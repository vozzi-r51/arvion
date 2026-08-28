import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import '../database/db_helper.dart';
import '../security/secure_storage.dart';

/// Handles PIN setup/verification and fingerprint (biometric) authentication.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _keyPinHash = 'owner_pin_hash';
  static const _keyPinSalt = 'owner_pin_salt';
  static const _pbkdf2Iterations = 20000; // Stronger than raw SHA-256

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 implementation using the 'crypto' package.
  String _hashPinV2(String pin, String salt) {
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, pinBytes);

    // Initial block (U1)
    // For a 4-6 digit PIN, one 256-bit block is more than enough entropy.
    var lastHash = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(lastHash);

    for (var i = 1; i < _pbkdf2Iterations; i++) {
      lastHash = hmac.convert(lastHash).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= lastHash[j];
      }
    }

    return 'v2:$_pbkdf2Iterations:${base64UrlEncode(result)}';
  }

  /// Old hashing scheme (raw salted SHA-256) for backward compatibility/migration.
  String _hashPinV1(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> isPinSet() async {
    final secureHash = await SecureAppStorage.read(_keyPinHash);
    if (secureHash != null) return true;
    return DBHelper.instance.hasPinSetup();
  }

  /// Call once, during first-time setup, to create the app PIN.
  Future<void> setPin(String pin, {String? question, String? answer}) async {
    final salt = _generateSalt();
    final hash = _hashPinV2(pin, salt);
    
    // 1. Store secrets in Keystore/Keychain
    await SecureAppStorage.write(_keyPinHash, hash);
    await SecureAppStorage.write(_keyPinSalt, salt);
    
    // 2. Store metadata + backup in SQLite (for redundancy/migrations)
    await DBHelper.instance.savePin(hash, salt, question: question, answer: answer);
  }

  Future<Map<String, dynamic>?> getSecurityInfo() => DBHelper.instance.getSecurityRow();

  Future<bool> verifyRecovery(String answer) async {
    final row = await DBHelper.instance.getSecurityRow();
    if (row == null || row['security_answer'] == null) return false;
    return answer.trim().toLowerCase() == (row['security_answer'] as String).trim().toLowerCase();
  }

  /// Verifies a PIN entered at login against the stored hash.
  Future<bool> verifyPin(String pin) async {
    String? storedHash = await SecureAppStorage.read(_keyPinHash);
    String? salt = await SecureAppStorage.read(_keyPinSalt);

    // Lazy migration from SQLite to SecureStorage
    if (storedHash == null || salt == null) {
      final row = await DBHelper.instance.getSecurityRow();
      if (row == null) return false;
      storedHash = row['pin_hash'] as String;
      salt = row['pin_salt'] as String;
    }

    bool isValid = false;

    if (storedHash.startsWith('v2:')) {
      // Modern PBKDF2 verify
      isValid = _hashPinV2(pin, salt) == storedHash;
    } else {
      // Old raw SHA-256 verify
      isValid = _hashPinV1(pin, salt) == storedHash;
      
      // Automatic upgrade to V2 on successful login
      if (isValid) {
        await setPin(pin); 
      }
    }

    return isValid;
  }

  /// Hashes a staff PIN with a fresh salt (used when creating a cashier).
  ({String hash, String salt}) hashNewPin(String pin) {
    final salt = _generateSalt();
    return (hash: _hashPinV2(pin, salt), salt: salt);
  }

  /// Checks a PIN against every staff PIN on this device.
  Future<Map<String, dynamic>?> verifyStaffPin(String pin) async {
    final staff = await DBHelper.instance.getAllStaffUsersAcrossCompanies();
    for (final s in staff) {
      final storedHash = s['pin_hash'] as String;
      final salt = s['pin_salt'] as String;
      
      bool isValid = false;
      if (storedHash.startsWith('v2:')) {
        isValid = _hashPinV2(pin, salt) == storedHash;
      } else {
        isValid = _hashPinV1(pin, salt) == storedHash;
        // Upgrade staff hash too if valid
        if (isValid) {
          final newPin = hashNewPin(pin);
          await DBHelper.instance.updateStaffUser(s['id'] as int, {
            'pin_hash': newPin.hash,
            'pin_salt': newPin.salt,
          });
        }
      }
      
      if (isValid) return s;
    }
    return null;
  }

  Future<bool> isBiometricEnabled() async {
    final row = await DBHelper.instance.getSecurityRow();
    if (row == null) return false;
    return (row['biometric_enabled'] as int) == 1;
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      DBHelper.instance.setBiometricEnabled(enabled);

  /// Checks if the device itself supports fingerprint/face unlock.
  Future<bool> deviceSupportsBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS fingerprint/face dialog. Returns true on success.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'BizManager kholne ke liye apni fingerprint dikhayen',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
