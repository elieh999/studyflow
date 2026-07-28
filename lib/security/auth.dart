import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';

class Account {
  const Account(this.username, this.cred, this.encSalt);
  final String username;
  final PasswordHash cred;
  // Salt used to derive the database encryption key. Empty for legacy accounts
  // created before at-rest encryption; filled in on the next login.
  final String encSalt;

  Account copyWith({PasswordHash? cred, String? encSalt}) =>
      Account(username, cred ?? this.cred, encSalt ?? this.encSalt);

  Map<String, dynamic> toJson() =>
      {'username': username, 'cred': cred.toJson(), 'encSalt': encSalt};

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        j['username'] as String,
        PasswordHash.fromJson((j['cred'] as Map).cast<String, dynamic>()),
        j['encSalt'] as String? ?? '',
      );
}

// Manages local accounts. Credentials are stored as Argon2id hashes in
// shared_preferences (legacy PBKDF2 hashes are still accepted and upgraded on
// login); each account's study data lives in its own database. A small
// lockout guards against repeated wrong password guesses.
class AuthController extends ChangeNotifier {
  AuthController(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final raw = _prefs.getString(_kAccounts);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _accounts = list.map(Account.fromJson).toList();
    }
    _lastUser = _prefs.getString(_kLastUser);
    final locks = _prefs.getString(_kLockouts);
    if (locks != null) {
      (jsonDecode(locks) as Map<String, dynamic>).forEach((k, v) {
        final m = (v as Map).cast<String, dynamic>();
        _lockouts[k] = _Lockout(
          fails: m['fails'] as int? ?? 0,
          untilMillis: m['until'] as int? ?? 0,
        );
      });
    }
  }

  static const _kAccounts = 'accounts';
  static const _kLastUser = 'lastUser';
  static const _kLockouts = 'loginLockouts';

  // After this many consecutive wrong guesses the account locks, then the
  // lockout doubles each further failure up to the cap.
  static const int _lockThreshold = 5;
  static const int _baseLockSeconds = 30;
  static const int _maxLockSeconds = 900;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  List<Account> _accounts = [];
  final Map<String, _Lockout> _lockouts = {};
  String? _currentUser;
  String? _lastUser;
  List<int>? _sessionKey;

  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;
  String? get lastUser => _lastUser;

  // The database encryption key for the signed-in user. Only in memory, only
  // while logged in. Never persisted anywhere.
  List<int>? get sessionKey => _sessionKey;
  bool get hasAccounts => _accounts.isNotEmpty;
  List<String> get usernames => _accounts.map((a) => a.username).toList();

  String get databaseName {
    final safe = (_currentUser ?? 'default')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'studyflow_$safe';
  }

  // Seconds left on an active lockout for [username], or 0 if not locked.
  int lockRemainingSeconds(String username) {
    final lock = _lockouts[username.toLowerCase()];
    if (lock == null) return 0;
    final remaining =
        lock.untilMillis - _clock().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  Future<void> _persistAccounts() async {
    await _prefs.setString(
        _kAccounts, jsonEncode(_accounts.map((a) => a.toJson()).toList()));
  }

  Future<void> _persistLockouts() async {
    await _prefs.setString(
      _kLockouts,
      jsonEncode(_lockouts.map((k, v) =>
          MapEntry(k, {'fails': v.fails, 'until': v.untilMillis}))),
    );
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
    final encSalt = newSaltBase64();
    _accounts = [..._accounts, Account(name, cred, encSalt)];
    await _persistAccounts();
    _sessionKey = await deriveVaultKey(password, encSalt);
    _currentUser = name;
    _lastUser = name;
    await _prefs.setString(_kLastUser, name);
    notifyListeners();
    return null;
  }

  Future<String?> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    final index =
        _accounts.indexWhere((a) => a.username.toLowerCase() == key);
    if (index < 0) return 'No account with that username.';

    final locked = lockRemainingSeconds(key);
    if (locked > 0) {
      return 'Too many attempts. Try again in $locked seconds.';
    }

    final account = _accounts[index];
    final ok = await verifyPassword(password, account.cred);
    if (!ok) {
      await _recordFailure(key);
      return 'Incorrect password.';
    }

    // Success: clear any lockout.
    _lockouts.remove(key);
    await _persistLockouts();

    var acc = account;
    var changed = false;
    // Legacy accounts (made before at-rest encryption) have no vault salt yet.
    var encSalt = acc.encSalt;
    if (encSalt.isEmpty) {
      encSalt = newSaltBase64();
      changed = true;
    }
    // Upgrade an old PBKDF2 hash to Argon2id on the way in.
    var cred = acc.cred;
    if (needsRehash(acc.cred)) {
      cred = await hashPassword(password);
      changed = true;
    }
    if (changed) {
      acc = acc.copyWith(cred: cred, encSalt: encSalt);
      _accounts[index] = acc;
      await _persistAccounts();
    }
    _sessionKey = await deriveVaultKey(password, encSalt);
    _currentUser = acc.username;
    _lastUser = acc.username;
    await _prefs.setString(_kLastUser, acc.username);
    notifyListeners();
    return null;
  }

  Future<void> _recordFailure(String key) async {
    final current = _lockouts[key] ?? const _Lockout(fails: 0, untilMillis: 0);
    final fails = current.fails + 1;
    var untilMillis = 0;
    if (fails >= _lockThreshold) {
      final seconds = math.min(
          _baseLockSeconds * (1 << (fails - _lockThreshold)), _maxLockSeconds);
      untilMillis =
          _clock().millisecondsSinceEpoch + seconds * 1000;
    }
    _lockouts[key] = _Lockout(fails: fails, untilMillis: untilMillis);
    await _persistLockouts();
  }

  void logout() {
    _currentUser = null;
    _sessionKey = null;
    notifyListeners();
  }
}

class _Lockout {
  const _Lockout({required this.fails, required this.untilMillis});
  final int fails;
  final int untilMillis;
}
