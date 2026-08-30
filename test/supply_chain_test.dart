import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/services/batch_stock_service.dart';
import 'package:bizmanager/core/services/p2p_matching_service.dart';
import 'package:bizmanager/core/repositories/warehouse_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 2 Enterprise Supply Chain & 3-Way Matching Tests', () {
    late DBHelper db;
    late int companyId;
    late int warehouseId;
    late int productId;

    setUp(() async {
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Supply Chain Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });

      warehouseId = await DBHelper.instance.insertWarehouse({
        'company_id': companyId,
        'name': 'Main Warehouse',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      productId = await db.insertProduct({
        'company_id': companyId,
        'name': 'Pharma Medicine A',
        'current_stock': 100.0,
        'purchase_price': 50.0,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) FEFO auto-selection picks the earliest expiring batch and skips expired batches', () async {
      final now = DateTime.now();
      final expiredDate = now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
      final earlyExpiryDate = now.add(const Duration(days: 30)).toIso8601String().substring(0, 10);
      final lateExpiryDate = now.add(const Duration(days: 120)).toIso8601String().substring(0, 10);

      // Batch 1: Expired (30 days ago) - 50 units
      await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'BATCH-EXPIRED',
        qty: 50.0,
        costPrice: 50.0,
        expiryDate: expiredDate,
      );

      // Batch 2: Early Expiry (30 days in future) - 20 units
      await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'BATCH-EARLY',
        qty: 20.0,
        costPrice: 50.0,
        expiryDate: earlyExpiryDate,
      );

      // Batch 3: Late Expiry (120 days in future) - 30 units
      await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseId,
        batchNumber: 'BATCH-LATE',
        qty: 30.0,
        costPrice: 50.0,
        expiryDate: lateExpiryDate,
      );

      // FEFO Select 25 units -> should pick 20 from BATCH-EARLY and 5 from BATCH-LATE (skipping BATCH-EXPIRED)
      final selected = await BatchStockService.instance.selectFEFOBatches(
        companyId: companyId,
        productId: productId,
        requestedQty: 25.0,
        warehouseId: warehouseId,
      );

      expect(selected.length, 2);
      expect(selected[0]['batch_number'], 'BATCH-EARLY');
      expect((selected[0]['allocated_qty'] as num).toDouble(), 20.0);

      expect(selected[1]['batch_number'], 'BATCH-LATE');
      expect((selected[1]['allocated_qty'] as num).toDouble(), 5.0);
    });

    test('b) Receiving a GRN updates physical stock & posts accrual journal without touching AP', () async {
      final supplierId = await db.insertSupplier({
        'company_id': companyId,
        'company_name': 'Global Pharma Supplier',
        'current_balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final poId = await P2PMatchingService.instance.createPurchaseOrder(
        companyId: companyId,
        supplierId: supplierId,
        poNumber: 'PO-2026-901',
        items: [
          {'product_id': productId, 'quantity': 100.0, 'unit_cost': 60.0},
        ],
      );

      // Receive GRN
      final grnId = await P2PMatchingService.instance.createGoodsReceivedNote(
        companyId: companyId,
        purchaseOrderId: poId,
        warehouseId: warehouseId,
        grnNumber: 'GRN-2026-901',
        items: [
          {
            'product_id': productId,
            'quantity_received': 100.0,
            'unit_cost': 60.0,
            'batch_number': 'GRN-BATCH-100',
            'expiry_date': '2027-12-31',
          }
        ],
      );

      expect(grnId, isPositive);

      // Check AP Supplier Balance is still 0 (AP not touched at GRN stage)
      final suppliers = await db.getSuppliers(companyId);
      final supplier = suppliers.firstWhere((s) => s['id'] == supplierId);
      expect((supplier['current_balance'] as num).toDouble(), 0.0);

      // Check GRN status is 'received'
      final grnRows = await (await db.database).query(
        'goods_received_notes',
        where: 'id = ?',
        whereArgs: [grnId],
      );
      expect(grnRows.first['status'], 'received');
    });

    test('c) Linking a Purchase Invoice to a GRN clears accrual balance against Accounts Payable', () async {
      final supplierId = await db.insertSupplier({
        'company_id': companyId,
        'company_name': 'Med Supply Ltd',
        'current_balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final poId = await P2PMatchingService.instance.createPurchaseOrder(
        companyId: companyId,
        supplierId: supplierId,
        poNumber: 'PO-2026-902',
        items: [
          {'product_id': productId, 'quantity': 50.0, 'unit_cost': 100.0},
        ],
      );

      final grnId = await P2PMatchingService.instance.createGoodsReceivedNote(
        companyId: companyId,
        purchaseOrderId: poId,
        warehouseId: warehouseId,
        grnNumber: 'GRN-2026-902',
        items: [
          {
            'product_id': productId,
            'quantity_received': 50.0,
            'unit_cost': 100.0,
            'batch_number': 'GRN-BATCH-200',
            'expiry_date': '2028-01-01',
          }
        ],
      );

      // Create Purchase Invoice linking GRN
      final invId = await P2PMatchingService.instance.createPurchaseInvoice(
        companyId: companyId,
        grnId: grnId,
        invoiceNumber: 'INV-2026-902',
        totalAmount: 5000.0,
        supplierId: supplierId,
      );

      expect(invId, isPositive);

      // Supplier balance / AP established
      final suppliers = await db.getSuppliers(companyId);
      final supplier = suppliers.firstWhere((s) => s['id'] == supplierId);
      expect((supplier['current_balance'] as num).toDouble(), 5000.0);

      // GRN status updated to 'invoiced'
      final grnRows = await (await db.database).query(
        'goods_received_notes',
        where: 'id = ?',
        whereArgs: [grnId],
      );
      expect(grnRows.first['status'], 'invoiced');
    });

    test('d) Two-Stage Inter-Warehouse Stock Transfer Order (STO) dispatch and receive flow', () async {
      final destWarehouseId = await db.insertWarehouse({
        'company_id': companyId,
        'name': 'Secondary Warehouse',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final repo = WarehouseRepository();

      // Dispatch 30 units
      final transferId = await repo.dispatchTransfer(
        companyId: companyId,
        productId: productId,
        sourceWarehouseId: warehouseId,
        destWarehouseId: destWarehouseId,
        quantity: 30.0,
        transferNumber: 'STO-2026-001',
      );

      expect(transferId, isPositive);

      // Verify transfer status IN_TRANSIT
      final tRows = await (await db.database).query(
        'stock_transfers',
        where: 'id = ?',
        whereArgs: [transferId],
      );
      expect(tRows.first['status'], 'IN_TRANSIT');

      // Receive transfer
      final received = await repo.receiveTransfer(
        companyId: companyId,
        transferId: transferId,
      );

      expect(received, isTrue);

      // Verify transfer status COMPLETED
      final completedRows = await (await db.database).query(
        'stock_transfers',
        where: 'id = ?',
        whereArgs: [transferId],
      );
      expect(completedRows.first['status'], 'COMPLETED');
    });
  });
}
