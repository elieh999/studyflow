import 'dart:math' as math;

// A light XP/level system: XP is just total minutes studied. Each level needs a
// bit more than the last (a gentle quadratic curve).

int minutesForLevel(int level) => (level - 1) * (level - 1) * 30;

int levelForMinutes(int minutes) {
  if (minutes <= 0) return 1;
  return (math.sqrt(minutes / 30)).floor() + 1;
}

// 0..1 progress from the current level toward the next.
double levelProgress(int minutes) {
  final level = levelForMinutes(minutes);
  final base = minutesForLevel(level);
  final next = minutesForLevel(level + 1);
  if (next <= base) return 0;
  return ((minutes - base) / (next - base)).clamp(0.0, 1.0);
}

String levelTitle(int level) {
  if (level >= 12) return 'Scholar';
  if (level >= 9) return 'Honours student';
  if (level >= 6) return 'Dedicated';
  if (level >= 4) return 'Getting serious';
  if (level >= 2) return 'Warming up';
  return 'Beginner';
}
