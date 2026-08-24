import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import '../database/db_helper.dart';

/// Handles PIN setup/verification and fingerprint (biometric) authentication.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> isPinSet() => DBHelper.instance.hasPinSetup();

  /// Call once, during first-time setup, to create the app PIN.
  Future<void> setPin(String pin, {String? question, String? answer}) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
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
    final row = await DBHelper.instance.getSecurityRow();
    if (row == null) return false;
    final computed = _hashPin(pin, row['pin_salt'] as String);
    return computed == row['pin_hash'] as String;
  }

  /// Hashes a staff PIN with a fresh salt (used when creating a cashier).
  ({String hash, String salt}) hashNewPin(String pin) {
    final salt = _generateSalt();
    return (hash: _hashPin(pin, salt), salt: salt);
  }

  /// Checks a PIN against every staff PIN on this device (across all
  /// companies, since login happens before a company is chosen). Returns
  /// the matching staff row (with its company_id) or null.
  Future<Map<String, dynamic>?> verifyStaffPin(String pin) async {
    final staff = await DBHelper.instance.getAllStaffUsersAcrossCompanies();
    for (final s in staff) {
      final computed = _hashPin(pin, s['pin_salt'] as String);
      if (computed == s['pin_hash'] as String) return s;
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
        localizedReason: 'ARVION kholne ke liye apni fingerprint dikhayen',
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
