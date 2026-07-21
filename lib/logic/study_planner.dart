import '../data/database.dart';

// A greedy study-plan generator. It spreads each assignment's estimated time
// across the days between today and its due date, earliest-deadline-first, never
// putting more than [dailyCapacityMinutes] of study on any one day. Anything
// that can't fit before its deadline is reported so the student can react.

class PlannedBlock {
  const PlannedBlock({
    required this.day,
    required this.assignmentId,
    required this.courseId,
    required this.title,
    required this.minutes,
  });

  final DateTime day;
  final int assignmentId;
  final int courseId;
  final String title;
  final int minutes;
}

class StudyPlan {
  const StudyPlan({required this.blocks, required this.unschedulable});

  final List<PlannedBlock> blocks;
  // Assignments that don't fully fit before their due date, with the shortfall.
  final Map<Assignment, int> unschedulable;
}

StudyPlan generatePlan({
  required List<Assignment> assignments,
  required DateTime now,
  int dailyCapacityMinutes = 120,
  int maxBlockMinutes = 60,
}) {
  final today = DateTime(now.year, now.month, now.day);

  final pending = assignments
      .where((a) => !a.isCompleted && a.estimatedMinutes > 0)
      .toList()
    ..sort((a, b) {
      final byDue = a.dueDate.compareTo(b.dueDate);
      if (byDue != 0) return byDue;
      return b.priority.compareTo(a.priority);
    });

  final usedPerDay = <DateTime, int>{};
  final blocks = <PlannedBlock>[];
  final unschedulable = <Assignment, int>{};

  int capacityLeft(DateTime day) =>
      dailyCapacityMinutes - (usedPerDay[day] ?? 0);

  for (final a in pending) {
    var remaining = a.estimatedMinutes;
    final due = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
    // Study up to and including the due date, but never before today.
    var day = today;
    while (remaining > 0 && !day.isAfter(due)) {
      final free = capacityLeft(day);
      if (free > 0) {
        final chunk =
            remaining < free ? remaining : (free < maxBlockMinutes ? free : maxBlockMinutes);
        final place = chunk < free ? chunk : free;
        final minutes = remaining < place ? remaining : place;
        blocks.add(PlannedBlock(
          day: day,
          assignmentId: a.id,
          courseId: a.courseId,
          title: a.title,
          minutes: minutes,
        ));
        usedPerDay[day] = (usedPerDay[day] ?? 0) + minutes;
        remaining -= minutes;
      }
      day = day.add(const Duration(days: 1));
    }
    if (remaining > 0) unschedulable[a] = remaining;
  }

  blocks.sort((x, y) {
    final byDay = x.day.compareTo(y.day);
    if (byDay != 0) return byDay;
    return x.title.compareTo(y.title);
  });

  return StudyPlan(blocks: blocks, unschedulable: unschedulable);
}
