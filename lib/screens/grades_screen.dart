import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../logic/grade_calc.dart';
import '../widgets/common.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  int? _courseId;
  double _target = 85;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grades'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          if (courses.isEmpty) {
            return const EmptyHint(
              icon: Icons.grade_outlined,
              text: 'Add a course first,\nthen track its grade breakdown here.',
            );
          }
          _courseId ??= courses.first.id;
          if (!courses.any((c) => c.id == _courseId)) {
            _courseId = courses.first.id;
          }
          return StreamBuilder<List<GradeItem>>(
            stream: db.watchGradeItems(),
            builder: (context, snap) {
              final all = snap.data ?? [];
              final items =
                  all.where((g) => g.courseId == _courseId).toList();
              final summary = summarise(items);
              final needed = neededOnRemaining(items, _target);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _courseId,
                    decoration: const InputDecoration(
                        labelText: 'Course', border: OutlineInputBorder()),
                    items: [
                      for (final c in courses)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _courseId = v),
                  ),
                  const SizedBox(height: 16),
                  _summaryCard(context, summary),
                  const SizedBox(height: 16),
                  _targetCard(context, needed),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Grade items',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => _editItem(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                          'No grade items yet. Add things like "Midterm 30%", '
                          '"Final 40%", "Homework 30%".'),
                    )
                  else
                    ...items.map((g) => _itemTile(context, g)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryCard(BuildContext context, GradeSummary s) {
    final pct = s.currentPercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current standing',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _metric(context, 'Grade so far',
                    pct == null ? '—' : '${pct.toStringAsFixed(1)}%'),
                _metric(context, 'Letter',
                    pct == null ? '—' : letterGrade(pct)),
                _metric(context, 'GPA point',
                    pct == null ? '—' : gpaPoint(pct).toStringAsFixed(1)),
                _metric(context, 'Graded weight',
                    '${s.gradedWeight.toStringAsFixed(0)}%'),
                _metric(context, 'If you ace the rest',
                    '${s.projectedIfRestFull.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetCard(BuildContext context, double? needed) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What do I need on the rest?',
                style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                const Text('Target'),
                Expanded(
                  child: Slider(
                    value: _target,
                    min: 50,
                    max: 100,
                    divisions: 50,
                    label: '${_target.round()}%',
                    onChanged: (v) => setState(() => _target = v),
                  ),
                ),
                Text('${_target.round()}%'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              needed == null
                  ? 'All the weight is already graded — nothing left to score on.'
                  : needed <= 0
                      ? 'You\'ve already secured this target. Nice.'
                      : needed > 100
                          ? 'Reaching ${_target.round()}% isn\'t possible with the '
                              'remaining work (would need ${needed.toStringAsFixed(0)}%).'
                          : 'You need to average ${needed.toStringAsFixed(1)}% on the '
                              'remaining graded work to finish at ${_target.round()}%.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _itemTile(BuildContext context, GradeItem g) {
    final db = AppScope.of(context).db;
    final scoreStr = g.graded
        ? '${g.score.toStringAsFixed(0)} / ${g.maxScore.toStringAsFixed(0)}'
        : 'not graded';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(g.name),
        subtitle: Text('Weight ${g.weight.toStringAsFixed(0)}%  ·  $scoreStr'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editItem(existing: g)),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => db.deleteGradeItem(g.id)),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem({GradeItem? existing}) async {
    final db = AppScope.of(context).db;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final weightCtrl =
        TextEditingController(text: existing?.weight.toStringAsFixed(0) ?? '');
    final scoreCtrl = TextEditingController(
        text: existing != null && existing.graded
            ? existing.score.toStringAsFixed(0)
            : '');
    final maxCtrl = TextEditingController(
        text: existing?.maxScore.toStringAsFixed(0) ?? '100');
    var graded = existing?.graded ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add grade item' : 'Edit grade item'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Name (e.g. Midterm)'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Weight (%)'),
                    validator: (v) => (double.tryParse(v ?? '') == null)
                        ? 'Enter a number'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Already graded'),
                    value: graded,
                    onChanged: (v) => setState(() => graded = v),
                  ),
                  if (graded)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: scoreCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Your score'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Out of'),
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
                final weight = double.tryParse(weightCtrl.text) ?? 0;
                final score = double.tryParse(scoreCtrl.text) ?? 0;
                final max = double.tryParse(maxCtrl.text) ?? 100;
                if (existing == null) {
                  await db.addGradeItem(GradeItemsCompanion(
                    courseId: Value(_courseId!),
                    name: Value(nameCtrl.text.trim()),
                    weight: Value(weight),
                    graded: Value(graded),
                    score: Value(score),
                    maxScore: Value(max == 0 ? 100 : max),
                  ));
                } else {
                  await db.updateGradeItem(existing.copyWith(
                    name: nameCtrl.text.trim(),
                    weight: weight,
                    graded: graded,
                    score: score,
                    maxScore: max == 0 ? 100 : max,
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
}
