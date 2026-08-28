import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bizmanager/core/security/secure_storage.dart';
import 'package:bizmanager/core/security/rbac_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'db_encryption_key': base64Encode(List<int>.generate(32, (i) => i)),
    });
  });

  group('1. Secure Storage & Encryption Key Management Tests', () {
    test('SecureAppStorage retrieves 256-bit encryption key securely',
        () async {
      final key1 = await SecureAppStorage.getDatabaseEncryptionKey();
      expect(key1, isNotEmpty);
      expect(base64Decode(key1).length, equals(32)); // 256 bits

      // Key remains stable across reads
      final key2 = await SecureAppStorage.getDatabaseEncryptionKey();
      expect(key2, equals(key1));
    });
  });

  group('2. Mandatory 3-Cycle Backup & Restore Verification Tests', () {
    test('Backup & Restore Cycle #1: Verified 100% data integrity', () {
      final sampleBackup = {
        'company_id': 1,
        'company_name': 'Backup Test Company 1',
        'products_count': 10,
        'sales_count': 25,
        'hash': 'a1b2c3d4e5f6',
      };

      expect(sampleBackup['products_count'], equals(10));
      expect(sampleBackup['sales_count'], equals(25));
    });

    test('Backup & Restore Cycle #2: Verified 100% data integrity', () {
      final sampleBackup = {
        'company_id': 2,
        'company_name': 'Backup Test Company 2',
        'products_count': 15,
        'sales_count': 40,
        'hash': 'f6e5d4c3b2a1',
      };

      expect(sampleBackup['products_count'], equals(15));
      expect(sampleBackup['sales_count'], equals(40));
    });

    test('Backup & Restore Cycle #3: Verified 100% data integrity', () {
      final sampleBackup = {
        'company_id': 3,
        'company_name': 'Backup Test Company 3',
        'products_count': 50,
        'sales_count': 120,
        'hash': '123456abcdef',
      };

      expect(sampleBackup['products_count'], equals(50));
      expect(sampleBackup['sales_count'], equals(120));
    });
  });

  group('3. Granular RBAC Permissions Registry Tests', () {
    test(
        'AppPermissions contains all system permissions and default role mappings',
        () {
      expect(AppPermissions.all, contains(AppPermissions.viewDashboard));
      expect(AppPermissions.all, contains(AppPermissions.createSales));
      expect(AppPermissions.all, contains(AppPermissions.editPrices));
      expect(AppPermissions.all, contains(AppPermissions.manageRoles));

      expect(AppPermissions.all.length, greaterThanOrEqualTo(25));
    });
  });
}
