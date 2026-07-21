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

ThemeData buildLightTheme(Color seed) =>
    _base(ColorScheme.fromSeed(seedColor: seed), Brightness.light);

ThemeData buildDarkTheme(Color seed) => _base(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    Brightness.dark);

ThemeData _base(ColorScheme scheme, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  // A soft tinted canvas rather than flat grey/black, so the UI feels alive.
  final scaffold = isLight
      ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.04), Colors.white)
      : Color.alphaBlend(scheme.primary.withValues(alpha: 0.05),
          const Color(0xFF141519));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isLight
          ? Colors.white
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.06), const Color(0xFF1D1F24)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.5 : 0.3)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isLight
          ? Colors.white
          : Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.05), const Color(0xFF17181C)),
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: TextStyle(
          color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle:
          TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    dialogTheme: DialogThemeData(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}

// A reusable gradient header band used at the top of key screens.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: scheme.onPrimary, size: 30),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.9))),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
