import 'base_repository.dart';

/// Repository for Expense & Category Monthly Budgeting.
class BudgetRepository extends BaseRepository {
  BudgetRepository();

  /// Sets or updates a monthly budget for a category/account.
  Future<void> setBudget({
    required int companyId,
    required String periodMonth, // "2026-08"
    required String category,
    required double budgetedAmount,
  }) async {
    await db.rawInsert('''
      INSERT INTO budgets (company_id, period_month, category_or_account, budgeted_amount, created_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(company_id, period_month, category_or_account) DO UPDATE SET
        budgeted_amount = excluded.budgeted_amount
    ''', [
      companyId,
      periodMonth,
      category,
      budgetedAmount,
      DateTime.now().toIso8601String()
    ]);
  }

  /// Gets all budgets for a given month.
  Future<List<Map<String, dynamic>>> getBudgets(
      int companyId, String periodMonth) async {
    return await db.query(
      'budgets',
      where: 'company_id = ? AND period_month = ?',
      whereArgs: [companyId, periodMonth],
    );
  }

  /// Calculates Budget vs Actual comparison for a given month.
  /// Combines `budgets` table with actual sum from `expenses` table.
  Future<List<Map<String, dynamic>>> getBudgetVsActual(
      int companyId, String periodMonth) async {
    final budgets = await getBudgets(companyId, periodMonth);
    final budgetMap = <String, double>{};
    for (final b in budgets) {
      budgetMap[b['category_or_account'] as String] =
          (b['budgeted_amount'] as num).toDouble();
    }

    // Query actual expenses for this month
    final actualRows = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) AS total_actual
      FROM expenses
      WHERE company_id = ? AND expense_date LIKE ?
      GROUP BY category
    ''', [companyId, '$periodMonth%']);

    final actualMap = <String, double>{};
    for (final r in actualRows) {
      actualMap[r['category'] as String] =
          (r['total_actual'] as num).toDouble();
    }

    final allCategories = {...budgetMap.keys, ...actualMap.keys}.toList()
      ..sort();

    return allCategories.map((cat) {
      final budget = budgetMap[cat] ?? 0.0;
      final actual = actualMap[cat] ?? 0.0;
      final variance = actual - budget;
      final percentUsed =
          budget > 0 ? (actual / budget) * 100.0 : (actual > 0 ? 100.0 : 0.0);

      return {
        'category': cat,
        'budgeted': budget,
        'actual': actual,
        'variance':
            variance, // Positive = over budget (unfavorable for expense)
        'percentUsed': percentUsed,
        'isOverBudget': budget > 0 && actual > budget,
      };
    }).toList();
  }
}
