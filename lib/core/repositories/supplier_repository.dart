import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns supplier-related persistence: creating suppliers, fetching,
/// managing payables. Payment events trigger ledger updates.
class SupplierRepository extends BaseRepository {
  SupplierRepository();

  /// Create a supplier and emit `SupplierCreatedEvent`.
  Future<int> createSupplier(Map<String, dynamic> supplier) async {
    final id = await db.insert('suppliers', supplier);
    DomainEventBus.instance.emit(SupplierCreatedEvent(
      supplierId: id,
      companyId: supplier['company_id'] as int,
    ));
    return id;
  }

  /// List suppliers for a company with search query & pagination.
  Future<List<Map<String, dynamic>>> listSuppliers(
    int companyId, {
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    String where = 'company_id = ? AND deleted_at IS NULL';
    List<dynamic> args = [companyId];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (company_name LIKE ? OR contact_person LIKE ? OR phone LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    return await db.query(
      'suppliers',
      where: where,
      whereArgs: args,
      orderBy: 'company_name ASC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get supplier by ID.
  Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final rows = await db.query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Get supplier count for dashboard / AI.
  Future<int> getSupplierCount(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM suppliers WHERE company_id = ? AND deleted_at IS NULL",
      [companyId],
    );
    return (rows.first['c'] as num).toInt();
  }

  /// Update supplier details.
  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    await db.update('suppliers', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-delete supplier.
  Future<void> deleteSupplier(int id) async {
    await db.update(
      'suppliers',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get payables (suppliers we owe money to).
  Future<List<Map<String, dynamic>>> getPayables(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT * FROM suppliers "
      "WHERE company_id = ? AND deleted_at IS NULL AND current_balance > 0 "
      "ORDER BY current_balance DESC",
      [companyId],
    );
    return rows;
  }

  /// Record payment to supplier — emits `PaymentMadeEvent`.
  Future<void> recordPayment({
    required int supplierId,
    required int companyId,
    required double amount,
  }) async {
    await db.rawUpdate(
      "UPDATE suppliers SET current_balance = current_balance - ? WHERE id = ?",
      [amount, supplierId],
    );
    DomainEventBus.instance.emit(PaymentMadeEvent(
      supplierId: supplierId,
      companyId: companyId,
      amount: amount,
    ));
  }
}
