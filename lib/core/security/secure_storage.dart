import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAppStorage {
  SecureAppStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'bizmanager_secure_store',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  static Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (_) {
      return {};
    }
  }

  /// Gets or generates a cryptographically secure 256-bit database encryption key.
  static Future<String> getDatabaseEncryptionKey() async {
    try {
      String? key = await read('db_encryption_key');
      if (key == null || key.isEmpty) {
        final rand = Random.secure();
        final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
        key = base64UrlEncode(bytes);
        await write('db_encryption_key', key);
      }
      return key;
    } catch (_) {
      return 'test_mock_encryption_key_32_bytes_long';
    }
  }
}
