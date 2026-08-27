import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns expense-related persistence: recording expenses, fetching,
/// summarizing by category. Emits events for accounting & analytics.
class ExpenseRepository extends BaseRepository {
  ExpenseRepository();

  /// Record an expense and emit `ExpenseRecordedEvent`.
  Future<int> recordExpense(Map<String, dynamic> expense) async {
    final id = await db.insert('expenses', expense);
    DomainEventBus.instance.emit(ExpenseRecordedEvent(
      expenseId: id,
      companyId: expense['company_id'] as int,
      amount: (expense['amount'] as num).toDouble(),
      category: expense['category'] as String? ?? 'Operating Expenses',
    ));
    return id;
  }

  /// List expenses for a company (paginated).
  Future<List<Map<String, dynamic>>> listExpenses(
    int companyId, {
    int? limit,
    int? offset,
    String? category,
  }) async {
    String where = 'company_id = ?';
    List<dynamic> args = [companyId];

    if (category != null && category.isNotEmpty) {
      where += ' AND category = ?';
      args.add(category);
    }

    return await db.query(
      'expenses',
      where: where,
      whereArgs: args,
      orderBy: 'expense_date DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Today's total expenses for dashboards / AI.
  Future<double> getTodaysExpensesTotal(int companyId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses "
      "WHERE company_id = ? AND expense_date LIKE ?",
      [companyId, '$today%'],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Get expenses grouped by category (for reports).
  Future<Map<String, double>> getExpensesByCategory(
    int companyId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = 'company_id = ?';
    List<dynamic> args = [companyId];

    if (startDate != null) {
      where += ' AND expense_date >= ?';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND expense_date <= ?';
      args.add(endDate.toIso8601String());
    }

    final rows = await db.rawQuery(
      "SELECT category, SUM(amount) AS total FROM expenses "
      "WHERE $where "
      "GROUP BY category",
      args,
    );

    final result = <String, double>{};
    for (final row in rows) {
      result[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return result;
  }

  /// Delete an expense (soft-delete).
  Future<void> deleteExpense(int id) async {
    await db.update(
      'expenses',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
