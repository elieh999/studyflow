import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../export/backup_actions.dart';
import '../export/exporters.dart';
import '../export/web_files.dart';
import '../logic/insights.dart';
import '../util.dart';
import '../widgets/common.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final now = DateTime.now();
    final weekStart = startOfWeek(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, cSnap) {
          final courses = cSnap.data ?? [];
          final byId = {for (final c in courses) c.id: c};
          return StreamBuilder<List<StudySession>>(
            stream: db.watchSessions(),
            builder: (context, sSnap) {
              final sessions = sSnap.data ?? [];
              return StreamBuilder<List<Assignment>>(
                stream: db.watchAssignments(),
                builder: (context, aSnap) {
                  final assignments = aSnap.data ?? [];
                  return StreamBuilder<List<Flashcard>>(
                    stream: db.watchFlashcards(),
                    builder: (context, fSnap) {
                      final flashcards = fSnap.data ?? [];

                      if (courses.isEmpty) {
                        return const EmptyHint(
                          icon: Icons.insights_outlined,
                          text:
                              'No data yet.\nAdd courses and log study sessions to see insights.',
                        );
                      }

                      final perCourse = <int, int>{};
                      for (final s in sessions) {
                        perCourse.update(s.courseId, (v) => v + s.duration,
                            ifAbsent: () => s.duration);
                      }
                      final perCourseWeek = <int, int>{};
                      for (final s in sessions.where(
                          (s) => !s.sessionDate.isBefore(weekStart))) {
                        perCourseWeek.update(s.courseId, (v) => v + s.duration,
                            ifAbsent: () => s.duration);
                      }
                      int? topId;
                      var topSecs = 0;
                      perCourseWeek.forEach((id, secs) {
                        if (secs > topSecs) {
                          topSecs = secs;
                          topId = id;
                        }
                      });

                      final completed =
                          assignments.where((a) => a.isCompleted).length;
                      final streak = studyStreak(sessions, now);
                      final cram = crammingIndex(sessions, assignments);
                      final badges = achievements(
                        courses: courses,
                        assignments: assignments,
                        sessions: sessions,
                        flashcards: flashcards,
                        streak: streak,
                      );

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
                                  icon: Icons.task_alt),
                              StatCard(
                                  label: 'Study streak',
                                  value:
                                      '$streak day${streak == 1 ? '' : 's'}',
                                  icon: Icons.local_fire_department),
                              StatCard(
                                  label: 'Most studied (this week)',
                                  value: topId == null
                                      ? '—'
                                      : (byId[topId]?.name ?? '—'),
                                  icon: Icons.emoji_events),
                              StatCard(
                                  label: 'Last-minute studying',
                                  value: '${(cram * 100).round()}%',
                                  icon: Icons.hourglass_bottom),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _exportBar(context),
                          const SizedBox(height: 24),
                          Text('Study time per course',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 280,
                            child: perCourse.isEmpty
                                ? const Center(
                                    child: Text(
                                        'No study sessions recorded yet.'))
                                : _StudyBarChart(
                                    courses: courses,
                                    secondsByCourse: perCourse),
                          ),
                          const SizedBox(height: 24),
                          Text('Study activity',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('Each square is a day over the last 12 weeks',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          _Heatmap(minutes: minutesByDay(sessions), now: now),
                          const SizedBox(height: 24),
                          Text('Achievements',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final b in badges) _badge(context, b),
                            ],
                          ),
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

  Widget _exportBar(BuildContext context) {
    final db = AppScope.of(context).db;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Weekly PDF'),
          onPressed: () async {
            final courses = await db.allCourses();
            final sessions = await db.allSessions();
            final assignments = await db.allAssignments();
            final bytes = await buildWeeklyReport(
                courses: courses,
                sessions: sessions,
                assignments: assignments,
                now: DateTime.now());
            await Printing.sharePdf(
                bytes: bytes, filename: 'studyflow_week.pdf');
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: const Text('Export calendar (.ics)'),
          onPressed: () async {
            final courses = await db.allCourses();
            final assignments = await db.allAssignments();
            final schedule = await db.allSchedule();
            final ics = buildIcs(
                courses: courses,
                assignments: assignments,
                schedule: schedule,
                now: DateTime.now());
            downloadText('studyflow.ics', ics, 'text/calendar');
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined),
          label: const Text('Backup'),
          onPressed: () => exportBackupFlow(context, db),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Restore'),
          onPressed: () => restoreBackupFlow(context, db),
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, Achievement a) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: a.unlocked
            ? scheme.primaryContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Icon(a.unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: a.unlocked ? scheme.primary : scheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: a.unlocked ? null : scheme.outline)),
                Text(a.description,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Heatmap ----------------------------------------------------------------

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.minutes, required this.now});

  final Map<DateTime, int> minutes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime(now.year, now.month, now.day);
    // Start on the Monday 11 weeks before this week -> 12 columns.
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 7 * 11));
    final maxMin = minutes.values.fold<int>(0, (m, v) => v > m ? v : m);

    Color cellColor(int mins) {
      if (mins <= 0) {
        return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
      }
      final t = maxMin == 0 ? 0.0 : (mins / maxMin).clamp(0.15, 1.0);
      return Color.lerp(
          scheme.primary.withValues(alpha: 0.25), scheme.primary, t)!;
    }

    final columns = <Widget>[];
    for (var w = 0; w < 12; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        final mins = minutes[day] ?? 0;
        final future = day.isAfter(today);
        cells.add(Tooltip(
          message: future
              ? ''
              : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}: ${formatDuration(mins * 60)}',
          child: Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: future ? Colors.transparent : cellColor(mins),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ));
      }
      columns.add(Column(children: cells));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
    );
  }
}

// ---- Bar chart --------------------------------------------------------------

class _StudyBarChart extends StatelessWidget {
  const _StudyBarChart(
      {required this.courses, required this.secondsByCourse});

  final List<Course> courses;
  final Map<int, int> secondsByCourse;

  @override
  Widget build(BuildContext context) {
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
                if (i < 0 || i >= charted.length) {
                  return const SizedBox.shrink();
                }
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
