import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores user-supplied provider credentials in Android Keystore-backed
/// encrypted storage and removes legacy plaintext preference values.
class CredentialStorageService {
  CredentialStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  static Future<String?> read(
    String key, {
    List<String> legacyAliases = const [],
  }) async {
    final stored = await _storage.read(key: key);
    if (stored != null && stored.trim().isNotEmpty) return stored;

    final preferences = await SharedPreferences.getInstance();
    for (final legacyKey in [key, ...legacyAliases]) {
      final legacyValue = preferences.getString(legacyKey);
      if (legacyValue == null || legacyValue.trim().isEmpty) continue;
      await _storage.write(key: key, value: legacyValue.trim());
      await preferences.remove(legacyKey);
      return legacyValue.trim();
    }
    return null;
  }

  static Future<void> write(String key, String? value) async {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: normalized);
    }

    // Always remove the old plaintext copy after a successful secure write.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
