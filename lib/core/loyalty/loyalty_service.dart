import 'package:sqflite/sqflite.dart';

/// Customer Loyalty Points Earning & Redemption Service.
class LoyaltyService {
  LoyaltyService._();

  /// Calculates loyalty points earned for an eligible sale amount based on company rate.
  static double calculatePointsEarned({
    required double eligibleAmount,
    required double pointsPerCurrency, // e.g. 0.01 (1 point per 100)
  }) {
    if (eligibleAmount <= 0 || pointsPerCurrency <= 0) return 0.0;
    return eligibleAmount * pointsPerCurrency;
  }

  /// Converts loyalty points into currency discount amount based on redemption rate.
  static double calculateRedemptionDiscount({
    required double pointsToRedeem,
    required double redemptionRate, // e.g. 1.0 (1 point = 1 currency unit)
  }) {
    if (pointsToRedeem <= 0 || redemptionRate <= 0) return 0.0;
    return pointsToRedeem * redemptionRate;
  }

  /// Atomically updates customer loyalty points balance and records entry in loyalty_ledger.
  static Future<double> applyLoyaltyTransaction({
    required DatabaseExecutor txn,
    required int companyId,
    required int customerId,
    required int saleId,
    required double pointsEarned,
    required double pointsRedeemed,
  }) async {
    final customerRows = await txn.query(
      'customers',
      columns: ['loyalty_points'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (customerRows.isEmpty) return 0.0;

    final currentPoints = (customerRows.first['loyalty_points'] as num?)?.toDouble() ?? 0.0;

    if (pointsRedeemed > currentPoints) {
      throw FormatException('Redeemed points ($pointsRedeemed) cannot exceed available points ($currentPoints)');
    }

    final newBalance = currentPoints - pointsRedeemed + pointsEarned;

    // 1. Update customer loyalty balance
    await txn.update(
      'customers',
      {'loyalty_points': newBalance},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    // 2. Insert into loyalty_ledger
    await txn.insert('loyalty_ledger', {
      'company_id': companyId,
      'customer_id': customerId,
      'sale_id': saleId,
      'points_earned': pointsEarned,
      'points_redeemed': pointsRedeemed,
      'balance_after': newBalance,
      'created_at': DateTime.now().toIso8601String(),
    });

    return newBalance;
  }
}
