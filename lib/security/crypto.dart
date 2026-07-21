import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

// Real, standard cryptography for a local app:
//  - passwords are stretched with PBKDF2-HMAC-SHA256 (salted, 150k iterations)
//    and only the derived hash is ever stored — never the password itself;
//  - backups can be sealed with AES-256-GCM using a key derived the same way.
//
// This protects credentials and exported files. It is NOT a substitute for a
// server: the live local database is still readable by anyone with file access.

const int kIterations = 150000;

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

Future<List<int>> _derive(String password, List<int> salt, int iterations,
    {int bytes = 32}) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: bytes * 8,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return key.extractBytes();
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class PasswordHash {
  const PasswordHash(this.salt, this.hash, this.iterations);
  final String salt; // base64
  final String hash; // base64
  final int iterations;

  Map<String, dynamic> toJson() =>
      {'salt': salt, 'hash': hash, 'iterations': iterations};

  factory PasswordHash.fromJson(Map<String, dynamic> j) => PasswordHash(
        j['salt'] as String,
        j['hash'] as String,
        (j['iterations'] as int?) ?? kIterations,
      );
}

Future<PasswordHash> hashPassword(String password) async {
  final salt = _randomBytes(16);
  final derived = await _derive(password, salt, kIterations);
  return PasswordHash(
      base64Encode(salt), base64Encode(derived), kIterations);
}

Future<bool> verifyPassword(String password, PasswordHash stored) async {
  final salt = base64Decode(stored.salt);
  final derived = await _derive(password, salt, stored.iterations);
  return _constantTimeEquals(derived, base64Decode(stored.hash));
}

// Seal a string with AES-256-GCM; the result is a self-describing JSON envelope
// that carries the salt/nonce/mac needed to open it again with the passphrase.
Future<String> encryptString(String plaintext, String passphrase) async {
  final salt = _randomBytes(16);
  final keyBytes = await _derive(passphrase, salt, kIterations);
  final algo = AesGcm.with256bits();
  final box = await algo.encrypt(
    utf8.encode(plaintext),
    secretKey: SecretKey(keyBytes),
  );
  return jsonEncode({
    'format': 'studyflow-enc-v1',
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
    'iterations': kIterations,
  });
}

Future<String> decryptString(String envelope, String passphrase) async {
  final env = jsonDecode(envelope) as Map<String, dynamic>;
  final salt = base64Decode(env['salt'] as String);
  final keyBytes =
      await _derive(passphrase, salt, (env['iterations'] as int?) ?? kIterations);
  final algo = AesGcm.with256bits();
  final box = SecretBox(
    base64Decode(env['ciphertext'] as String),
    nonce: base64Decode(env['nonce'] as String),
    mac: Mac(base64Decode(env['mac'] as String)),
  );
  final clear = await algo.decrypt(box, secretKey: SecretKey(keyBytes));
  return utf8.decode(clear);
}

bool looksEncrypted(String text) {
  try {
    final j = jsonDecode(text);
    return j is Map && j['format'] == 'studyflow-enc-v1';
  } catch (_) {
    return false;
  }
}
