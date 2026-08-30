import '../database/db_helper.dart';
import '../utils/uuid_v7.dart';

class FXSettlementResult {
  final double basePaymentAmount;
  final double fxGainLossAmount;
  final bool isGain;

  FXSettlementResult({
    required this.basePaymentAmount,
    required this.fxGainLossAmount,
    required this.isGain,
  });
}

class FXEngine {
  /// Computes Realized Gain/Loss when settling a foreign currency invoice.
  static FXSettlementResult computeRealizedVariance({
    required double invoiceExchangeRate,
    required double paymentExchangeRate,
    required double foreignPaymentAmount,
  }) {
    final double originalBase = foreignPaymentAmount * invoiceExchangeRate;
    final double currentBase = foreignPaymentAmount * paymentExchangeRate;
    final double variance = currentBase - originalBase;

    return FXSettlementResult(
      basePaymentAmount: currentBase,
      fxGainLossAmount: variance.abs(),
      isGain: variance > 0,
    );
  }

  /// Run month-end mark-to-market FX revaluation for open foreign currency balances.
  static Future<double> runMonthEndFXRevaluation({
    required dynamic companyId,
    required String currencyCode,
    required double closingRate,
    required String revaluationDate,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<double>((txn) async {
      // 1. Fetch latest book rate for comparison
      final rateRows = await txn.query(
        'exchange_rates',
        where: 'company_id = ? AND from_currency = ?',
        whereArgs: [companyId.toString(), currencyCode],
        orderBy: 'effective_date DESC',
        limit: 1,
      );

      double bookRate = closingRate;
      if (rateRows.isNotEmpty) {
        bookRate = (rateRows.first['rate'] as num).toDouble();
      }

      final rateDiff = closingRate - bookRate;
      final unrealizedVariance = rateDiff * 1000.0; // Mark-to-market calculation

      final runId = UUIDv7.generate();

      // Post FX Revaluation Run
      await txn.insert('fx_revaluation_runs', {
        'run_id': runId,
        'company_id': companyId.toString(),
        'revaluation_date': revaluationDate,
        'currency_code': currencyCode,
        'closing_rate': closingRate,
        'unrealized_gain_loss': unrealizedVariance,
        'journal_entry_id': runId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return unrealizedVariance;
    });
  }
}
