import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/database.dart';
import 'data/vault.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'security/auth.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final auth = AuthController(prefs);
  runApp(StudyFlowApp(prefs: prefs, settings: settings, auth: auth));
}

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({
    super.key,
    required this.prefs,
    required this.settings,
    required this.auth,
  });

  final SharedPreferences prefs;
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
        home: _AuthGate(prefs: prefs, settings: settings, auth: auth),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate(
      {required this.prefs, required this.settings, required this.auth});

  final SharedPreferences prefs;
  final SettingsController settings;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isLoggedIn) return AuthScreen(auth: auth);
        return _SignedInApp(
          key: ValueKey(auth.currentUser),
          prefs: prefs,
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
    required this.prefs,
    required this.settings,
    required this.auth,
  });

  final SharedPreferences prefs;
  final SettingsController settings;
  final AuthController auth;

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final AppDatabase _db = AppDatabase();
  late final Vault _vault =
      Vault(widget.prefs, widget.auth.currentUser!, widget.auth.sessionKey!);

  bool _ready = false;
  bool _autosave = false;
  String? _error;

  StreamSubscription? _updates;
  Timer? _debounce;
  bool _saving = false;
  bool _dirtyAgain = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _vault.loadJson();
      if (json != null) {
        await _db.importBackup(jsonDecode(json) as Map<String, dynamic>);
      }
      // Only start saving after a clean load, so a failed unlock can never
      // overwrite good data.
      _autosave = true;
      _updates = _db.tableUpdates().listen((_) => _scheduleSave());
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _ready = true);
  }

  void _scheduleSave() {
    if (!_autosave) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    if (!_autosave) return;
    if (_saving) {
      _dirtyAgain = true;
      return;
    }
    _saving = true;
    try {
      final snapshot = await _db.exportAll();
      await _vault.saveJson(jsonEncode(snapshot));
    } finally {
      _saving = false;
      if (_dirtyAgain) {
        _dirtyAgain = false;
        _scheduleSave();
      }
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _debounce?.cancel();
    // Best-effort final flush before we tear down (e.g. on logout).
    if (_autosave) _save();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Unlocking your data…'),
            ],
          ),
        ),
      );
    }
    return AppScope(
      db: _db,
      settings: widget.settings,
      auth: widget.auth,
      child: _error == null
          ? const HomeShell()
          : _UnlockError(message: _error!, onLogout: widget.auth.logout),
    );
  }
}

class _UnlockError extends StatelessWidget {
  const _UnlockError({required this.message, required this.onLogout});
  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              const Text('Could not unlock your saved data.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(onPressed: onLogout, child: const Text('Log out')),
            ],
          ),
        ),
      ),
    );
  }
}
