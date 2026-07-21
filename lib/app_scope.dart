import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';
import 'theme.dart';

// Holds all user preferences and persists them. Any change notifies listeners
// so the app rebuilds (theme, text size, etc.).
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    switch (_prefs.getString(_kMode)) {
      case 'dark':
        _mode = ThemeMode.dark;
      case 'light':
        _mode = ThemeMode.light;
      default:
        _mode = ThemeMode.system;
    }
    _seed = Color(_prefs.getInt(_kSeed) ?? accentThemes.first.seed.toARGB32());
    _textScale = _prefs.getDouble(_kScale) ?? 1.0;
    _studyMinutes = _prefs.getInt(_kStudy) ?? 25;
    _breakMinutes = _prefs.getInt(_kBreak) ?? 5;
    _longBreakMinutes = _prefs.getInt(_kLongBreak) ?? 15;
    _longBreakEvery = _prefs.getInt(_kLongEvery) ?? 4;
    _dailyGoalMinutes = _prefs.getInt(_kGoal) ?? 120;
    _aiModel = _prefs.getString(_kModel) ?? 'qwen2.5:0.5b';
  }

  static const _kMode = 'themeMode';
  static const _kSeed = 'seedColor';
  static const _kScale = 'textScale';
  static const _kStudy = 'studyMinutes';
  static const _kBreak = 'breakMinutes';
  static const _kLongBreak = 'longBreakMinutes';
  static const _kLongEvery = 'longBreakEvery';
  static const _kGoal = 'dailyGoalMinutes';
  static const _kModel = 'aiModel';

  final SharedPreferences _prefs;

  late ThemeMode _mode;
  late Color _seed;
  late double _textScale;
  late int _studyMinutes;
  late int _breakMinutes;
  late int _longBreakMinutes;
  late int _longBreakEvery;
  late int _dailyGoalMinutes;
  late String _aiModel;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  Color get seed => _seed;
  double get textScale => _textScale;
  int get studyMinutes => _studyMinutes;
  int get breakMinutes => _breakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get longBreakEvery => _longBreakEvery;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  String get aiModel => _aiModel;

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    await _prefs.setString(
        _kMode,
        switch (m) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          ThemeMode.system => 'system',
        });
    notifyListeners();
  }

  Future<void> setDark(bool on) => setMode(on ? ThemeMode.dark : ThemeMode.light);

  Future<void> setSeed(Color c) async {
    _seed = c;
    await _prefs.setInt(_kSeed, c.toARGB32());
    notifyListeners();
  }

  Future<void> setTextScale(double v) async {
    _textScale = v;
    await _prefs.setDouble(_kScale, v);
    notifyListeners();
  }

  Future<void> setStudyMinutes(int v) async {
    _studyMinutes = v;
    await _prefs.setInt(_kStudy, v);
    notifyListeners();
  }

  Future<void> setBreakMinutes(int v) async {
    _breakMinutes = v;
    await _prefs.setInt(_kBreak, v);
    notifyListeners();
  }

  Future<void> setLongBreakMinutes(int v) async {
    _longBreakMinutes = v;
    await _prefs.setInt(_kLongBreak, v);
    notifyListeners();
  }

  Future<void> setLongBreakEvery(int v) async {
    _longBreakEvery = v;
    await _prefs.setInt(_kLongEvery, v);
    notifyListeners();
  }

  Future<void> setDailyGoal(int v) async {
    _dailyGoalMinutes = v;
    await _prefs.setInt(_kGoal, v);
    notifyListeners();
  }

  Future<void> setAiModel(String v) async {
    _aiModel = v.trim();
    await _prefs.setString(_kModel, _aiModel);
    notifyListeners();
  }
}

// Makes the database and settings available to the whole widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.settings,
    required super.child,
  });

  final AppDatabase db;
  final SettingsController settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
