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
  final settings = SettingsController(prefs);
  runApp(StudyFlowApp(db: db, settings: settings));
}

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key, required this.db, required this.settings});

  final AppDatabase db;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: db,
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: 'StudyFlow',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(settings.seed),
          darkTheme: buildDarkTheme(settings.seed),
          themeMode: settings.mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: child!,
          ),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
