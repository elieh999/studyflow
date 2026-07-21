import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai/ollama_service.dart';
import '../app_scope.dart';
import '../data/database.dart';
import '../util.dart';
import '../widgets/common.dart';

enum StatusFilter { all, pending, completed }

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _search = '';
  int? _courseFilter; // null = all courses
  StatusFilter _status = StatusFilter.all;
  int? _priorityFilter; // null = all priorities

  final _ai = OllamaService();
  bool _aiUp = false;

  @override
  void initState() {
    super.initState();
    _ai.available().then((v) {
      if (mounted) setState(() => _aiUp = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        automaticallyImplyLeading: false,
        actions: [
          if (_aiUp)
            StreamBuilder<List<Course>>(
              stream: db.watchCourses(),
              builder: (context, snap) {
                final courses = snap.data ?? [];
                return IconButton(
                  tooltip: 'Quick add with AI',
                  icon: const Icon(Icons.auto_awesome),
                  onPressed:
                      courses.isEmpty ? null : () => _quickAdd(courses),
                );
              },
            ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, snap) {
          final courses = snap.data ?? [];
          return FloatingActionButton.extended(
            onPressed: courses.isEmpty
                ? null
                : () => showAssignmentDialog(context, courses),
            icon: const Icon(Icons.add),
            label: const Text('Add assignment'),
          );
        },
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          final courseById = {for (final c in courses) c.id: c};
          return Column(
            children: [
              _buildFilters(courses),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<Assignment>>(
                  stream: db.watchAssignments(),
                  builder: (context, snap) {
                    if (courses.isEmpty) {
                      return const EmptyHint(
                        icon: Icons.checklist_outlined,
                        text: 'Add a course first,\nthen you can create assignments for it.',
                      );
                    }
                    var items = snap.data ?? [];
                    items = items.where(_matches).toList()
                      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    if (items.isEmpty) {
                      return const EmptyHint(
                        icon: Icons.filter_alt_off_outlined,
                        text: 'No assignments match the current filters.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _AssignmentTile(
                        assignment: items[i],
                        course: courseById[items[i].courseId],
                        courses: courses,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matches(Assignment a) {
    if (_search.isNotEmpty &&
        !a.title.toLowerCase().contains(_search.toLowerCase()) &&
        !a.description.toLowerCase().contains(_search.toLowerCase())) {
      return false;
    }
    if (_courseFilter != null && a.courseId != _courseFilter) return false;
    if (_status == StatusFilter.pending && a.isCompleted) return false;
    if (_status == StatusFilter.completed && !a.isCompleted) return false;
    if (_priorityFilter != null && a.priority != _priorityFilter) return false;
    return true;
  }

  Future<void> _quickAdd(List<Course> courses) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final db = AppScope.of(context).db;
    var busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Quick add with AI'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Describe it in plain English, e.g. "history essay due next '
                      'friday, high priority".'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  enabled: !busy,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setState(() => busy = true);
                      try {
                        final ai = OllamaService(
                            model: AppScope.of(context).settings.aiModel);
                        final parsed = await ai.parseQuickAdd(
                            controller.text.trim(), courses);
                        if (parsed == null) {
                          setState(() => busy = false);
                          messenger.showSnackBar(const SnackBar(
                              content: Text(
                                  'Couldn\'t understand that — try rephrasing.')));
                          return;
                        }
                        final courseName =
                            (parsed['course'] ?? '').toString().toLowerCase();
                        final course = courses.firstWhere(
                          (c) => c.name.toLowerCase() == courseName,
                          orElse: () => courses.first,
                        );
                        final pr = switch (
                            (parsed['priority'] ?? '').toString().toLowerCase()) {
                          'high' => 2,
                          'low' => 0,
                          _ => 1,
                        };
                        final days =
                            (parsed['dueInDays'] as num?)?.round() ?? 3;
                        final due = DateTime.now()
                            .add(Duration(days: days))
                            .copyWith(hour: 23, minute: 59, second: 0);
                        await db.addAssignment(AssignmentsCompanion(
                          courseId: Value(course.id),
                          title: Value(
                              (parsed['title'] ?? controller.text).toString().trim()),
                          dueDate: Value(due),
                          priority: Value(pr),
                        ));
                        if (context.mounted) Navigator.pop(context);
                        messenger.showSnackBar(const SnackBar(
                            content: Text(
                                'Added — open it to fine-tune the details.')));
                      } catch (e) {
                        setState(() => busy = false);
                        messenger.showSnackBar(
                            SnackBar(content: Text('AI request failed: $e')));
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(List<Course> courses) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title or description',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          DropdownMenu<int?>(
            initialSelection: _courseFilter,
            label: const Text('Course'),
            onSelected: (v) => setState(() => _courseFilter = v),
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: null, label: 'All courses'),
              for (final c in courses)
                DropdownMenuEntry(value: c.id, label: c.name),
            ],
          ),
          SegmentedButton<StatusFilter>(
            segments: const [
              ButtonSegment(value: StatusFilter.all, label: Text('All')),
              ButtonSegment(value: StatusFilter.pending, label: Text('Pending')),
              ButtonSegment(value: StatusFilter.completed, label: Text('Done')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          DropdownMenu<int?>(
            initialSelection: _priorityFilter,
            label: const Text('Priority'),
            onSelected: (v) => setState(() => _priorityFilter = v),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: null, label: 'Any priority'),
              DropdownMenuEntry(value: 2, label: 'High'),
              DropdownMenuEntry(value: 1, label: 'Medium'),
              DropdownMenuEntry(value: 0, label: 'Low'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.course,
    required this.courses,
  });

  final Assignment assignment;
  final Course? course;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final due = assignment.dueDate;
    final overdue = !assignment.isCompleted && due.isBefore(DateTime.now());
    final dateStr = DateFormat('EEE, d MMM · HH:mm').format(due);

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: assignment.isCompleted,
          onChanged: (v) =>
              db.setAssignmentComplete(assignment.id, v ?? false),
        ),
        title: Text(
          assignment.title,
          style: TextStyle(
            decoration:
                assignment.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (course != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(course!.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(course!.name),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.event,
                    size: 14,
                    color: overdue ? Colors.red : null),
                const SizedBox(width: 4),
                Text(
                  overdue ? '$dateStr (overdue)' : dateStr,
                  style: TextStyle(color: overdue ? Colors.red : null),
                ),
              ],
            ),
            if (assignment.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(assignment.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PriorityBadge(priority: assignment.priority),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => showAssignmentDialog(context, courses,
                  existing: assignment),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => db.deleteAssignment(assignment.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final int priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priorityLabel(priority),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Future<void> showAssignmentDialog(
  BuildContext context,
  List<Course> courses, {
  Assignment? existing,
}) async {
  final db = AppScope.of(context).db;
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final estCtrl = TextEditingController(
      text: (existing != null && existing.estimatedMinutes > 0)
          ? (existing.estimatedMinutes / 60).toString()
          : '');
  var courseId = existing?.courseId ?? courses.first.id;
  var priority = existing?.priority ?? 1;
  var due = existing?.dueDate ??
      DateTime.now().add(const Duration(days: 1)).copyWith(
            hour: 23,
            minute: 59,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          );
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Add assignment' : 'Edit assignment'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: courseId,
                    decoration: const InputDecoration(labelText: 'Course'),
                    items: [
                      for (final c in courses)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => courseId = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('High')),
                      DropdownMenuItem(value: 1, child: Text('Medium')),
                      DropdownMenuItem(value: 0, child: Text('Low')),
                    ],
                    onChanged: (v) => setState(() => priority = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Due: ${DateFormat('EEE, d MMM y · HH:mm').format(due)}'),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Pick'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: due,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d == null) return;
                          if (!context.mounted) return;
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(due),
                          );
                          setState(() {
                            due = DateTime(d.year, d.month, d.day,
                                t?.hour ?? 23, t?.minute ?? 59);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: estCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Estimated hours (optional)',
                      helperText: 'Used by the study plan generator',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final estMinutes =
                  ((double.tryParse(estCtrl.text.trim()) ?? 0) * 60).round();
              if (existing == null) {
                await db.addAssignment(AssignmentsCompanion(
                  courseId: Value(courseId),
                  title: Value(titleCtrl.text.trim()),
                  description: Value(descCtrl.text.trim()),
                  dueDate: Value(due),
                  priority: Value(priority),
                  estimatedMinutes: Value(estMinutes),
                ));
              } else {
                await db.updateAssignment(existing.copyWith(
                  courseId: courseId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  dueDate: due,
                  priority: priority,
                  estimatedMinutes: estMinutes,
                ));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
