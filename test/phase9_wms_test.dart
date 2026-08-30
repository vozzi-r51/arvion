import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/wms/wms_scanner_service.dart';
import 'package:bizmanager/core/utils/uuid_v7.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 9 Advanced Warehouse Management System (WMS) Tests', () {
    late DBHelper db;
    late int companyId;
    late int warehouseId;
    late int productId;
    late String binId;
    late String binCode;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'WMS Test Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });

      warehouseId = await db.insertWarehouse({
        'company_id': companyId,
        'name': 'WMS Central Warehouse',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      productId = await db.insertProduct({
        'company_id': companyId,
        'name': 'WMS Barcode Widget',
        'barcode': '8901234567890',
        'current_stock': 100.0,
        'purchase_price': 50.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final dbConn = await db.database;
      binId = UUIDv7.generate();
      binCode = 'Z-A-04-12-${DateTime.now().microsecondsSinceEpoch % 100000}';

      await dbConn.insert('warehouse_bins', {
        'bin_id': binId,
        'warehouse_id': warehouseId.toString(),
        'zone': 'Zone A',
        'aisle': 'Aisle 04',
        'rack': 'Rack 12',
        'shelf': 'Shelf 02',
        'bin_code': binCode,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    test('a) Valid barcode and bin scan increments scanned_qty and sets is_verified when expected_qty is reached', () async {
      final dbConn = await db.database;
      final pickListId = UUIDv7.generate();
      final itemId = UUIDv7.generate();

      await dbConn.insert('pick_lists', {
        'pick_list_id': pickListId,
        'company_id': companyId.toString(),
        'sales_order_id': 'SO-9001',
        'assigned_picker_id': 'PICKER-01',
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      await dbConn.insert('pick_list_items', {
        'item_id': itemId,
        'pick_list_id': pickListId,
        'product_id': productId.toString(),
        'bin_id': binId,
        'expected_qty': 2.0,
        'scanned_qty': 0.0,
        'is_verified': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Scan 1 (1 of 2)
      final scan1Verified = await WMSScannerService.verifyPickItem(
        dbConn,
        pickListId: pickListId,
        scannedBarcode: '8901234567890',
        scannedBinCode: binCode,
      );
      expect(scan1Verified, isFalse); // Only 1 scanned out of 2 expected

      // Scan 2 (2 of 2)
      final scan2Verified = await WMSScannerService.verifyPickItem(
        dbConn,
        pickListId: pickListId,
        scannedBarcode: '8901234567890',
        scannedBinCode: binCode,
      );
      expect(scan2Verified, isTrue); // Order volume completed!

      final itemRows = await dbConn.query('pick_list_items', where: 'item_id = ?', whereArgs: [itemId]);
      expect((itemRows.first['scanned_qty'] as num).toDouble(), 2.0);
      expect(itemRows.first['is_verified'], 1);
    });

    test('b) Mismatched barcode or bin code throws WMSScanException', () async {
      final dbConn = await db.database;
      final pickListId = UUIDv7.generate();
      final itemId = UUIDv7.generate();

      await dbConn.insert('pick_lists', {
        'pick_list_id': pickListId,
        'company_id': companyId.toString(),
        'sales_order_id': 'SO-9002',
        'assigned_picker_id': 'PICKER-01',
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      await dbConn.insert('pick_list_items', {
        'item_id': itemId,
        'pick_list_id': pickListId,
        'product_id': productId.toString(),
        'bin_id': binId,
        'expected_qty': 1.0,
        'scanned_qty': 0.0,
        'is_verified': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Mismatched barcode scan
      expect(
        () async => await WMSScannerService.verifyPickItem(
          dbConn,
          pickListId: pickListId,
          scannedBarcode: 'INVALID_BARCODE',
          scannedBinCode: binCode,
        ),
        throwsA(isA<WMSScanException>()),
      );

      // Mismatched bin code scan
      expect(
        () async => await WMSScannerService.verifyPickItem(
          dbConn,
          pickListId: pickListId,
          scannedBarcode: '8901234567890',
          scannedBinCode: 'INVALID_BIN_CODE',
        ),
        throwsA(isA<WMSScanException>()),
      );
    });

    test('c) Over-picking beyond expected_qty throws WMSScanException', () async {
      final dbConn = await db.database;
      final pickListId = UUIDv7.generate();
      final itemId = UUIDv7.generate();

      await dbConn.insert('pick_lists', {
        'pick_list_id': pickListId,
        'company_id': companyId.toString(),
        'sales_order_id': 'SO-9003',
        'assigned_picker_id': 'PICKER-01',
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      await dbConn.insert('pick_list_items', {
        'item_id': itemId,
        'pick_list_id': pickListId,
        'product_id': productId.toString(),
        'bin_id': binId,
        'expected_qty': 1.0,
        'scanned_qty': 1.0, // Already fulfilled
        'is_verified': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Extra scan beyond expected_qty = 1.0
      expect(
        () async => await WMSScannerService.verifyPickItem(
          dbConn,
          pickListId: pickListId,
          scannedBarcode: '8901234567890',
          scannedBinCode: binCode,
        ),
        throwsA(isA<WMSScanException>()),
      );
    });
  });
}
