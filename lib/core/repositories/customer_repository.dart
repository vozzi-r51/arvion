import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns customer-related persistence: creating customers, fetching,
/// managing receivables/payables. Payment events trigger ledger updates.
class CustomerRepository extends BaseRepository {
  CustomerRepository();

  /// Create a customer and emit `CustomerCreatedEvent`.
  Future<int> createCustomer(Map<String, dynamic> customer) async {
    final id = await db.insert('customers', customer);
    DomainEventBus.instance.emit(CustomerCreatedEvent(
      customerId: id,
      companyId: customer['company_id'] as int,
    ));
    return id;
  }

  /// List customers for a company with search query & pagination.
  Future<List<Map<String, dynamic>>> listCustomers(
    int companyId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    String where = 'company_id = ? AND deleted_at IS NULL';
    List<dynamic> args = [companyId];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR mobile LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q]);
    }

    return await db.query(
      'customers',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get customer by ID.
  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Get customer count for dashboard.
  Future<int> getCustomerCount(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM customers WHERE company_id = ? AND deleted_at IS NULL",
      [companyId],
    );
    return (rows.first['c'] as num).toInt();
  }

  /// Update customer details.
  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await db.update('customers', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-delete customer.
  Future<void> deleteCustomer(int id) async {
    await db.update(
      'customers',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get receivables (customers who owe money).
  Future<List<Map<String, dynamic>>> getReceivables(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT * FROM customers "
      "WHERE company_id = ? AND deleted_at IS NULL AND current_balance > 0 "
      "ORDER BY current_balance DESC",
      [companyId],
    );
    return rows;
  }

  /// Record payment from customer — emits `PaymentReceivedEvent`.
  Future<void> recordPayment({
    required int customerId,
    required int companyId,
    required double amount,
  }) async {
    await db.rawUpdate(
      "UPDATE customers SET current_balance = current_balance - ? WHERE id = ?",
      [amount, customerId],
    );
    DomainEventBus.instance.emit(PaymentReceivedEvent(
      customerId: customerId,
      companyId: companyId,
      amount: amount,
    ));
  }
}
