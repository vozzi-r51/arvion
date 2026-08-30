import '../database/db_helper.dart';

/// Service managing stock batch creation, lot tracking, and FEFO (First-Expired, First-Out) auto-selection.
class BatchStockService {
  BatchStockService._();
  static final BatchStockService instance = BatchStockService._();

  /// Create or add stock to a batch.
  Future<int> createBatch({
    required int companyId,
    required int productId,
    required int warehouseId,
    required String batchNumber,
    required double qty,
    double costPrice = 0,
    String? mfgDate,
    String? expiryDate,
  }) async {
    final db = await DBHelper.instance.database;
    final existing = await db.query(
      'stock_batches',
      where:
          'company_id = ? AND product_id = ? AND warehouse_id = ? AND batch_number = ?',
      whereArgs: [companyId, productId, warehouseId, batchNumber],
    );

    if (existing.isNotEmpty) {
      final batchId = existing.first['id'] as int;
      await db.rawUpdate(
        'UPDATE stock_batches SET current_qty = current_qty + ? WHERE id = ?',
        [qty, batchId],
      );
      return batchId;
    }

    return await DBHelper.instance.insertStockBatch({
      'company_id': companyId,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'batch_number': batchNumber,
      'mfg_date': mfgDate,
      'expiry_date': expiryDate,
      'cost_price': costPrice,
      'current_qty': qty,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Auto-select unexpired stock batches using FEFO (First-Expired, First-Out) logic.
  /// Strictly ignores batches where expiry_date < DateTime.now().
  Future<List<Map<String, dynamic>>> selectFEFOBatches({
    required int companyId,
    required int productId,
    required double requestedQty,
    int? warehouseId,
  }) async {
    final batches = await DBHelper.instance.getStockBatchesForProduct(
      companyId,
      productId,
      warehouseId: warehouseId,
    );

    final now = DateTime.now();
    final todayIso = now.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> selected = [];
    double remaining = requestedQty;

    for (final b in batches) {
      if (remaining <= 0) break;

      final expStr = b['expiry_date'] as String?;
      if (expStr != null && expStr.isNotEmpty) {
        final expDate = expStr.length >= 10 ? expStr.substring(0, 10) : expStr;
        if (expDate.compareTo(todayIso) < 0) {
          // EXPIRED BATCH! Skip in FEFO mode
          continue;
        }
      }

      final double available = (b['current_qty'] as num).toDouble();
      if (available <= 0) continue;

      final double take = available >= remaining ? remaining : available;
      selected.add({
        'batch_id': b['id'],
        'batch_number': b['batch_number'],
        'expiry_date': b['expiry_date'],
        'cost_price': b['cost_price'],
        'allocated_qty': take,
      });

      remaining -= take;
    }

    if (remaining > 0) {
      throw StateError(
          'Insufficient unexpired batch stock for product ID $productId. Short by $remaining.');
    }

    return selected;
  }

  /// Deduct quantities from allocated batches inside an active database transaction.
  Future<void> deductAllocatedBatches(
    dynamic txn,
    List<Map<String, dynamic>> allocatedBatches,
  ) async {
    for (final b in allocatedBatches) {
      final batchId = b['batch_id'];
      final double qty = (b['allocated_qty'] as num).toDouble();
      await txn.rawUpdate(
        'UPDATE stock_batches SET current_qty = current_qty - ? WHERE id = ?',
        [qty, batchId],
      );
    }
  }
}
