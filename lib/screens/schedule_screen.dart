import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly schedule'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, snap) {
          final courses = snap.data ?? [];
          return FloatingActionButton.extended(
            onPressed: courses.isEmpty
                ? null
                : () => showScheduleDialog(context, courses),
            icon: const Icon(Icons.add),
            label: const Text('Add class'),
          );
        },
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          final courseById = {for (final c in courses) c.id: c};
          if (courses.isEmpty) {
            return const EmptyHint(
              icon: Icons.calendar_view_week_outlined,
              text: 'Add a course first,\nthen add its weekly class times here.',
            );
          }
          return StreamBuilder<List<ScheduleEntry>>(
            stream: db.watchSchedule(),
            builder: (context, snap) {
              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return const EmptyHint(
                  icon: Icons.event_available_outlined,
                  text: 'No classes scheduled yet.\nTap "Add class" to build your week.',
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var day = 1; day <= 7; day++)
                    _daySection(context, day,
                        entries.where((e) => e.dayOfWeek == day).toList(),
                        courseById),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _daySection(
    BuildContext context,
    int day,
    List<ScheduleEntry> entries,
    Map<int, Course> courseById,
  ) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final db = AppScope.of(context).db;
    const fullDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(fullDays[day - 1],
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final e in entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 10,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(courseById[e.courseId]?.color ?? 0xFF888888),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(courseById[e.courseId]?.name ?? 'Course'),
              subtitle: Text(
                '${e.startTime} – ${e.endTime}'
                '${e.location.isNotEmpty ? '  ·  ${e.location}' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: () => db.deleteScheduleEntry(e.id),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showScheduleDialog(
    BuildContext context, List<Course> courses) async {
  final db = AppScope.of(context).db;
  var courseId = courses.first.id;
  var day = 1;
  var start = const TimeOfDay(hour: 9, minute: 0);
  var end = const TimeOfDay(hour: 10, minute: 0);
  final locationCtrl = TextEditingController();

  String fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add class time'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                  DropdownMenuItem(value: 7, child: Text('Sunday')),
                ],
                onChanged: (v) => setState(() => day = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: start);
                        if (t != null) setState(() => start = t);
                      },
                      child: Text('Start: ${fmt(start)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: end);
                        if (t != null) setState(() => end = t);
                      },
                      child: Text('End: ${fmt(end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Location / room (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await db.addScheduleEntry(ScheduleEntriesCompanion(
                courseId: Value(courseId),
                dayOfWeek: Value(day),
                startTime: Value(fmt(start)),
                endTime: Value(fmt(end)),
                location: Value(locationCtrl.text.trim()),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
