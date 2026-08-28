import 'package:sqflite/sqflite.dart';

/// Race-Condition Safe Promotion Usage Tracking Service.
class PromotionUsageService {
  PromotionUsageService._();

  /// Gets total usages by a specific customer for a promotion.
  static Future<int> getCustomerUsageCount({
    required DatabaseExecutor db,
    required int promotionId,
    required int customerId,
  }) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM promotion_usages WHERE promotion_id = ? AND customer_id = ?',
      [promotionId, customerId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Atomically increments current_use_count in promotions table and records entry in promotion_usages.
  /// Uses race-condition safe SQL UPDATE with WHERE condition checking max_uses_total.
  static Future<void> applyPromotionUsage({
    required DatabaseExecutor txn,
    required int companyId,
    required int promotionId,
    required int saleId,
    int? customerId,
    required double discountAmount,
  }) async {
    // Atomic SQL UPDATE preventing race conditions
    final affectedRows = await txn.rawUpdate('''
      UPDATE promotions
      SET current_use_count = current_use_count + 1
      WHERE id = ?
        AND (max_uses_total IS NULL OR current_use_count < max_uses_total)
    ''', [promotionId]);

    if (affectedRows == 0) {
      throw FormatException('Promotion #$promotionId usage limit reached or unavailable');
    }

    // Insert record into promotion_usages history table
    await txn.insert('promotion_usages', {
      'company_id': companyId,
      'promotion_id': promotionId,
      'sale_id': saleId,
      'customer_id': customerId,
      'discount_amount': discountAmount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
