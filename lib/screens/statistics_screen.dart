import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../util.dart';
import '../widgets/common.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final weekStart = startOfWeek(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, cSnap) {
          final courses = cSnap.data ?? [];
          final courseById = {for (final c in courses) c.id: c};
          return StreamBuilder<List<StudySession>>(
            stream: db.watchSessions(),
            builder: (context, sSnap) {
              final sessions = sSnap.data ?? [];
              return StreamBuilder<List<Assignment>>(
                stream: db.watchAssignments(),
                builder: (context, aSnap) {
                  final assignments = aSnap.data ?? [];

                  if (courses.isEmpty) {
                    return const EmptyHint(
                      icon: Icons.bar_chart_outlined,
                      text: 'No data yet.\nAdd courses and run a few study sessions to see stats.',
                    );
                  }

                  // Total study seconds per course (all time).
                  final perCourse = <int, int>{};
                  for (final s in sessions) {
                    perCourse.update(s.courseId, (v) => v + s.duration,
                        ifAbsent: () => s.duration);
                  }

                  // Most-studied course this week.
                  final perCourseWeek = <int, int>{};
                  for (final s in sessions
                      .where((s) => !s.sessionDate.isBefore(weekStart))) {
                    perCourseWeek.update(s.courseId, (v) => v + s.duration,
                        ifAbsent: () => s.duration);
                  }
                  int? topCourseId;
                  var topSecs = 0;
                  perCourseWeek.forEach((id, secs) {
                    if (secs > topSecs) {
                      topSecs = secs;
                      topCourseId = id;
                    }
                  });

                  final completed =
                      assignments.where((a) => a.isCompleted).length;
                  final streak = _studyStreak(sessions);

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          StatCard(
                            label: 'Assignments completed',
                            value: '$completed',
                            icon: Icons.task_alt,
                          ),
                          StatCard(
                            label: 'Weekly study streak',
                            value: '$streak day${streak == 1 ? '' : 's'}',
                            icon: Icons.local_fire_department,
                          ),
                          StatCard(
                            label: 'Most studied (this week)',
                            value: topCourseId == null
                                ? '—'
                                : (courseById[topCourseId]?.name ?? '—'),
                            icon: Icons.emoji_events,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('Study time per course',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Total hours recorded for each course',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 300,
                        child: perCourse.isEmpty
                            ? const Center(
                                child: Text(
                                    'No study sessions recorded yet.\nUse the Focus timer to log some.',
                                    textAlign: TextAlign.center),
                              )
                            : _StudyBarChart(
                                courses: courses,
                                secondsByCourse: perCourse,
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Consecutive days (ending today or yesterday) with at least one session.
  static int _studyStreak(List<StudySession> sessions) {
    if (sessions.isEmpty) return 0;
    final days = <DateTime>{
      for (final s in sessions)
        DateTime(s.sessionDate.year, s.sessionDate.month, s.sessionDate.day)
    };
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    // Allow the streak to count even if today has no session yet.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class _StudyBarChart extends StatelessWidget {
  const _StudyBarChart({
    required this.courses,
    required this.secondsByCourse,
  });

  final List<Course> courses;
  final Map<int, int> secondsByCourse;

  @override
  Widget build(BuildContext context) {
    // Only chart courses that actually have study time.
    final charted =
        courses.where((c) => (secondsByCourse[c.id] ?? 0) > 0).toList();
    final maxHours = charted
        .map((c) => (secondsByCourse[c.id] ?? 0) / 3600)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final topY = (maxHours <= 1) ? 1.0 : (maxHours * 1.2);

    return BarChart(
      BarChartData(
        maxY: topY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) {
              final c = charted[group.x];
              return BarTooltipItem(
                '${c.name}\n${formatDuration(secondsByCourse[c.id] ?? 0)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, _) => Text('${value.toStringAsFixed(0)}h',
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= charted.length) return const SizedBox.shrink();
                final name = charted[i].name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 8)}…' : name,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < charted.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (secondsByCourse[charted[i].id] ?? 0) / 3600,
                  color: Color(charted[i].color),
                  width: 26,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
