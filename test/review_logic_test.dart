import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/database.dart';
import 'package:studyflow/logic/grade_calc.dart';
import 'package:studyflow/logic/insights.dart';
import 'package:studyflow/logic/spaced_repetition.dart';
import 'package:studyflow/logic/study_planner.dart';

Assignment _a({
  required int id,
  required DateTime due,
  int estimate = 0,
  int priority = 1,
  bool done = false,
}) =>
    Assignment(
      id: id,
      courseId: 1,
      title: 'A$id',
      description: '',
      dueDate: due,
      priority: priority,
      isCompleted: done,
      estimatedMinutes: estimate,
    );

GradeItem _g(String name, double weight,
        {bool graded = false, double score = 0, double max = 100}) =>
    GradeItem(
        id: name.hashCode,
        courseId: 1,
        name: name,
        weight: weight,
        score: score,
        maxScore: max,
        graded: graded);

StudySession _s(int id, DateTime when, {int seconds = 1500}) => StudySession(
      id: id,
      courseId: 1,
      startTime: when,
      duration: seconds,
      sessionDate: when,
      distractions: 0,
      note: '',
    );

void main() {
  group('study planner', () {
    final now = DateTime(2026, 7, 28, 9);
    int usedOn(StudyPlan p, DateTime day) => p.blocks
        .where((b) => b.day == DateTime(day.year, day.month, day.day))
        .fold(0, (t, b) => t + b.minutes);

    test('fills a full day up to capacity (regression: was capped at one block)',
        () {
      // 120 minutes due today, capacity 120 -> must all fit today.
      final plan = generatePlan(
        assignments: [_a(id: 1, due: now, estimate: 120)],
        now: now,
        dailyCapacityMinutes: 120,
        maxBlockMinutes: 60,
      );
      expect(plan.unschedulable, isEmpty);
      expect(usedOn(plan, now), 120);
      // Split into two 60-minute blocks on the same day.
      expect(plan.blocks.length, 2);
    });

    test('never exceeds daily capacity', () {
      final plan = generatePlan(
        assignments: [_a(id: 1, due: now.add(const Duration(days: 5)), estimate: 600)],
        now: now,
        dailyCapacityMinutes: 90,
      );
      for (var d = 0; d <= 5; d++) {
        expect(usedOn(plan, now.add(Duration(days: d))), lessThanOrEqualTo(90));
      }
    });

    test('overdue assignment cannot be scheduled', () {
      final plan = generatePlan(
        assignments: [_a(id: 1, due: now.subtract(const Duration(days: 1)), estimate: 60)],
        now: now,
      );
      expect(plan.blocks, isEmpty);
      expect(plan.unschedulable.keys.map((a) => a.id), contains(1));
      expect(plan.unschedulable.values.first, 60);
    });

    test('zero and negative estimates are ignored', () {
      final plan = generatePlan(
        assignments: [
          _a(id: 1, due: now.add(const Duration(days: 2)), estimate: 0),
          _a(id: 2, due: now.add(const Duration(days: 2)), estimate: -30),
        ],
        now: now,
      );
      expect(plan.blocks, isEmpty);
      expect(plan.unschedulable, isEmpty);
    });

    test('daily capacity of zero schedules nothing', () {
      final plan = generatePlan(
        assignments: [_a(id: 1, due: now.add(const Duration(days: 3)), estimate: 60)],
        now: now,
        dailyCapacityMinutes: 0,
      );
      expect(plan.blocks, isEmpty);
      expect(plan.unschedulable[_findKey(plan, 1)], 60);
    });

    test('estimate exceeding all remaining capacity lands the overflow in unschedulable',
        () {
      // Due tomorrow -> only today + tomorrow (2 days) at 60/day = 120 possible.
      final plan = generatePlan(
        assignments: [_a(id: 1, due: now.add(const Duration(days: 1)), estimate: 200)],
        now: now,
        dailyCapacityMinutes: 60,
      );
      final scheduled = plan.blocks.fold<int>(0, (t, b) => t + b.minutes);
      expect(scheduled, 120);
      expect(plan.unschedulable[_findKey(plan, 1)], 80);
    });

    test('overlapping deadlines: earliest deadline wins the earlier slots', () {
      final soon = _a(id: 1, due: now.add(const Duration(days: 1)), estimate: 120);
      final later = _a(id: 2, due: now.add(const Duration(days: 1)), estimate: 120, priority: 2);
      final plan = generatePlan(
        assignments: [later, soon],
        now: now,
        dailyCapacityMinutes: 120,
      );
      // Same due date -> higher priority (later, priority 2) is placed first today.
      final todayBlocks = plan.blocks
          .where((b) => b.day == DateTime(now.year, now.month, now.day))
          .toList();
      expect(todayBlocks.first.assignmentId, 2);
      expect(plan.unschedulable, isEmpty); // 120 today + 120 tomorrow = 240 fits
    });
  });

  group('grades', () {
    test('weights that do not sum to 100 still scale sensibly', () {
      final items = [
        _g('Midterm', 40, graded: true, score: 90, max: 100),
        _g('Project', 40, graded: true, score: 80, max: 100),
      ]; // total weight 80, both graded
      final s = summarise(items);
      expect(s.gradedWeight, 80);
      // earned = 40*.9 + 40*.8 = 36 + 32 = 68 ; current = 68/80*100 = 85
      expect(s.currentPercent, closeTo(85, 0.001));
    });

    test('a course with no graded components yet', () {
      final items = [_g('Final', 100)];
      final s = summarise(items);
      expect(s.currentPercent, isNull);
      expect(s.projectedIfRestFull, closeTo(100, 0.001));
      // needs 90 on the remaining 100 weight to reach 90
      expect(neededOnRemaining(items, 90), closeTo(90, 0.001));
    });

    test('an already unreachable target reports over 100 (infeasible), not nonsense',
        () {
      // Midterm 60% scored 20/100 -> earned 12. Final 40% remaining.
      // To hit 90 you would need (90-12)/40*100 = 195% on the final: impossible.
      final items = [
        _g('Midterm', 60, graded: true, score: 20, max: 100),
        _g('Final', 40),
      ];
      final need = neededOnRemaining(items, 90);
      expect(need, isNotNull);
      expect(need! > 100, isTrue);
    });

    test('no remaining weight returns null', () {
      final items = [_g('Only', 100, graded: true, score: 50, max: 100)];
      expect(neededOnRemaining(items, 90), isNull);
    });
  });

  group('SM-2', () {
    test('answering "again" repeatedly floors the ease factor at 1.3', () {
      var ease = 2.5, interval = 0, reps = 0;
      final now = DateTime(2026, 7, 28);
      for (var i = 0; i < 12; i++) {
        final r = reviewCard(
            easiness: ease,
            intervalDays: interval,
            repetitions: reps,
            quality: 0,
            now: now);
        ease = r.easiness;
        interval = r.intervalDays;
        reps = r.repetitions;
        expect(r.repetitions, 0);
        expect(r.intervalDays, 1);
      }
      expect(ease, closeTo(1.3, 0.0001));
    });

    test('intervals grow over many good reviews', () {
      var ease = 2.5, interval = 0, reps = 0;
      final now = DateTime(2026, 7, 28);
      final seen = <int>[];
      for (var i = 0; i < 6; i++) {
        final r = reviewCard(
            easiness: ease,
            intervalDays: interval,
            repetitions: reps,
            quality: 5,
            now: now);
        ease = r.easiness;
        interval = r.intervalDays;
        reps = r.repetitions;
        seen.add(interval);
      }
      // 1, 6, then strictly increasing.
      expect(seen.first, 1);
      expect(seen[1], 6);
      for (var i = 2; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
    });
  });

  group('streak and heatmap', () {
    test('sessions on the same calendar day count once; midnight boundary splits days',
        () {
      final now = DateTime(2026, 7, 28, 12);
      final lateLastNight = DateTime(2026, 7, 27, 23, 59);
      final earlyToday = DateTime(2026, 7, 28, 0, 1);
      expect(studyStreak([_s(1, lateLastNight), _s(2, earlyToday)], now), 2);

      final byDay = minutesByDay([_s(1, lateLastNight), _s(2, earlyToday)]);
      expect(byDay[DateTime(2026, 7, 27)], 25);
      expect(byDay[DateTime(2026, 7, 28)], 25);
    });

    test('streak counts back only through consecutive days', () {
      final now = DateTime(2026, 7, 28, 12);
      final sessions = [
        _s(1, DateTime(2026, 7, 28, 10)),
        _s(2, DateTime(2026, 7, 27, 10)),
        _s(3, DateTime(2026, 7, 25, 10)), // gap on the 26th
      ];
      expect(studyStreak(sessions, now), 2);
    });
  });
}

Assignment _findKey(StudyPlan plan, int id) =>
    plan.unschedulable.keys.firstWhere((a) => a.id == id);
