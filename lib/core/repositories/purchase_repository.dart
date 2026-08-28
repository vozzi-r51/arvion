import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns all purchase-related persistence: creating purchases with items,
/// listing, voiding. Side-effects happen via event listeners.
class PurchaseRepository extends BaseRepository {
  PurchaseRepository();

  /// Create a purchase with its items + emit `PurchaseCompletedEvent`.
  Future<int> createPurchase({
    required Map<String, dynamic> purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    final purchaseId = await db.transaction((txn) async {
      final id = await txn.insert('purchases', purchase);
      for (final item in items) {
        item['purchase_id'] = id;
        await txn.insert('purchase_items', item);
      }
      return id;
    });

    DomainEventBus.instance.emit(PurchaseCompletedEvent(
      purchaseId: purchaseId,
      companyId: purchase['company_id'] as int,
      total: (purchase['total'] as num).toDouble(),
      supplierId: purchase['supplier_id'] as int?,
    ));
    return purchaseId;
  }

  /// Fetch purchases list (paginated).
  Future<List<Map<String, dynamic>>> listPurchases(
    int companyId, {
    int? limit,
    int? offset,
  }) async {
    return await db.query(
      'purchases',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Fetch items for a purchase.
  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    return await db.query('purchase_items',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
  }

  /// Today's total purchases for dashboards / AI.
  Future<double> getTodaysPurchaseTotal(int companyId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) AS total FROM purchases "
      "WHERE company_id = ? AND purchase_date LIKE ?",
      [companyId, '$today%'],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
