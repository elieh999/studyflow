import 'package:flutter/material.dart';

// The accent colours a user can pick in Settings. The whole app (charts, the
// focus garden, buttons) is driven off the chosen seed via ColorScheme.fromSeed.
class AccentTheme {
  const AccentTheme(this.name, this.seed);
  final String name;
  final Color seed;
}

const accentThemes = <AccentTheme>[
  AccentTheme('Ocean', Color(0xFF4F86C6)),
  AccentTheme('Teal', Color(0xFF20A4A0)),
  AccentTheme('Emerald', Color(0xFF2E9E67)),
  AccentTheme('Violet', Color(0xFF7A5CC6)),
  AccentTheme('Indigo', Color(0xFF4E5BD6)),
  AccentTheme('Rose', Color(0xFFD6608E)),
  AccentTheme('Amber', Color(0xFFE0952B)),
  AccentTheme('Crimson', Color(0xFFD64545)),
  AccentTheme('Sunset', Color(0xFFEF6C4D)),
  AccentTheme('Slate', Color(0xFF5C6B7A)),
];

ThemeData buildLightTheme(Color seed) {
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F7F9),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
  );
}

ThemeData buildDarkTheme(Color seed) {
  final scheme =
      ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
  );
}
