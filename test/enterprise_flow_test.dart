import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/repositories/warehouse_repository.dart';
import 'package:bizmanager/core/services/batch_stock_service.dart';
import 'package:bizmanager/core/services/p2p_matching_service.dart';
import 'package:bizmanager/core/security/permission_guard.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Enterprise Core Architecture Tests', () {
    late DBHelper dbHelper;
    late WarehouseRepository warehouseRepo;
    late int companyId;
    late int warehouseAId;
    late int warehouseBId;
    late int productId;

    setUp(() async {
      dbHelper = DBHelper.instance;
      warehouseRepo = WarehouseRepository();

      // Create test company
      companyId = await dbHelper.insertCompany({
        'name': 'ARVION Holding Co ${DateTime.now().millisecondsSinceEpoch}',
        'owner_name': 'Enterprise Owner',
        'business_type': 'general_retail',
        'business_category': 'General Retail',
        'template_family': 'retailStandard',
        'currency_symbol': 'Rs.',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create 2 warehouses
      warehouseAId = await warehouseRepo.createWarehouse(
        companyId: companyId,
        name: 'Main Warehouse Lahore',
        location: 'Lahore Branch',
      );

      warehouseBId = await warehouseRepo.createWarehouse(
        companyId: companyId,
        name: 'Central Warehouse Karachi',
        location: 'Karachi Branch',
      );

      // Create product
      productId = await dbHelper.insertProduct({
        'company_id': companyId,
        'name': 'Enterprise Widget X',
        'product_code': 'WIDGET-X',
        'purchase_price': 1000.0,
        'retail_price': 1500.0,
        'current_stock': 100.0,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Inter-warehouse stock transfers keep total balance intact while updating location counts', () async {
      // Create batch in Warehouse A with 100 units
      final batchId = await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseAId,
        batchNumber: 'BATCH-LACORE-01',
        qty: 100.0,
        costPrice: 1000.0,
      );

      final initialBatchesA = await dbHelper.getStockBatchesForProduct(
          companyId, productId, warehouseId: warehouseAId);
      final initialBatchesB = await dbHelper.getStockBatchesForProduct(
          companyId, productId, warehouseId: warehouseBId);

      expect(initialBatchesA.first['current_qty'], 100.0);
      expect(initialBatchesB, isEmpty);

      // Transfer 30 units from Warehouse A to Warehouse B
      final transferred = await warehouseRepo.transferStock(
        companyId: companyId,
        productId: productId,
        fromWarehouseId: warehouseAId,
        toWarehouseId: warehouseBId,
        quantity: 30.0,
        batchId: batchId,
      );

      expect(transferred, isTrue);

      final afterBatchesA = await dbHelper.getStockBatchesForProduct(
          companyId, productId, warehouseId: warehouseAId);
      final afterBatchesB = await dbHelper.getStockBatchesForProduct(
          companyId, productId, warehouseId: warehouseBId);

      final double qtyA = (afterBatchesA.first['current_qty'] as num).toDouble();
      final double qtyB = (afterBatchesB.first['current_qty'] as num).toDouble();

      expect(qtyA, 70.0);
      expect(qtyB, 30.0);
      // Invariant: Total stock remains 100.0
      expect(qtyA + qtyB, 100.0);
    });

    test('b) Batch expiry prevents expired items from being selected in FEFO sales mode', () async {
      final pastDate = DateTime.now()
          .subtract(const Duration(days: 10))
          .toIso8601String()
          .substring(0, 10);
      final futureDate = DateTime.now()
          .add(const Duration(days: 90))
          .toIso8601String()
          .substring(0, 10);

      // Create an expired batch (50 units) and an unexpired batch (50 units)
      await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseAId,
        batchNumber: 'BATCH-EXPIRED',
        qty: 50.0,
        expiryDate: pastDate,
      );

      await BatchStockService.instance.createBatch(
        companyId: companyId,
        productId: productId,
        warehouseId: warehouseAId,
        batchNumber: 'BATCH-FRESH',
        qty: 50.0,
        expiryDate: futureDate,
      );

      // Request 30 units in FEFO mode
      final selected = await BatchStockService.instance.selectFEFOBatches(
        companyId: companyId,
        productId: productId,
        requestedQty: 30.0,
        warehouseId: warehouseAId,
      );

      expect(selected.length, 1);
      expect(selected.first['batch_number'], 'BATCH-FRESH');
      expect(selected.first['allocated_qty'], 30.0);

      // Requesting 60 units should fail because expired batch is strictly ignored
      expect(
        () async => await BatchStockService.instance.selectFEFOBatches(
          companyId: companyId,
          productId: productId,
          requestedQty: 60.0,
          warehouseId: warehouseAId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('c) 3-way match reconciles inventory valuation with accounting entries', () async {
      // 1. Create Purchase Order (PO)
      final poId = await P2PMatchingService.instance.createPurchaseOrder(
        companyId: companyId,
        poNumber: 'PO-2026-001',
        items: [
          {
            'product_id': productId,
            'product_name': 'Enterprise Widget X',
            'quantity': 50.0,
            'unit_cost': 1000.0,
          }
        ],
      );

      expect(poId, isPositive);

      // 2. Create Goods Received Note (GRN) -> Physical stock received
      final db = await dbHelper.database;
      final productBeforeGrn = await db.query('products',
          columns: ['current_stock'], where: 'id = ?', whereArgs: [productId]);
      final double stockBefore =
          (productBeforeGrn.first['current_stock'] as num).toDouble();

      final grnId = await P2PMatchingService.instance.createGoodsReceivedNote(
        companyId: companyId,
        purchaseOrderId: poId,
        warehouseId: warehouseAId,
        grnNumber: 'GRN-2026-001',
        items: [
          {
            'product_id': productId,
            'batch_number': 'BATCH-P2P-001',
            'quantity_received': 50.0,
            'unit_cost': 1000.0,
          }
        ],
      );

      expect(grnId, isPositive);

      final productAfterGrn = await db.query('products',
          columns: ['current_stock'], where: 'id = ?', whereArgs: [productId]);
      final double stockAfter =
          (productAfterGrn.first['current_stock'] as num).toDouble();

      // Physical stock increased by 50
      expect(stockAfter, stockBefore + 50.0);

      // 3. Create Purchase Invoice -> AP Ledger & Bill reconciliation
      final invId = await P2PMatchingService.instance.createPurchaseInvoice(
        companyId: companyId,
        grnId: grnId,
        invoiceNumber: 'INV-SUPP-2026-001',
        totalAmount: 50000.0,
      );

      expect(invId, isPositive);

      final grnRows = await db.query('goods_received_notes',
          where: 'id = ?', whereArgs: [grnId]);
      expect(grnRows.first['status'], 'invoiced');
    });

    test('d) PermissionGuard enforces granular RBAC checks and throws PermissionDeniedException', () async {
      expect(
        () async => await PermissionGuard.checkPermission(
          companyId: companyId,
          permissionKey: PermissionGuard.p2pGrnCreate,
          userRole: 'Cashier',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Owner role bypasses permission checks
      await PermissionGuard.checkPermission(
        companyId: companyId,
        permissionKey: PermissionGuard.p2pGrnCreate,
        userRole: 'Owner',
      );
    });
  });
}
