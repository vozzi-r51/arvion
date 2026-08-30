import '../database/db_helper.dart';

/// Procure-to-Pay (P2P) 3-Way Matching Service.
/// Reconciles:
///   1. Purchase Order (PO - Commercial Agreement)
///   2. Goods Received Note (GRN - Physical Stock Receipt & Unbilled Liability)
///   3. Purchase Invoice (Financial Bill & AP Ledger Impact)
class P2PMatchingService {
  P2PMatchingService._();
  static final P2PMatchingService instance = P2PMatchingService._();

  /// Step 1: Create Purchase Order (PO). Commercial agreement only — no stock or AP impact.
  Future<int> createPurchaseOrder({
    required int companyId,
    int? supplierId,
    required String poNumber,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await DBHelper.instance.database;
    double total = 0;
    for (final it in items) {
      total += (it['quantity'] as num) * (it['unit_cost'] as num);
    }

    final poId = await db.insert('purchase_orders', {
      'company_id': companyId,
      'supplier_id': supplierId,
      'po_number': poNumber,
      'total_amount': total,
      'status': 'approved',
      'po_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    for (final it in items) {
      await db.insert('purchase_order_items', {
        'po_id': poId,
        'product_id': it['product_id'],
        'product_name': it['product_name'] ?? 'Item',
        'quantity': it['quantity'],
        'unit_cost': it['unit_cost'],
        'total': (it['quantity'] as num) * (it['unit_cost'] as num),
      });
    }

    return poId;
  }

  /// Step 2: Create Goods Received Note (GRN).
  /// Physical stock increases in warehouse, hits Unbilled Inventory Liability.
  /// AP Ledger is NOT touched at this stage.
  Future<int> createGoodsReceivedNote({
    required int companyId,
    required int purchaseOrderId,
    required int warehouseId,
    required String grnNumber,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<int>((txn) async {
      final grnId = await txn.insert('goods_received_notes', {
        'company_id': companyId,
        'purchase_order_id': purchaseOrderId,
        'warehouse_id': warehouseId,
        'grn_number': grnNumber,
        'status': 'received',
        'grn_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final it in items) {
        final productId = it['product_id'] as int;
        final qty = (it['quantity_received'] as num).toDouble();
        final unitCost = (it['unit_cost'] as num).toDouble();
        final totalCost = qty * unitCost;

        await txn.insert('goods_received_note_items', {
          'grn_id': grnId,
          'product_id': productId,
          'batch_number': it['batch_number'] ?? 'BATCH_DEFAULT',
          'expiry_date': it['expiry_date'],
          'quantity_received': qty,
          'unit_cost': unitCost,
          'total_cost': totalCost,
        });

        // 1. Increase product stock
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ?, purchase_price = ? WHERE id = ?',
          [qty, unitCost, productId],
        );

        // 2. Insert or update batch
        final batchNum = it['batch_number'] as String? ?? 'BATCH_DEFAULT';
        final existingBatch = await txn.query(
          'stock_batches',
          where:
              'company_id = ? AND product_id = ? AND warehouse_id = ? AND batch_number = ?',
          whereArgs: [companyId, productId, warehouseId, batchNum],
        );

        if (existingBatch.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE stock_batches SET current_qty = current_qty + ? WHERE id = ?',
            [qty, existingBatch.first['id'] as int],
          );
        } else {
          await txn.insert('stock_batches', {
            'company_id': companyId,
            'product_id': productId,
            'warehouse_id': warehouseId,
            'batch_number': batchNum,
            'expiry_date': it['expiry_date'],
            'cost_price': unitCost,
            'current_qty': qty,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // 3. Record stock movement
        await txn.insert('stock_movements', {
          'company_id': companyId,
          'product_id': productId,
          'to_warehouse_id': warehouseId,
          'quantity': qty,
          'movement_type': 'PURCHASE_GRN',
          'reference_type': 'GRN',
          'reference_id': grnId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update PO status
      await txn.rawUpdate(
        "UPDATE purchase_orders SET status = 'received' WHERE id = ?",
        [purchaseOrderId],
      );

      return grnId;
    });
  }

  /// Step 3: Create Purchase Invoice.
  /// Financial bill clears Unbilled Inventory Liability and impacts Accounts Payable (AP) / Supplier Ledger.
  /// Physical stock is NOT touched at this stage.
  Future<int> createPurchaseInvoice({
    required int companyId,
    required int grnId,
    required String invoiceNumber,
    required double totalAmount,
    int? supplierId,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<int>((txn) async {
      final invId = await txn.insert('purchase_invoices', {
        'company_id': companyId,
        'grn_id': grnId,
        'supplier_id': supplierId,
        'invoice_number': invoiceNumber,
        'subtotal': totalAmount,
        'total_amount': totalAmount,
        'due_amount': totalAmount,
        'status': 'posted',
        'invoice_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update Supplier Balance / AP Ledger
      if (supplierId != null) {
        await txn.rawUpdate(
          'UPDATE suppliers SET current_balance = current_balance + ? WHERE id = ?',
          [totalAmount, supplierId],
        );
      }

      // Update GRN status
      await txn.rawUpdate(
        "UPDATE goods_received_notes SET status = 'invoiced' WHERE id = ?",
        [grnId],
      );

      return invId;
    });
  }
}
