import 'dart:isolate';

class BatchWorker {
  /// Offloads heavy weighted average cost recalculations across inventory to a background Isolate.
  static Future<Map<String, double>> reevaluateWeightedAverageCosts(
    List<Map<String, dynamic>> inventoryRows,
  ) async {
    return await Isolate.run(() {
      final Map<String, double> newCosts = {};
      for (final row in inventoryRows) {
        final id = (row['id'] ?? row['product_id']).toString();
        final double stock = (row['current_stock'] as num? ?? 0.0).toDouble();
        final double price = (row['purchase_price'] as num? ?? 0.0).toDouble();
        final double lastUnitCost = (row['last_unit_cost'] as num? ?? price).toDouble();
        final double lastQty = (row['last_qty'] as num? ?? 0.0).toDouble();

        if (stock + lastQty > 0) {
          final newAvgCost =
              ((stock * price) + (lastQty * lastUnitCost)) / (stock + lastQty);
          newCosts[id] = newAvgCost;
        } else {
          newCosts[id] = price;
        }
      }
      return newCosts;
    });
  }

  /// Offloads heavy trial balance aggregation across multi-year journal lines to a background Isolate.
  static Future<Map<int, Map<String, double>>> aggregateTrialBalance(
    List<Map<String, dynamic>> journalLines,
  ) async {
    return await Isolate.run(() {
      final Map<int, Map<String, double>> balances = {};

      for (final line in journalLines) {
        final int accId = (line['account_id'] as num).toInt();
        final double debit = (line['debit'] as num? ?? 0.0).toDouble();
        final double credit = (line['credit'] as num? ?? 0.0).toDouble();

        if (!balances.containsKey(accId)) {
          balances[accId] = {'debit': 0.0, 'credit': 0.0};
        }

        balances[accId]!['debit'] = balances[accId]!['debit']! + debit;
        balances[accId]!['credit'] = balances[accId]!['credit']! + credit;
      }

      return balances;
    });
  }
}
