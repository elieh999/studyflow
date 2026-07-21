import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../logic/gamification.dart';
import '../logic/study_tips.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/goal_ring.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onStartStudying});

  final VoidCallback onStartStudying;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final now = DateTime.now();
    final weekStart = startOfWeek(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: onStartStudying,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start studying'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, courseSnap) {
          final courses = courseSnap.data ?? [];
          final courseById = {for (final c in courses) c.id: c};
          return StreamBuilder<List<Assignment>>(
            stream: db.watchAssignments(),
            builder: (context, aSnap) {
              final assignments = aSnap.data ?? [];
              return StreamBuilder<List<StudySession>>(
                stream: db.watchSessions(),
                builder: (context, sSnap) {
                  final sessions = sSnap.data ?? [];
                  return StreamBuilder<List<ScheduleEntry>>(
                    stream: db.watchSchedule(),
                    builder: (context, schedSnap) {
                      final schedule = schedSnap.data ?? [];

                      final weekSeconds = sessions
                          .where((s) => !s.sessionDate.isBefore(weekStart))
                          .fold<int>(0, (sum, s) => sum + s.duration);

                      final today = DateTime(now.year, now.month, now.day);
                      final todayMinutes = sessions
                              .where((s) => !s.sessionDate.isBefore(today))
                              .fold<int>(0, (sum, s) => sum + s.duration) ~/
                          60;
                      final totalMinutes = sessions.fold<int>(
                              0, (sum, s) => sum + s.duration) ~/
                          60;
                      final level = levelForMinutes(totalMinutes);
                      final settings = AppScope.of(context).settings;

                      final upcoming = assignments
                          .where((a) => !a.isCompleted)
                          .toList()
                        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

                      final todayClasses = schedule
                          .where((e) => e.dayOfWeek == now.weekday)
                          .toList()
                        ..sort((a, b) => a.startTime.compareTo(b.startTime));

                      final pendingCount =
                          assignments.where((a) => !a.isCompleted).length;

                      final dueSoon = upcoming
                          .where((a) =>
                              a.dueDate.isAfter(now) &&
                              a.dueDate.difference(now) <=
                                  const Duration(hours: 48))
                          .toList();

                      if (courses.isEmpty) {
                        return const EmptyHint(
                          icon: Icons.school_outlined,
                          text: 'Welcome to StudyFlow!\nStart by adding a course from the Courses tab.',
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  GoalRing(
                                    doneMinutes: todayMinutes,
                                    goalMinutes: settings.dailyGoalMinutes,
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.military_tech,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            const SizedBox(width: 8),
                                            Text('Level $level · ${levelTitle(level)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: levelProgress(totalMinutes),
                                            minHeight: 8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('$totalMinutes minutes studied all-time',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                        const SizedBox(height: 14),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                                Icons.lightbulb_outline,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(tipForDay(now),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (dueSoon.isNotEmpty)
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.55),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.alarm, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${dueSoon.length} assignment${dueSoon.length == 1 ? '' : 's'} '
                                        'due within 48 hours — ${dueSoon.map((a) => a.title).take(3).join(', ')}'
                                        '${dueSoon.length > 3 ? '…' : ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              StatCard(
                                label: 'Study time this week',
                                value: formatDuration(weekSeconds),
                                icon: Icons.timelapse,
                              ),
                              StatCard(
                                label: 'Pending assignments',
                                value: '$pendingCount',
                                icon: Icons.checklist,
                              ),
                              StatCard(
                                label: 'Classes today',
                                value: '${todayClasses.length}',
                                icon: Icons.today,
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _SectionTitle('Today\'s classes'),
                          if (todayClasses.isEmpty)
                            const _MutedLine('No classes scheduled for today.')
                          else
                            ...todayClasses.map((e) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Container(
                                      width: 10,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Color(courseById[e.courseId]
                                                ?.color ??
                                            0xFF888888),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    title: Text(
                                        courseById[e.courseId]?.name ??
                                            'Course'),
                                    subtitle: Text(
                                        '${e.startTime} – ${e.endTime}'
                                        '${e.location.isNotEmpty ? '  ·  ${e.location}' : ''}'),
                                  ),
                                )),
                          const SizedBox(height: 24),
                          _SectionTitle('Upcoming assignments'),
                          if (upcoming.isEmpty)
                            const _MutedLine('Nothing pending — nice work!')
                          else
                            ...upcoming.take(6).map((a) {
                              final c = courseById[a.courseId];
                              final overdue =
                                  a.dueDate.isBefore(DateTime.now());
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(Icons.circle,
                                      size: 14,
                                      color: priorityColor(a.priority)),
                                  title: Text(a.title),
                                  subtitle: Text(
                                    '${c?.name ?? ''} · ${DateFormat('EEE, d MMM · HH:mm').format(a.dueDate)}'
                                    '${overdue ? ' (overdue)' : ''}',
                                    style: TextStyle(
                                        color: overdue ? Colors.red : null),
                                  ),
                                  trailing: Text(priorityLabel(a.priority),
                                      style: TextStyle(
                                          color: priorityColor(a.priority),
                                          fontWeight: FontWeight.w600)),
                                ),
                              );
                            }),
                        ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
