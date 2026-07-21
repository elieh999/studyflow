import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../logic/study_planner.dart';
import '../util.dart';
import '../widgets/common.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  double _dailyCapacity = 120;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study plan'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          final byId = {for (final c in courses) c.id: c};
          return StreamBuilder<List<Assignment>>(
            stream: db.watchAssignments(),
            builder: (context, snap) {
              final assignments = snap.data ?? [];
              final withEstimates = assignments
                  .where((a) => !a.isCompleted && a.estimatedMinutes > 0)
                  .toList();
              final plan = generatePlan(
                assignments: assignments,
                now: DateTime.now(),
                dailyCapacityMinutes: _dailyCapacity.round(),
              );
              final byDay = <DateTime, List<PlannedBlock>>{};
              for (final b in plan.blocks) {
                byDay.putIfAbsent(b.day, () => []).add(b);
              }
              final days = byDay.keys.toList()..sort();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This spreads each assignment\'s estimated time across the '
                            'days before it\'s due, earliest deadline first — capped at '
                            'how much you want to study per day.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Row(
                            children: [
                              const Text('Study per day'),
                              Expanded(
                                child: Slider(
                                  value: _dailyCapacity,
                                  min: 30,
                                  max: 360,
                                  divisions: 11,
                                  label:
                                      '${(_dailyCapacity / 60).toStringAsFixed(1)} h',
                                  onChanged: (v) =>
                                      setState(() => _dailyCapacity = v),
                                ),
                              ),
                              Text(
                                  '${(_dailyCapacity / 60).toStringAsFixed(1)} h'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (withEstimates.isEmpty)
                    const EmptyHint(
                      icon: Icons.event_note_outlined,
                      text:
                          'Add an estimated time to some assignments\n(open an assignment and set "Estimated hours")\nand a plan will appear here.',
                    ),
                  if (plan.unschedulable.isNotEmpty)
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber, size: 20),
                                const SizedBox(width: 8),
                                Text('Tight on time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final e in plan.unschedulable.entries)
                              Text(
                                  '• ${e.key.title}: ${formatDuration(e.value * 60)} won\'t '
                                  'fit before it\'s due at your current pace.'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  for (final day in days) _daySection(context, day, byDay[day]!, byId),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _daySection(BuildContext context, DateTime day,
      List<PlannedBlock> blocks, Map<int, Course> byId) {
    final total = blocks.fold<int>(0, (t, b) => t + b.minutes);
    final label = DateFormat('EEEE, d MMM').format(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text('$label  ·  ${formatDuration(total * 60)}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final b in blocks)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 8,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(byId[b.courseId]?.color ?? 0xFF888888),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(b.title),
              subtitle: Text(byId[b.courseId]?.name ?? ''),
              trailing: Text(formatDuration(b.minutes * 60),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
      ],
    );
  }
}
