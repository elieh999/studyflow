import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';

// Holds the theme mode and persists the user's choice.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    switch (_prefs.getString(_key)) {
      case 'dark':
        _mode = ThemeMode.dark;
      case 'light':
        _mode = ThemeMode.light;
      default:
        _mode = ThemeMode.system;
    }
  }

  static const _key = 'themeMode';
  final SharedPreferences _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> setDark(bool on) async {
    _mode = on ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString(_key, on ? 'dark' : 'light');
    notifyListeners();
  }
}

// Makes the database and theme controller available to the whole widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.theme,
    required super.child,
  });

  final AppDatabase db;
  final ThemeController theme;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
