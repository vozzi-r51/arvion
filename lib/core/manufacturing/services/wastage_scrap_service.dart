import '../../database/db_helper.dart';

/// Service for Production Wastage & Scrap Tracking.
class WastageScrapService {
  WastageScrapService._();

  /// Calculates actual wastage and creates stock adjustment entry if wastage > 0.
  /// Overproduction (actual >= expected) results in 0 wastage without negative adjustments.
  static Future<double> calculateAndRecordWastage({
    required int companyId,
    required int productionOrderId,
    required int finishedProductId,
    required double expectedOutputQty,
    required double actualOutputQty,
  }) async {
    double wastageQty = 0.0;

    if (actualOutputQty < expectedOutputQty) {
      wastageQty = expectedOutputQty - actualOutputQty;
    }

    final db = await DBHelper.instance.database;

    // 1. Update production order with output and wastage quantity
    await db.update(
      'production_orders',
      {
        'actual_output_quantity': actualOutputQty,
        'actual_wastage_quantity': wastageQty,
        'status': 'completed',
        'completion_date': DateTime.now().toIso8601String().substring(0, 10),
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [productionOrderId, companyId],
    );

    // 2. Create Stock Adjustment for wastage if wastage > 0
    if (wastageQty > 0) {
      await DBHelper.instance.insertStockAdjustment({
        'company_id': companyId,
        'product_id': finishedProductId,
        'type': 'decrease',
        'quantity': wastageQty,
        'reason': 'Production Wastage (Order #$productionOrderId)',
        'adjustment_date': DateTime.now().toIso8601String().substring(0, 10),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return wastageQty;
  }
}
