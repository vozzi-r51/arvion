import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/sync/hlc.dart';
import 'package:bizmanager/core/sync/uuid_v7.dart';
import 'package:bizmanager/core/sync/crdt_merge_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('CRDT Multi-Branch Sync Subsystem Tests', () {
    late DBHelper dbHelper;

    setUp(() async {
      dbHelper = DBHelper.instance;
    });

    test('a) HLC clock and UUIDv7 generation produce monotonic and unique identifiers', () {
      final hlc1 = HLC.now('NODE-A');
      final hlc2 = HLC.now('NODE-A');

      expect(hlc2.compareTo(hlc1), greaterThanOrEqualTo(0));

      final uuid1 = UUIDv7.generate();
      final uuid2 = UUIDv7.generate();

      expect(uuid1, isNot(equals(uuid2)));
      expect(uuid1.length, 36);
      expect(uuid2.length, 36);
    });

    test('b) LWW Column-Level Merge: two offline nodes updating distinct fields merge convergently', () async {
      final companyId = await dbHelper.insertCompany({
        'name': 'CRDT Test Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });

      final db = await dbHelper.database;
      const custId = 101;
      const custIdStr = '101';

      // Seed initial customer
      await db.insert('customers', {
        'id': custId,
        'company_id': companyId,
        'name': 'Original Customer',
        'mobile': '03001112233',
        'credit_limit': 5000.0,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Node A updates name at HLC t1
      final hlcA = HLC.now('NODE-A');
      final deltaA = {
        'change_id': UUIDv7.generate(),
        'company_id': '1',
        'branch_id': 'BR-01',
        'node_id': 'NODE-A',
        'table_name': 'customers',
        'row_id': custIdStr,
        'hlc_timestamp': hlcA.toString(),
        'operation_type': 'UPDATE',
        'columns_payload': jsonEncode({'name': 'Updated Name Node A'}),
      };

      // Node B updates mobile at HLC t2
      final hlcB = HLC.now('NODE-B');
      final deltaB = {
        'change_id': UUIDv7.generate(),
        'company_id': '1',
        'branch_id': 'BR-02',
        'node_id': 'NODE-B',
        'table_name': 'customers',
        'row_id': custIdStr,
        'hlc_timestamp': hlcB.toString(),
        'operation_type': 'UPDATE',
        'columns_payload': jsonEncode({'mobile': '03998887766'}),
      };

      // Apply deltas from both nodes
      await CRDTMergeService.instance.applyRemoteDeltas([deltaA, deltaB]);

      final rows = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(rows.length, 1);
      final mergedCust = rows.first;

      // Both distinct field updates merged convergently!
      expect(mergedCust['name'], 'Updated Name Node A');
      expect(mergedCust['mobile'], '03998887766');
    });

    test('c) Concurrent sales on offline nodes produce non-colliding UUIDs and aggregate stock deltas correctly', () async {
      final warehouseId = 'WH-LAHORE-01';
      final productId = 'PROD-WIDGET-99';

      final delta1Id = UUIDv7.generate();
      final delta2Id = UUIDv7.generate();

      expect(delta1Id, isNot(equals(delta2Id)));

      final hlc1 = HLC.now('NODE-POS-101');
      final hlc2 = HLC.now('NODE-POS-201');

      // Sale 1 on POS-101 deducts 5 units
      await dbHelper.insertInventoryStockDelta({
        'delta_id': delta1Id,
        'company_id': '1',
        'warehouse_id': warehouseId,
        'product_id': productId,
        'node_id': 'NODE-POS-101',
        'hlc_timestamp': hlc1.toString(),
        'qty_delta': -5.0,
        'source_type': 'SALE',
        'source_id': UUIDv7.generate(),
      });

      // Sale 2 on POS-201 deducts 8 units
      await dbHelper.insertInventoryStockDelta({
        'delta_id': delta2Id,
        'company_id': '1',
        'warehouse_id': warehouseId,
        'product_id': productId,
        'node_id': 'NODE-POS-201',
        'hlc_timestamp': hlc2.toString(),
        'qty_delta': -8.0,
        'source_type': 'SALE',
        'source_id': UUIDv7.generate(),
      });

      // Aggregate sum of stock deltas across offline nodes
      final totalDelta = await dbHelper.getAggregateStockDelta(warehouseId, productId);
      expect(totalDelta, -13.0);
    });
  });
}
