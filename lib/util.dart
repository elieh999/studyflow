import 'package:flutter/material.dart';

// A small fixed palette so courses get distinct, pleasant colours.
const courseColorPalette = <Color>[
  Color(0xFF4F86C6),
  Color(0xFF66A182),
  Color(0xFFE0A458),
  Color(0xFFCC6B8E),
  Color(0xFF8E7CC3),
  Color(0xFF4FB0AE),
  Color(0xFFD96C6C),
  Color(0xFF7A8B99),
];

String priorityLabel(int p) => switch (p) {
      2 => 'High',
      1 => 'Medium',
      _ => 'Low',
    };

Color priorityColor(int p) => switch (p) {
      2 => const Color(0xFFD64545),
      1 => const Color(0xFFDB8B00),
      _ => const Color(0xFF3F9142),
    };

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String weekdayName(int dayOfWeek) => weekdayNames[(dayOfWeek - 1).clamp(0, 6)];

// Format a duration given in seconds as e.g. "1h 20m" or "45m" or "30s".
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}

// Monday 00:00 of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}
