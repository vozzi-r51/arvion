import 'dart:isolate';

/// Background Isolate Computation Service for heavy report calculations.
/// Ensures 100% smooth UI (60/120 FPS) when processing 10,000+ products/transactions.
class ReportComputeService {
  ReportComputeService._();

  /// Computes Total Stock Valuation (Retail Value, Cost Value, Total Quantity)
  /// across thousands of products on a background Isolate thread.
  static Future<Map<String, double>> computeStockValuation(
    List<Map<String, dynamic>> products,
  ) async {
    return await Isolate.run(() => _calculateStockValuationIsolate(products));
  }

  static Map<String, double> _calculateStockValuationIsolate(
    List<Map<String, dynamic>> products,
  ) {
    double totalRetailValue = 0.0;
    double totalCostValue = 0.0;
    double totalQty = 0.0;

    for (final p in products) {
      final stock = (p['stock'] as num?)?.toDouble() ??
          (p['stock_quantity'] as num?)?.toDouble() ??
          0.0;
      final salePrice = (p['sale_price'] as num?)?.toDouble() ?? 0.0;
      final costPrice = (p['cost_price'] as num?)?.toDouble() ?? 0.0;

      if (stock > 0) {
        totalQty += stock;
        totalRetailValue += stock * salePrice;
        totalCostValue += stock * costPrice;
      }
    }

    return {
      'totalQty': totalQty,
      'totalRetailValue': totalRetailValue,
      'totalCostValue': totalCostValue,
      'potentialProfit': totalRetailValue - totalCostValue,
    };
  }

  /// Computes Trial Balance Debit/Credit Totals across journal lines on a background Isolate.
  static Future<Map<String, dynamic>> computeTrialBalance(
    List<Map<String, dynamic>> lines,
  ) async {
    return await Isolate.run(() => _calculateTrialBalanceIsolate(lines));
  }

  static Map<String, dynamic> _calculateTrialBalanceIsolate(
    List<Map<String, dynamic>> lines,
  ) {
    double totalDebit = 0.0;
    double totalCredit = 0.0;
    final Map<int, Map<String, dynamic>> accountSummary = {};

    for (final line in lines) {
      final accountId = line['account_id'] as int;
      final accountName =
          (line['account_name'] as String?) ?? 'Account #$accountId';
      final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;

      totalDebit += debit;
      totalCredit += credit;

      if (!accountSummary.containsKey(accountId)) {
        accountSummary[accountId] = {
          'account_id': accountId,
          'account_name': accountName,
          'debit': 0.0,
          'credit': 0.0,
        };
      }

      accountSummary[accountId]!['debit'] =
          (accountSummary[accountId]!['debit'] as double) + debit;
      accountSummary[accountId]!['credit'] =
          (accountSummary[accountId]!['credit'] as double) + credit;
    }

    return {
      'totalDebit': totalDebit,
      'totalCredit': totalCredit,
      'isBalanced': (totalDebit - totalCredit).abs() < 0.01,
      'summaryList': accountSummary.values.toList(),
    };
  }
}
