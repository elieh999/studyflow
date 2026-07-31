import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/security/auth.dart';
import 'package:studyflow/security/crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('password hashing', () {
    test('argon2id hash verifies and does not need a rehash', () async {
      final h = await hashPassword('correct horse');
      expect(h.algo, 'argon2id');
      expect(await verifyPassword('correct horse', h), isTrue);
      expect(await verifyPassword('wrong horse', h), isFalse);
      expect(needsRehash(h), isFalse);
    });

    test('legacy pbkdf2 hash still verifies but is flagged for rehash', () async {
      final legacy = await pbkdf2HashForTesting('oldpass');
      expect(legacy.algo, 'pbkdf2');
      expect(await verifyPassword('oldpass', legacy), isTrue);
      expect(await verifyPassword('nope', legacy), isFalse);
      expect(needsRehash(legacy), isTrue);
    });

    test('a legacy JSON record without an algo field parses as pbkdf2', () {
      final h = PasswordHash.fromJson(
          {'salt': 'c2FsdA==', 'hash': 'aGFzaA==', 'iterations': 150000});
      expect(h.algo, 'pbkdf2');
      expect(h.params['iterations'], 150000);
    });
  });

  group('auth lockout', () {
    test('rejects weak passwords for encrypted local accounts', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthController(await SharedPreferences.getInstance());

      expect(
        await auth.register('short', 'abc123'),
        'Password must be at least 10 characters.',
      );
      expect(
        await auth.register('letters', 'abcdefghij'),
        'Password must include a letter and a number.',
      );
    });

    test('locks after repeated failures and unlocks once time passes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 7, 28, 12);
      final auth = AuthController(prefs, clock: () => now);

      expect(await auth.register('bob', 'correct1234'), isNull);
      auth.logout();

      for (var i = 0; i < 5; i++) {
        expect(await auth.login('bob', 'wrong'), 'Incorrect password.');
      }
      // Sixth attempt is refused by the lockout, even with the right password.
      expect(await auth.login('bob', 'wrong'), contains('Too many attempts'));
      expect(auth.lockRemainingSeconds('bob'), greaterThan(0));
      expect(
          await auth.login('bob', 'correct1234'), contains('Too many attempts'));

      // Move past the lockout window.
      now = now.add(const Duration(seconds: 40));
      expect(auth.lockRemainingSeconds('bob'), 0);
      expect(await auth.login('bob', 'correct1234'), isNull);
      expect(auth.isLoggedIn, isTrue);
    });
  });

  group('migration on login', () {
    test('an old pbkdf2 account is upgraded to argon2id after signing in',
        () async {
      final legacy = await pbkdf2HashForTesting('mypassword');
      final account = Account('alice', legacy, ''); // legacy: no vault salt
      SharedPreferences.setMockInitialValues({
        'accounts': jsonEncode([account.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = AuthController(prefs);

      expect(await auth.login('alice', 'mypassword'), isNull);

      final stored = (jsonDecode(prefs.getString('accounts')!) as List)
          .cast<Map<String, dynamic>>();
      final cred = PasswordHash.fromJson(
          (stored.first['cred'] as Map).cast<String, dynamic>());
      expect(cred.algo, 'argon2id');
      // And the upgraded hash still verifies the same password.
      expect(await verifyPassword('mypassword', cred), isTrue);
      // The account also gains a vault salt and a session key on login.
      expect(stored.first['encSalt'] as String, isNotEmpty);
      expect(auth.sessionKey, isNotNull);
    });
  });
}

