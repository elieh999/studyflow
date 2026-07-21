import '../data/database.dart';

// Grade maths for a single course. Weights are percentages (ideally summing to
// 100). Each item contributes (weight * score/maxScore) points toward a final
// mark out of 100.

class GradeSummary {
  const GradeSummary({
    required this.gradedWeight,
    required this.pointsEarned,
    required this.currentPercent,
    required this.projectedIfRestFull,
  });

  // Sum of the weights of items that have actually been graded.
  final double gradedWeight;

  // Points earned so far, out of 100.
  final double pointsEarned;

  // Your mark considering only graded work (earned / gradedWeight * 100).
  final double? currentPercent;

  // Final mark if you scored 100% on everything not yet graded.
  final double projectedIfRestFull;
}

GradeSummary summarise(List<GradeItem> items) {
  var gradedWeight = 0.0;
  var earned = 0.0;
  var totalWeight = 0.0;
  for (final it in items) {
    totalWeight += it.weight;
    if (it.graded && it.maxScore > 0) {
      gradedWeight += it.weight;
      earned += it.weight * (it.score / it.maxScore);
    }
  }
  final remainingWeight = (totalWeight - gradedWeight).clamp(0, totalWeight);
  return GradeSummary(
    gradedWeight: gradedWeight,
    pointsEarned: earned,
    currentPercent: gradedWeight > 0 ? earned / gradedWeight * 100 : null,
    projectedIfRestFull: earned + remainingWeight,
  );
}

// What average (%) is needed on the not-yet-graded work to finish at [target]%.
// Returns null when there's no remaining weight to score on.
double? neededOnRemaining(List<GradeItem> items, double target) {
  var gradedWeight = 0.0;
  var earned = 0.0;
  var totalWeight = 0.0;
  for (final it in items) {
    totalWeight += it.weight;
    if (it.graded && it.maxScore > 0) {
      gradedWeight += it.weight;
      earned += it.weight * (it.score / it.maxScore);
    }
  }
  final remainingWeight = totalWeight - gradedWeight;
  if (remainingWeight <= 0) return null;
  return (target - earned) / remainingWeight * 100;
}

// A simple 4.0-scale GPA point from a percentage (common US-style bands).
double gpaPoint(double percent) {
  if (percent >= 93) return 4.0;
  if (percent >= 90) return 3.7;
  if (percent >= 87) return 3.3;
  if (percent >= 83) return 3.0;
  if (percent >= 80) return 2.7;
  if (percent >= 77) return 2.3;
  if (percent >= 73) return 2.0;
  if (percent >= 70) return 1.7;
  if (percent >= 67) return 1.3;
  if (percent >= 60) return 1.0;
  return 0.0;
}

String letterGrade(double percent) {
  if (percent >= 93) return 'A';
  if (percent >= 90) return 'A-';
  if (percent >= 87) return 'B+';
  if (percent >= 83) return 'B';
  if (percent >= 80) return 'B-';
  if (percent >= 77) return 'C+';
  if (percent >= 73) return 'C';
  if (percent >= 70) return 'C-';
  if (percent >= 67) return 'D+';
  if (percent >= 60) return 'D';
  return 'F';
}
