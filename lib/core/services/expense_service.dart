import '../repositories/expense_repository.dart';

/// High-level service coordinating Expense operations.
class ExpenseService {
  final ExpenseRepository _expenseRepo;

  ExpenseService({required ExpenseRepository expenseRepository})
      : _expenseRepo = expenseRepository;

  Future<int> recordExpense(Map<String, dynamic> expense) async {
    return await _expenseRepo.recordExpense(expense);
  }

  Future<List<Map<String, dynamic>>> listExpenses(
    int companyId, {
    int? limit,
    int? offset,
    String? category,
  }) async {
    return await _expenseRepo.listExpenses(
      companyId,
      limit: limit,
      offset: offset,
      category: category,
    );
  }

  Future<double> getTodaysExpensesTotal(int companyId) async {
    return await _expenseRepo.getTodaysExpensesTotal(companyId);
  }

  Future<Map<String, double>> getExpensesByCategory(
    int companyId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _expenseRepo.getExpensesByCategory(
      companyId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> deleteExpense(int id) async {
    await _expenseRepo.deleteExpense(id);
  }
}
