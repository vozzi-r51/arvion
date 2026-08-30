import 'package:sqflite/sqflite.dart';

class FiscalPeriodLockedException implements Exception {
  final String message;
  final String transactionDate;
  final String periodName;

  FiscalPeriodLockedException({
    required this.message,
    required this.transactionDate,
    required this.periodName,
  });

  @override
  String toString() =>
      'FiscalPeriodLockedException: $message ($periodName @ $transactionDate)';
}

class FiscalPeriodGuard {
  /// Validates whether a transaction date falls into an active locked fiscal period.
  static Future<void> assertDateNotLocked(
    DatabaseExecutor db, {
    required dynamic companyId,
    required String transactionDate,
  }) async {
    // Extract date component (YYYY-MM-DD)
    final dateOnly = transactionDate.split('T').first;
    final companyIdStr = companyId.toString();

    final lockedPeriods = await db.query(
      'fiscal_periods',
      columns: ['period_name', 'start_date', 'end_date'],
      where:
          'company_id = ? AND is_locked = 1 AND ? BETWEEN start_date AND end_date',
      whereArgs: [companyIdStr, dateOnly],
      limit: 1,
    );

    if (lockedPeriods.isNotEmpty) {
      final period = lockedPeriods.first;
      throw FiscalPeriodLockedException(
        message:
            'Cannot post, modify, or reverse records in a locked fiscal period.',
        transactionDate: dateOnly,
        periodName: period['period_name'] as String,
      );
    }
  }
}
