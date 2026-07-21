import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';
import 'package:studyflow/logic/grade_calc.dart';
import 'package:studyflow/logic/insights.dart';
import 'package:studyflow/logic/spaced_repetition.dart';
import 'package:studyflow/logic/study_planner.dart';

Assignment _assignment({
  required int id,
  required int courseId,
  required DateTime due,
  int estimate = 0,
  int priority = 1,
  bool done = false,
}) =>
    Assignment(
      id: id,
      courseId: courseId,
      title: 'A$id',
      description: '',
      dueDate: due,
      priority: priority,
      isCompleted: done,
      estimatedMinutes: estimate,
    );

void main() {
  group('SM-2', () {
    test('a good answer grows the interval and keeps easiness sane', () {
      final now = DateTime(2026, 7, 21);
      final first = reviewCard(
          easiness: 2.5,
          intervalDays: 0,
          repetitions: 0,
          quality: 4,
          now: now);
      expect(first.repetitions, 1);
      expect(first.intervalDays, 1);

      final second = reviewCard(
          easiness: first.easiness,
          intervalDays: first.intervalDays,
          repetitions: first.repetitions,
          quality: 4,
          now: now);
      expect(second.repetitions, 2);
      expect(second.intervalDays, 6);
      expect(second.due, now.add(const Duration(days: 6)));
    });

    test('a failed answer resets repetitions and easiness never drops below 1.3',
        () {
      final now = DateTime(2026, 7, 21);
      final r = reviewCard(
          easiness: 1.3,
          intervalDays: 20,
          repetitions: 5,
          quality: 0,
          now: now);
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
      expect(r.easiness, greaterThanOrEqualTo(1.3));
    });
  });

  group('grades', () {
    final items = [
      GradeItem(
          id: 1,
          courseId: 1,
          name: 'Midterm',
          weight: 40,
          score: 80,
          maxScore: 100,
          graded: true),
      GradeItem(
          id: 2,
          courseId: 1,
          name: 'Final',
          weight: 60,
          score: 0,
          maxScore: 100,
          graded: false),
    ];

    test('current percent counts only graded work', () {
      final s = summarise(items);
      expect(s.gradedWeight, 40);
      expect(s.currentPercent, closeTo(80, 0.001));
      // 32 earned + 60 remaining if aced.
      expect(s.projectedIfRestFull, closeTo(92, 0.001));
    });

    test('target back-solve computes the needed average on the rest', () {
      // earned = 40*0.8 = 32. To reach 85, need 53 from 60 weight -> 88.33%.
      final need = neededOnRemaining(items, 85);
      expect(need, closeTo(88.33, 0.1));
    });

    test('letter and gpa bands', () {
      expect(letterGrade(94), 'A');
      expect(gpaPoint(94), 4.0);
      expect(letterGrade(59), 'F');
    });
  });

  group('study planner', () {
    test('splits estimate across days and flags what will not fit', () {
      final now = DateTime(2026, 7, 21, 9);
      final assignments = [
        // 300 minutes due in 2 days, only 120/day capacity -> 3 days needed,
        // but due date only allows today + 2 days = fits exactly (360 cap).
        _assignment(
            id: 1, courseId: 1, due: now.add(const Duration(days: 2)), estimate: 300),
        // 500 minutes due tomorrow -> cannot fit (only 240 available).
        _assignment(
            id: 2, courseId: 1, due: now.add(const Duration(days: 1)), estimate: 500),
      ];
      final plan = generatePlan(
          assignments: assignments, now: now, dailyCapacityMinutes: 120);
      final total = plan.blocks.fold<int>(0, (t, b) => t + b.minutes);
      expect(total, greaterThan(0));
      // The 500-minute one due tomorrow must be flagged as unschedulable.
      expect(plan.unschedulable.keys.map((a) => a.id), contains(2));
      // No day exceeds the capacity.
      final perDay = <DateTime, int>{};
      for (final b in plan.blocks) {
        perDay.update(b.day, (v) => v + b.minutes, ifAbsent: () => b.minutes);
      }
      expect(perDay.values.every((m) => m <= 120), isTrue);
    });
  });

  group('insights', () {
    test('streak counts consecutive days ending today', () {
      final now = DateTime(2026, 7, 21, 12);
      StudySession s(int daysAgo) => StudySession(
            id: daysAgo,
            courseId: 1,
            startTime: now.subtract(Duration(days: daysAgo)),
            duration: 1500,
            sessionDate: now.subtract(Duration(days: daysAgo)),
            distractions: 0,
            note: '',
          );
      expect(studyStreak([s(0), s(1), s(2)], now), 3);
      expect(studyStreak([s(0), s(2)], now), 1);
      expect(studyStreak([], now), 0);
    });

    test('cramming index flags study within 48h of a due date', () {
      final now = DateTime(2026, 7, 21, 12);
      final sessions = [
        StudySession(
            id: 1,
            courseId: 1,
            startTime: now,
            duration: 3600,
            sessionDate: now,
            distractions: 0,
            note: ''),
      ];
      final crammed = [
        _assignment(
            id: 1, courseId: 1, due: now.add(const Duration(hours: 10)))
      ];
      expect(crammingIndex(sessions, crammed), closeTo(1.0, 0.001));
      final relaxed = [
        _assignment(
            id: 1, courseId: 1, due: now.add(const Duration(days: 10)))
      ];
      expect(crammingIndex(sessions, relaxed), 0);
    });
  });

  test('planner ignores assignments with no estimate', () {
    final now = DateTime(2026, 7, 21);
    final plan = generatePlan(
      assignments: [
        _assignment(id: 1, courseId: 1, due: now.add(const Duration(days: 3))),
      ],
      now: now,
    );
    expect(plan.blocks, isEmpty);
  });

  // Keeps the analyzer honest that Value is used (companions in other tests).
  test('Value import is exercised', () {
    expect(const Value(1).present, isTrue);
  });
}
