import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/database.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  final theme = ThemeController(prefs);
  runApp(StudyFlowApp(db: db, theme: theme));
}

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key, required this.db, required this.theme});

  final AppDatabase db;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: db,
      theme: theme,
      child: AnimatedBuilder(
        animation: theme,
        builder: (context, _) => MaterialApp(
          title: 'StudyFlow',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: theme.mode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
