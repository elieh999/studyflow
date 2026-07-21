import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai/ollama_service.dart';
import '../app_scope.dart';
import '../data/database.dart';
import '../widgets/common.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _aiUp = false;
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      OllamaService().available().then((v) {
        if (mounted) setState(() => _aiUp = v);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, snap) {
          final courses = snap.data ?? [];
          return FloatingActionButton.extended(
            onPressed: courses.isEmpty ? null : () => _edit(courses),
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          );
        },
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          final byId = {for (final c in courses) c.id: c};
          if (courses.isEmpty) {
            return const EmptyHint(
              icon: Icons.sticky_note_2_outlined,
              text: 'Add a course first,\nthen keep study notes for it here.',
            );
          }
          return StreamBuilder<List<Note>>(
            stream: db.watchNotes(),
            builder: (context, snap) {
              final notes = snap.data ?? [];
              if (notes.isEmpty) {
                return const EmptyHint(
                  icon: Icons.sticky_note_2_outlined,
                  text: 'No notes yet.\nJot down what you learned — and turn it '
                      'into flashcards with one tap.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = notes[i];
                  final course = byId[n.courseId];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (course != null) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: Color(course.color),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(course.name,
                                    style:
                                        Theme.of(context).textTheme.labelMedium),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                DateFormat('d MMM, HH:mm').format(n.updatedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              if (_aiUp)
                                IconButton(
                                  tooltip: 'Make flashcards from this note',
                                  icon: const Icon(Icons.auto_awesome),
                                  onPressed: () => _makeCards(n),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(courses, existing: n),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => db.deleteNote(n.id),
                              ),
                            ],
                          ),
                          if (n.title.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(n.title,
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                          if (n.body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(n.body,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(List<Course> courses, {Note? existing}) async {
    final db = AppScope.of(context).db;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    var courseId = existing?.courseId ?? courses.first.id;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'New note' : 'Edit note'),
          content: SizedBox(
            width: 480,
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
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
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
                if (titleCtrl.text.trim().isEmpty &&
                    bodyCtrl.text.trim().isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                if (existing == null) {
                  await db.addNote(NotesCompanion(
                    courseId: Value(courseId),
                    title: Value(titleCtrl.text.trim()),
                    body: Value(bodyCtrl.text.trim()),
                    updatedAt: Value(DateTime.now()),
                  ));
                } else {
                  await db.updateNote(existing.copyWith(
                    courseId: courseId,
                    title: titleCtrl.text.trim(),
                    body: bodyCtrl.text.trim(),
                    updatedAt: DateTime.now(),
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

  Future<void> _makeCards(Note note) async {
    final db = AppScope.of(context).db;
    final messenger = ScaffoldMessenger.of(context);
    final source = '${note.title}\n${note.body}'.trim();
    if (source.isEmpty) return;
    messenger.showSnackBar(const SnackBar(
        content: Text('Asking the local model to draft flashcards…')));
    try {
      final ai = OllamaService(model: AppScope.of(context).settings.aiModel);
      final cards = await ai.makeFlashcards(source, count: 6);
      var added = 0;
      for (final c in cards) {
        if (c.question.isEmpty || c.answer.isEmpty) continue;
        await db.addFlashcard(FlashcardsCompanion(
          courseId: Value(note.courseId),
          question: Value(c.question),
          answer: Value(c.answer),
          dueDate: Value(DateTime.now()),
        ));
        added++;
      }
      messenger.showSnackBar(SnackBar(
          content: Text(added == 0
              ? 'The model didn\'t return usable cards — try a longer note.'
              : 'Added $added flashcard${added == 1 ? '' : 's'} from this note.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('AI request failed: $e')));
    }
  }
}
