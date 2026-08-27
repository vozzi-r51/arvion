import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns all sales-related persistence: creating sales, fetching them,
/// voiding/deleting. Side-effects (accounting posts, notifications, audit)
/// happen via event listeners, not direct calls.
class SalesRepository extends BaseRepository {
  SalesRepository();

  /// Create a sale with its items + cost center tagging + emit `SaleCompletedEvent`.
  /// Returns the new sale id.
  Future<int> createSale({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    int? costCenterId, // Branch, department, store, warehouse
  }) async {
    // Add cost center to sale if provided
    if (costCenterId != null) {
      sale['cost_center_id'] = costCenterId;
    }

    // Delegate the actual SQL to the existing battle-tested method on DBHelper.
    // The event is fired AFTER the transaction commits so listeners never
    // see a half-written sale.
    final saleId = await db.transaction((txn) async {
      final id = await txn.insert('sales', sale);
      for (final item in items) {
        item['sale_id'] = id;
        if (costCenterId != null) {
          item['cost_center_id'] = costCenterId; // Cascade to items
        }
        await txn.insert('sale_items', item);
      }
      return id;
    });

    DomainEventBus.instance.emit(SaleCompletedEvent(
      saleId: saleId,
      companyId: sale['company_id'] as int,
      total: (sale['total'] as num).toDouble(),
      customerId: sale['customer_id'] as int?,
    ));
    return saleId;
  }

  /// Fetch sales for a specific cost center (branch, department, etc.).
  Future<List<Map<String, dynamic>>> listSalesByCostCenter(
    int companyId,
    int costCenterId, {
    int? limit,
    int? offset,
  }) async {
    return await db.query(
      'sales',
      where: 'company_id = ? AND cost_center_id = ?',
      whereArgs: [companyId, costCenterId],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Fetch sales list (paginated). This is read-only so it does not emit events.
  Future<List<Map<String, dynamic>>> listSales(
    int companyId, {
    int? limit,
    int? offset,
  }) async {
    return await db.query(
      'sales',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Fetch items for a sale.
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    return await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  /// Void a sale and emit `SaleVoidedEvent`. Stock reversal, accounting
  /// reversal, etc. happen in listeners.
  Future<void> voidSale(int saleId, int companyId) async {
    await db.update('sales', {'is_voided': 1},
        where: 'id = ?', whereArgs: [saleId]);
    DomainEventBus.instance.emit(SaleVoidedEvent(saleId: saleId, companyId: companyId));
  }

  /// Today's total sales for dashboards / AI.
  Future<double> getTodaysSalesTotal(int companyId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE company_id = ? AND sale_date LIKE ? AND is_voided = 0",
      [companyId, '$today%'],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
