import 'package:shared_preferences/shared_preferences.dart';

import '../security/crypto.dart';

// Persists the whole database as one AES-256-GCM encrypted snapshot, unlocked
// by a key derived from the user's login password. Nothing here is readable
// without that key, and the key is never stored.
class Vault {
  Vault(this._prefs, String username, this.key)
      : _storeKey =
            'vault_${username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  final SharedPreferences _prefs;
  final String _storeKey;
  final List<int> key;

  bool get exists => _prefs.getString(_storeKey) != null;

  // Returns the decrypted snapshot JSON, or null if there's nothing stored.
  // Throws if the stored blob can't be decrypted with this key.
  Future<String?> loadJson() async {
    final blob = _prefs.getString(_storeKey);
    if (blob == null) return null;
    return decryptWithKey(blob, key);
  }

  Future<void> saveJson(String json) async {
    final blob = await encryptWithKey(json, key);
    await _prefs.setString(_storeKey, blob);
  }
}
