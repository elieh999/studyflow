import '../data/database.dart';

// Consecutive days (ending today, or yesterday if today is still empty) that
// have at least one study session.
int studyStreak(List<StudySession> sessions, DateTime now) {
  if (sessions.isEmpty) return 0;
  final days = <DateTime>{
    for (final s in sessions)
      DateTime(s.sessionDate.year, s.sessionDate.month, s.sessionDate.day),
  };
  var cursor = DateTime(now.year, now.month, now.day);
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

// Fraction (0..1) of study minutes logged within 48h before an assignment's due
// date for the same course — a rough "how much of a crammer are you" measure.
double crammingIndex(
    List<StudySession> sessions, List<Assignment> assignments) {
  if (sessions.isEmpty) return 0;
  var total = 0;
  var lastMinute = 0;
  for (final s in sessions) {
    total += s.duration;
    final crammed = assignments.any((a) =>
        a.courseId == s.courseId &&
        a.dueDate.isAfter(s.sessionDate) &&
        a.dueDate.difference(s.sessionDate) <= const Duration(hours: 48));
    if (crammed) lastMinute += s.duration;
  }
  if (total == 0) return 0;
  return lastMinute / total;
}

// Minutes studied per calendar day, for building an activity heatmap.
Map<DateTime, int> minutesByDay(List<StudySession> sessions) {
  final map = <DateTime, int>{};
  for (final s in sessions) {
    final d = DateTime(
        s.sessionDate.year, s.sessionDate.month, s.sessionDate.day);
    map.update(d, (v) => v + s.duration ~/ 60, ifAbsent: () => s.duration ~/ 60);
  }
  return map;
}

class Achievement {
  const Achievement(this.title, this.description, this.unlocked);
  final String title;
  final String description;
  final bool unlocked;
}

List<Achievement> achievements({
  required List<Course> courses,
  required List<Assignment> assignments,
  required List<StudySession> sessions,
  required List<Flashcard> flashcards,
  required int streak,
}) {
  final completed = assignments.where((a) => a.isCompleted).length;
  final totalMinutes =
      sessions.fold<int>(0, (sum, s) => sum + s.duration ~/ 60);
  final longestSession =
      sessions.fold<int>(0, (m, s) => s.duration > m ? s.duration : m);
  final cleanDeepSession =
      sessions.any((s) => s.duration >= 25 * 60 && s.distractions == 0);
  final reviewed = flashcards.any((f) => f.repetitions > 0);

  return [
    Achievement('First steps', 'Add your first course', courses.isNotEmpty),
    Achievement('Getting organised', 'Create 3 assignments',
        assignments.length >= 3),
    Achievement(
        'Focused', 'Finish your first study session', sessions.isNotEmpty),
    Achievement('Deep work', 'A single session of 50+ minutes',
        longestSession >= 50 * 60),
    Achievement('In the zone', 'A 25+ minute session with no distractions',
        cleanDeepSession),
    Achievement('Task tamer', 'Complete 10 assignments', completed >= 10),
    Achievement('Streak starter', 'Study 3 days in a row', streak >= 3),
    Achievement('On a roll', 'Study 7 days in a row', streak >= 7),
    Achievement('Ten hours in', 'Log 10 hours of study', totalMinutes >= 600),
    Achievement('Card shark', 'Review a flashcard', reviewed),
  ];
}
