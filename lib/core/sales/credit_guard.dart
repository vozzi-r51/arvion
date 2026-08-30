import 'package:sqflite/sqflite.dart';

class CreditLimitExceededException implements Exception {
  final String message;
  final double currentBalance;
  final double limit;

  CreditLimitExceededException(this.message, this.currentBalance, this.limit);

  @override
  String toString() => 'CreditLimitExceededException: $message';
}

class CreditGuard {
  /// Validates whether a sale is allowed for a customer based on administrative hold & credit limits.
  static Future<void> validateSaleAllowed(
    DatabaseExecutor db, {
    required dynamic companyId,
    required dynamic customerId,
    required double newOrderAmount,
  }) async {
    final customerRows = await db.query(
      'customers',
      columns: ['credit_limit', 'credit_hold', 'current_balance', 'max_overdue_days'],
      where: '(id = ? OR id = ?) AND company_id = ?',
      whereArgs: [customerId, int.tryParse(customerId.toString()) ?? 0, companyId],
      limit: 1,
    );

    if (customerRows.isEmpty) return;
    final cust = customerRows.first;

    // 1. Administrative Hold Check
    if ((cust['credit_hold'] as int? ?? 0) == 1) {
      throw CreditLimitExceededException(
        'Customer account is on administrative hold.',
        (cust['current_balance'] as num? ?? 0.0).toDouble(),
        (cust['credit_limit'] as num? ?? 0.0).toDouble(),
      );
    }

    final double creditLimit = (cust['credit_limit'] as num? ?? 0.0).toDouble();
    if (creditLimit <= 0) return; // 0 = Unlimited or no active threshold

    final double currentDebt = (cust['current_balance'] as num? ?? 0.0).toDouble();

    if ((currentDebt + newOrderAmount) > creditLimit) {
      throw CreditLimitExceededException(
        'Credit limit exceeded. Limit: $creditLimit, Current: $currentDebt, New Order: $newOrderAmount',
        currentDebt,
        creditLimit,
      );
    }
  }
}
