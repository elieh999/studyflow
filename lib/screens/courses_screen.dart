import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../util.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCourseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add course'),
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          if (courses.isEmpty) {
            return const _EmptyHint(
              icon: Icons.menu_book_outlined,
              text: 'No courses yet.\nTap "Add course" to create your first one.',
            );
          }
          return StreamBuilder<List<StudySession>>(
            stream: db.watchSessions(),
            builder: (context, sessionSnap) {
              final sessions = sessionSnap.data ?? [];
              return StreamBuilder<List<Assignment>>(
                stream: db.watchAssignments(),
                builder: (context, assignSnap) {
                  final assignments = assignSnap.data ?? [];
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: courses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = courses[i];
                      final studySecs = sessions
                          .where((s) => s.courseId == c.id)
                          .fold<int>(0, (sum, s) => sum + s.duration);
                      final openCount = assignments
                          .where((a) => a.courseId == c.id && !a.isCompleted)
                          .length;
                      return _CourseCard(
                        course: c,
                        studySeconds: studySecs,
                        openAssignments: openCount,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.studySeconds,
    required this.openAssignments,
  });

  final Course course;
  final int studySeconds;
  final int openAssignments;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 44,
              decoration: BoxDecoration(
                color: Color(course.color),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (course.instructor.isNotEmpty)
                    Text(course.instructor,
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    'Studied ${formatDuration(studySeconds)}  ·  $openAssignments open assignment${openAssignments == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => showCourseDialog(context, existing: course),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Delete "${course.name}"?'),
                    content: const Text(
                        'This also removes its assignments, study sessions and schedule entries.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) await db.deleteCourse(course.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCourseDialog(BuildContext context, {Course? existing}) async {
  final db = AppScope.of(context).db;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final instructorCtrl =
      TextEditingController(text: existing?.instructor ?? '');
  var color = existing != null
      ? Color(existing.color)
      : courseColorPalette.first;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Add course' : 'Edit course'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Course name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: instructorCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Instructor (optional)'),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Colour',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in courseColorPalette)
                      GestureDetector(
                        onTap: () => setState(() => color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.toARGB32() == color.toARGB32()
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
              if (existing == null) {
                await db.addCourse(CoursesCompanion(
                  name: Value(nameCtrl.text.trim()),
                  instructor: Value(instructorCtrl.text.trim()),
                  color: Value(color.toARGB32()),
                ));
              } else {
                await db.updateCourse(existing.copyWith(
                  name: nameCtrl.text.trim(),
                  instructor: instructorCtrl.text.trim(),
                  color: color.toARGB32(),
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
