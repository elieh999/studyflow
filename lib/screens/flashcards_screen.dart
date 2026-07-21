import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../ai/ollama_service.dart';
import '../app_scope.dart';
import '../data/database.dart';
import '../logic/spaced_repetition.dart';
import '../widgets/common.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _ai = OllamaService();
  bool? _aiUp;

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
        title: const Text('Flashcards'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, snap) {
          final courses = snap.data ?? [];
          if (courses.isEmpty) return const SizedBox.shrink();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_aiUp == true)
                FloatingActionButton.extended(
                  heroTag: 'ai',
                  onPressed: () => _generateWithAi(courses),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate with AI'),
                ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'add',
                onPressed: () => _editCard(courses),
                icon: const Icon(Icons.add),
                label: const Text('Add card'),
              ),
            ],
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
              icon: Icons.style_outlined,
              text: 'Add a course first,\nthen build flashcard decks for it.',
            );
          }
          return StreamBuilder<List<Flashcard>>(
            stream: db.watchFlashcards(),
            builder: (context, snap) {
              final cards = snap.data ?? [];
              final now = DateTime.now();
              final due =
                  cards.where((c) => !c.dueDate.isAfter(now)).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cards.isEmpty
                                  ? 'No cards yet. Add some or generate them with AI.'
                                  : '${due.length} card${due.length == 1 ? '' : 's'} due for review'
                                      ' · ${cards.length} total',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: due.isEmpty
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReviewSession(
                                            cards: due, byId: byId),
                                      ),
                                    ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Review due'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_aiUp == false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Local AI (Ollama) isn\'t reachable, so "Generate with AI" is hidden. '
                        'Open the app via "Open StudyFlow.exe" with Ollama running to use it.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 8),
                  ...cards.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 8,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(byId[c.courseId]?.color ?? 0xFF888888),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(c.question),
                          subtitle: Text(c.answer,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editCard(courses, existing: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => db.deleteFlashcard(c.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editCard(List<Course> courses, {Flashcard? existing}) async {
    final db = AppScope.of(context).db;
    final qCtrl = TextEditingController(text: existing?.question ?? '');
    final aCtrl = TextEditingController(text: existing?.answer ?? '');
    var courseId = existing?.courseId ?? courses.first.id;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add flashcard' : 'Edit flashcard'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
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
                  TextFormField(
                    controller: qCtrl,
                    decoration: const InputDecoration(labelText: 'Question'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: aCtrl,
                    decoration: const InputDecoration(labelText: 'Answer'),
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                  await db.addFlashcard(FlashcardsCompanion(
                    courseId: Value(courseId),
                    question: Value(qCtrl.text.trim()),
                    answer: Value(aCtrl.text.trim()),
                    dueDate: Value(DateTime.now()),
                  ));
                } else {
                  await db.updateFlashcard(existing.copyWith(
                    courseId: courseId,
                    question: qCtrl.text.trim(),
                    answer: aCtrl.text.trim(),
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

  Future<void> _generateWithAi(List<Course> courses) async {
    final db = AppScope.of(context).db;
    final notesCtrl = TextEditingController();
    var courseId = courses.first.id;
    var count = 6;
    var busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate flashcards with AI'),
          content: SizedBox(
            width: 460,
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
                  onChanged: busy ? null : (v) => setState(() => courseId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 6,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Paste your notes',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('How many cards:'),
                    Expanded(
                      child: Slider(
                        value: count.toDouble(),
                        min: 3,
                        max: 12,
                        divisions: 9,
                        label: '$count',
                        onChanged: busy
                            ? null
                            : (v) => setState(() => count = v.round()),
                      ),
                    ),
                    Text('$count'),
                  ],
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text('Asking the local model… this can take '
                                'a few seconds.')),
                      ],
                    ),
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
                      if (notesCtrl.text.trim().isEmpty) return;
                      setState(() => busy = true);
                      try {
                        final ai = OllamaService(
                            model: AppScope.of(context).settings.aiModel);
                        final cards = await ai.makeFlashcards(
                            notesCtrl.text.trim(),
                            count: count);
                        var added = 0;
                        for (final c in cards) {
                          if (c.question.isEmpty || c.answer.isEmpty) continue;
                          await db.addFlashcard(FlashcardsCompanion(
                            courseId: Value(courseId),
                            question: Value(c.question),
                            answer: Value(c.answer),
                            dueDate: Value(DateTime.now()),
                          ));
                          added++;
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(added == 0
                                  ? 'The model didn\'t return usable cards — try more detailed notes.'
                                  : 'Added $added flashcard${added == 1 ? '' : 's'}.')));
                        }
                      } catch (e) {
                        setState(() => busy = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('AI request failed: $e')));
                        }
                      }
                    },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen review flow that walks through due cards and grades recall.
class ReviewSession extends StatefulWidget {
  const ReviewSession({super.key, required this.cards, required this.byId});

  final List<Flashcard> cards;
  final Map<int, Course> byId;

  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  int _index = 0;
  bool _revealed = false;

  Future<void> _grade(int quality) async {
    final db = AppScope.of(context).db;
    final card = widget.cards[_index];
    final r = reviewCard(
      easiness: card.easiness,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      quality: quality,
      now: DateTime.now(),
    );
    await db.updateFlashcard(card.copyWith(
      easiness: r.easiness,
      intervalDays: r.intervalDays,
      repetitions: r.repetitions,
      dueDate: r.due,
      lastReviewed: Value(DateTime.now()),
    ));
    if (!mounted) return;
    if (_index + 1 >= widget.cards.length) {
      Navigator.pop(context);
    } else {
      setState(() {
        _index++;
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    final course = widget.byId[card.courseId];
    return Scaffold(
      appBar: AppBar(
        title: Text('Review · ${_index + 1}/${widget.cards.length}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (course != null)
                  Text(course.name,
                      style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 16),
                Card(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Text(card.question,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (_revealed) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Text(card.answer,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!_revealed)
                  FilledButton(
                    onPressed: () => setState(() => _revealed = true),
                    child: const Text('Show answer'),
                  )
                else
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton(
                          onPressed: () => _grade(0),
                          child: const Text('Again')),
                      OutlinedButton(
                          onPressed: () => _grade(3),
                          child: const Text('Hard')),
                      FilledButton.tonal(
                          onPressed: () => _grade(4),
                          child: const Text('Good')),
                      FilledButton(
                          onPressed: () => _grade(5),
                          child: const Text('Easy')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
