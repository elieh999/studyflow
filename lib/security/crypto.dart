import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

// Real, standard cryptography for a local app.
//
// Passwords are hashed with Argon2id (a memory hard function, current best
// practice) and only the derived hash is stored, never the password. Accounts
// created under the older PBKDF2 scheme still verify, and get transparently
// upgraded to Argon2id the next time the user signs in successfully.
//
// Backups are sealed with AES-256-GCM using a key stretched from a passphrase
// with PBKDF2-HMAC-SHA256. This protects credentials and exported files. It is
// not a substitute for a server: the live local database is still readable by
// anyone with file access.

const int kPbkdf2Iterations = 150000;

// Argon2id parameters (OWASP baseline: 19 MiB, 2 passes, single lane). Kept
// modest because on the web build this runs as pure Dart compiled to JS.
const int kArgonMemory = 19456; // KiB
const int kArgonIterations = 2;
const int kArgonParallelism = 1;

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

Future<List<int>> _derivePbkdf2(
    String password, List<int> salt, int iterations,
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

Future<List<int>> _deriveArgon2({
  required String password,
  required List<int> salt,
  required int memory,
  required int iterations,
  required int parallelism,
  int bytes = 32,
}) async {
  final algo = Argon2id(
    memory: memory,
    iterations: iterations,
    parallelism: parallelism,
    hashLength: bytes,
  );
  final key = await algo.deriveKey(
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

// Stored representation of a hashed password. [algo] is 'argon2id' or the
// legacy 'pbkdf2'; [params] carries the cost parameters for that algorithm.
class PasswordHash {
  const PasswordHash({
    required this.algo,
    required this.salt,
    required this.hash,
    required this.params,
  });

  final String algo;
  final String salt; // base64
  final String hash; // base64
  final Map<String, int> params;

  Map<String, dynamic> toJson() =>
      {'algo': algo, 'salt': salt, 'hash': hash, 'params': params};

  factory PasswordHash.fromJson(Map<String, dynamic> j) {
    // Legacy records had no 'algo' and stored iterations at the top level.
    if (j['algo'] == null) {
      return PasswordHash(
        algo: 'pbkdf2',
        salt: j['salt'] as String,
        hash: j['hash'] as String,
        params: {'iterations': (j['iterations'] as int?) ?? kPbkdf2Iterations},
      );
    }
    final rawParams = (j['params'] as Map?) ?? const {};
    return PasswordHash(
      algo: j['algo'] as String,
      salt: j['salt'] as String,
      hash: j['hash'] as String,
      params: rawParams.map((k, v) => MapEntry(k as String, v as int)),
    );
  }
}

Future<PasswordHash> hashPassword(String password) async {
  final salt = _randomBytes(16);
  final derived = await _deriveArgon2(
    password: password,
    salt: salt,
    memory: kArgonMemory,
    iterations: kArgonIterations,
    parallelism: kArgonParallelism,
  );
  return PasswordHash(
    algo: 'argon2id',
    salt: base64Encode(salt),
    hash: base64Encode(derived),
    params: {
      'memory': kArgonMemory,
      'iterations': kArgonIterations,
      'parallelism': kArgonParallelism,
    },
  );
}

Future<bool> verifyPassword(String password, PasswordHash stored) async {
  final salt = base64Decode(stored.salt);
  List<int> derived;
  if (stored.algo == 'argon2id') {
    derived = await _deriveArgon2(
      password: password,
      salt: salt,
      memory: stored.params['memory'] ?? kArgonMemory,
      iterations: stored.params['iterations'] ?? kArgonIterations,
      parallelism: stored.params['parallelism'] ?? kArgonParallelism,
    );
  } else {
    derived = await _derivePbkdf2(
        password, salt, stored.params['iterations'] ?? kPbkdf2Iterations);
  }
  return _constantTimeEquals(derived, base64Decode(stored.hash));
}

// True when a stored hash uses an older scheme and should be upgraded after a
// successful login.
bool needsRehash(PasswordHash stored) => stored.algo != 'argon2id';

// Seal a string with AES-256-GCM; the result is a self-describing JSON envelope
// that carries the salt/nonce/mac needed to open it again with the passphrase.
Future<String> encryptString(String plaintext, String passphrase) async {
  final salt = _randomBytes(16);
  final keyBytes = await _derivePbkdf2(passphrase, salt, kPbkdf2Iterations);
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
    'iterations': kPbkdf2Iterations,
  });
}

Future<String> decryptString(String envelope, String passphrase) async {
  final env = jsonDecode(envelope) as Map<String, dynamic>;
  final salt = base64Decode(env['salt'] as String);
  final keyBytes = await _derivePbkdf2(
      passphrase, salt, (env['iterations'] as int?) ?? kPbkdf2Iterations);
  final algo = AesGcm.with256bits();
  final box = SecretBox(
    base64Decode(env['ciphertext'] as String),
    nonce: base64Decode(env['nonce'] as String),
    mac: Mac(base64Decode(env['mac'] as String)),
  );
  final clear = await algo.decrypt(box, secretKey: SecretKey(keyBytes));
  return utf8.decode(clear);
}

// Test only: build a legacy PBKDF2 password hash so the Argon2id migration
// path can be exercised. Not used by the app itself.
Future<PasswordHash> pbkdf2HashForTesting(String password) async {
  final salt = _randomBytes(16);
  final derived = await _derivePbkdf2(password, salt, kPbkdf2Iterations);
  return PasswordHash(
    algo: 'pbkdf2',
    salt: base64Encode(salt),
    hash: base64Encode(derived),
    params: {'iterations': kPbkdf2Iterations},
  );
}

bool looksEncrypted(String text) {
  try {
    final j = jsonDecode(text);
    return j is Map && j['format'] == 'studyflow-enc-v1';
  } catch (_) {
    return false;
  }
}
