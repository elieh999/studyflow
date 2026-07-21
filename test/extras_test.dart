import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/logic/gamification.dart';
import 'package:studyflow/logic/study_tips.dart';

void main() {
  group('gamification', () {
    test('level rises with study minutes', () {
      expect(levelForMinutes(0), 1);
      expect(levelForMinutes(20), 1);
      expect(levelForMinutes(30), 2);
      expect(levelForMinutes(120), 3);
      expect(levelForMinutes(270), 4);
    });

    test('level thresholds are consistent', () {
      for (var l = 1; l <= 10; l++) {
        final need = minutesForLevel(l);
        expect(levelForMinutes(need), greaterThanOrEqualTo(l));
      }
    });

    test('progress is between 0 and 1', () {
      for (final m in [0, 15, 45, 200, 5000]) {
        final p = levelProgress(m);
        expect(p, inInclusiveRange(0.0, 1.0));
      }
    });

    test('titles are non-empty and scale up', () {
      expect(levelTitle(1), isNotEmpty);
      expect(levelTitle(12), 'Scholar');
    });
  });

  group('study tips', () {
    test('same day gives the same tip, and it is from the list', () {
      final a = tipForDay(DateTime(2026, 7, 21, 9));
      final b = tipForDay(DateTime(2026, 7, 21, 18));
      expect(a, b);
      expect(studyTips, contains(a));
    });

    test('different days can rotate', () {
      final tips = {
        for (var i = 0; i < studyTips.length; i++)
          tipForDay(DateTime(2026, 1, 1).add(Duration(days: i)))
      };
      // Over a full cycle we should see more than one distinct tip.
      expect(tips.length, greaterThan(1));
    });
  });
}
