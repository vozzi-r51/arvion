import '../events/domain_event_bus.dart';
import 'base_repository.dart';

/// Owns product + stock operations. Stock changes always emit
/// [StockAdjustedEvent] so analytics, low-stock alerts, and accounting
/// inventory valuations can react independently.
class InventoryRepository extends BaseRepository {
  InventoryRepository();

  Future<int> createProduct(Map<String, dynamic> product) async {
    final id = await db.insert('products', product);
    DomainEventBus.instance.emit(ProductCreatedEvent(
      productId: id,
      companyId: product['company_id'] as int,
    ));
    return id;
  }

  Future<List<Map<String, dynamic>>> listProducts(int companyId) async {
    return await db.query('products',
        where: 'company_id = ? AND deleted_at IS NULL', whereArgs: [companyId]);
  }

  Future<int> getProductCount(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM products "
      "WHERE company_id = ? AND deleted_at IS NULL",
      [companyId],
    );
    return (rows.first['c'] as num).toInt();
  }

  Future<int> getLowStockCount(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM products "
      "WHERE company_id = ? AND deleted_at IS NULL AND stock <= low_stock_alert",
      [companyId],
    );
    return (rows.first['c'] as num).toInt();
  }

  /// Apply a manual stock adjustment. Used for stock-take corrections,
  /// damages, transfers-in. Emits [StockAdjustedEvent] with `manual` reason.
  Future<void> adjustStock({
    required int productId,
    required int companyId,
    required double delta,
    String reason = 'manual',
  }) async {
    await db.rawUpdate(
      "UPDATE products SET stock = stock + ? WHERE id = ?",
      [delta, productId],
    );
    DomainEventBus.instance.emit(StockAdjustedEvent(
      productId: productId,
      companyId: companyId,
      delta: delta,
      reason: reason,
    ));
  }
}
