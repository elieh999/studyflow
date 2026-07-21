import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';

class Account {
  const Account(this.username, this.cred);
  final String username;
  final PasswordHash cred;

  Map<String, dynamic> toJson() =>
      {'username': username, 'cred': cred.toJson()};

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        j['username'] as String,
        PasswordHash.fromJson((j['cred'] as Map).cast<String, dynamic>()),
      );
}

// Manages local accounts. Credentials are stored as salted PBKDF2 hashes in
// shared_preferences; each account's study data lives in its own database.
class AuthController extends ChangeNotifier {
  AuthController(this._prefs) {
    final raw = _prefs.getString(_kAccounts);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _accounts = list.map(Account.fromJson).toList();
    }
    _lastUser = _prefs.getString(_kLastUser);
  }

  static const _kAccounts = 'accounts';
  static const _kLastUser = 'lastUser';

  final SharedPreferences _prefs;
  List<Account> _accounts = [];
  String? _currentUser;
  String? _lastUser;

  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;
  String? get lastUser => _lastUser;
  bool get hasAccounts => _accounts.isNotEmpty;
  List<String> get usernames => _accounts.map((a) => a.username).toList();

  // A filesystem/IndexedDB-safe database name unique to the signed-in user.
  String get databaseName {
    final safe = (_currentUser ?? 'default')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'studyflow_$safe';
  }

  Future<void> _persist() async {
    await _prefs.setString(
        _kAccounts, jsonEncode(_accounts.map((a) => a.toJson()).toList()));
  }

  Future<String?> register(String username, String password) async {
    final name = username.trim();
    if (name.isEmpty) return 'Please choose a username.';
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (_accounts.any((a) => a.username.toLowerCase() == name.toLowerCase())) {
      return 'That username is already taken.';
    }
    final cred = await hashPassword(password);
    _accounts = [..._accounts, Account(name, cred)];
    await _persist();
    _currentUser = name;
    _lastUser = name;
    await _prefs.setString(_kLastUser, name);
    notifyListeners();
    return null;
  }

  Future<String?> login(String username, String password) async {
    final account = _accounts
        .where((a) => a.username.toLowerCase() == username.trim().toLowerCase())
        .cast<Account?>()
        .firstOrNull;
    if (account == null) return 'No account with that username.';
    final ok = await verifyPassword(password, account.cred);
    if (!ok) return 'Incorrect password.';
    _currentUser = account.username;
    _lastUser = account.username;
    await _prefs.setString(_kLastUser, account.username);
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
