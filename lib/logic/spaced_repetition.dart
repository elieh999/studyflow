// A trimmed-down SM-2 spaced-repetition scheduler (the algorithm Anki is based
// on). Given how well the student recalled a card, it works out the new
// easiness factor, the next interval in days, and when the card is next due.

class Sm2Result {
  const Sm2Result({
    required this.easiness,
    required this.intervalDays,
    required this.repetitions,
    required this.due,
  });

  final double easiness;
  final int intervalDays;
  final int repetitions;
  final DateTime due;
}

// quality: 0 = forgot, 3 = hard, 4 = good, 5 = easy.
Sm2Result reviewCard({
  required double easiness,
  required int intervalDays,
  required int repetitions,
  required int quality,
  required DateTime now,
}) {
  var ef = easiness;
  var reps = repetitions;
  var interval = intervalDays;

  if (quality < 3) {
    // Failed recall: start the card over, see it again tomorrow.
    reps = 0;
    interval = 1;
  } else {
    if (reps == 0) {
      interval = 1;
    } else if (reps == 1) {
      interval = 6;
    } else {
      interval = (interval * ef).round();
    }
    reps += 1;
  }

  // Update the easiness factor and clamp it to the SM-2 floor of 1.3.
  ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (ef < 1.3) ef = 1.3;

  final today = DateTime(now.year, now.month, now.day);
  return Sm2Result(
    easiness: ef,
    intervalDays: interval,
    repetitions: reps,
    due: today.add(Duration(days: interval)),
  );
}
