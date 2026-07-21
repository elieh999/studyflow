import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/database.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'security/auth.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final auth = AuthController(prefs);
  runApp(StudyFlowApp(settings: settings, auth: auth));
}

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key, required this.settings, required this.auth});

  final SettingsController settings;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
        home: _AuthGate(settings: settings, auth: auth),
      ),
    );
  }
}

// Shows the login/register screen until someone signs in, then opens that
// user's own database and runs the app.
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.settings, required this.auth});

  final SettingsController settings;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isLoggedIn) {
          return AuthScreen(auth: auth);
        }
        return _SignedInApp(
          key: ValueKey(auth.currentUser),
          settings: settings,
          auth: auth,
        );
      },
    );
  }
}

class _SignedInApp extends StatefulWidget {
  const _SignedInApp({
    super.key,
    required this.settings,
    required this.auth,
  });

  final SettingsController settings;
  final AuthController auth;

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final AppDatabase _db = AppDatabase(widget.auth.databaseName);

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: _db,
      settings: widget.settings,
      auth: widget.auth,
      child: const HomeShell(),
    );
  }
}
