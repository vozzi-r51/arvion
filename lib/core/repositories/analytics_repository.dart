import 'base_repository.dart';

/// Owns analytics/reporting queries that roll up business metrics.
/// Read-only — no events emitted. Data flows from operational
/// repositories (Sales, Purchases, Expenses) into here.
class AnalyticsRepository extends BaseRepository {
  AnalyticsRepository();

  /// Today's profit (Revenue - COGS - Expenses).
  Future<double> getTodaysProfit(int companyId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final salesRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE company_id = ? AND sale_date LIKE ? AND is_voided = 0",
      [companyId, '$today%'],
    );
    final revenue = (salesRows.first['total'] as num).toDouble();

    final purchaseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM purchases "
      "WHERE company_id = ? AND purchase_date LIKE ?",
      [companyId, '$today%'],
    );
    final cogs = (purchaseRows.first['total'] as num).toDouble();

    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses "
      "WHERE company_id = ? AND expense_date LIKE ?",
      [companyId, '$today%'],
    );
    final expenses = (expenseRows.first['total'] as num).toDouble();

    return revenue - cogs - expenses;
  }

  /// Period profit (start → end date, inclusive).
  Future<double> getProfitForPeriod(
    int companyId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = startDate.toIso8601String().substring(0, 10);
    final end = endDate.toIso8601String().substring(0, 10);

    final salesRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE company_id = ? AND sale_date >= ? AND sale_date <= ? AND is_voided = 0",
      [companyId, start, end],
    );
    final revenue = (salesRows.first['total'] as num).toDouble();

    final purchaseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM purchases "
      "WHERE company_id = ? AND purchase_date >= ? AND purchase_date <= ?",
      [companyId, start, end],
    );
    final cogs = (purchaseRows.first['total'] as num).toDouble();

    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses "
      "WHERE company_id = ? AND expense_date >= ? AND expense_date <= ?",
      [companyId, start, end],
    );
    final expenses = (expenseRows.first['total'] as num).toDouble();

    return revenue - cogs - expenses;
  }

  /// Sales by category (for pie charts / reports).
  Future<Map<String, double>> getSalesByCategory(
    int companyId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = 'company_id = ? AND is_voided = 0';
    List<dynamic> args = [companyId];

    if (startDate != null) {
      where += ' AND sale_date >= ?';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND sale_date <= ?';
      args.add(endDate.toIso8601String());
    }

    final rows = await db.rawQuery(
      "SELECT c.name, SUM(s.total) AS total FROM sales s "
      "JOIN categories c ON s.category_id = c.id "
      "WHERE $where "
      "GROUP BY c.id, c.name",
      args,
    );

    final result = <String, double>{};
    for (final row in rows) {
      result[row['name'] as String] = (row['total'] as num).toDouble();
    }
    return result;
  }

  /// Customer payment status (total sold vs total paid).
  Future<Map<String, dynamic>> getCustomerHealthReport(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT "
      "  COUNT(*) AS total_customers, "
      "  SUM(CASE WHEN current_balance > 0 THEN 1 ELSE 0 END) AS owing_customers, "
      "  COALESCE(SUM(current_balance), 0) AS total_receivables "
      "FROM customers "
      "WHERE company_id = ? AND deleted_at IS NULL",
      [companyId],
    );
    return {
      'total_customers': (rows.first['total_customers'] as num).toInt(),
      'owing_customers': (rows.first['owing_customers'] as num).toInt(),
      'total_receivables': (rows.first['total_receivables'] as num).toDouble(),
    };
  }

  /// Supplier payment status (total purchased vs total paid).
  Future<Map<String, dynamic>> getSupplierHealthReport(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT "
      "  COUNT(*) AS total_suppliers, "
      "  SUM(CASE WHEN current_balance > 0 THEN 1 ELSE 0 END) AS payable_suppliers, "
      "  COALESCE(SUM(current_balance), 0) AS total_payables "
      "FROM suppliers "
      "WHERE company_id = ? AND deleted_at IS NULL",
      [companyId],
    );
    return {
      'total_suppliers': (rows.first['total_suppliers'] as num).toInt(),
      'payable_suppliers': (rows.first['payable_suppliers'] as num).toInt(),
      'total_payables': (rows.first['total_payables'] as num).toDouble(),
    };
  }
}
