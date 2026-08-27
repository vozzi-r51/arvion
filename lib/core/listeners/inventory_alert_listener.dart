import '../database/db_helper.dart';
import '../events/domain_event_bus.dart';

/// Listens to inventory events and dispatches alerts (low stock, reorder reminders).
/// Separates inventory monitoring from core inventory operations.
/// Currently logs to console; can be extended to send notifications.
class InventoryAlertListener {
  InventoryAlertListener();

  final List<Function> _disposers = [];

  void register() {
    _disposers.add(
      DomainEventBus.instance.on<StockAdjustedEvent>((e) async {
        // When stock decreases (sale, damage, transfer), check if now below threshold.
        if (e.delta < 0) {
          try {
            final db = DBHelper.instance.db;
            final productRows = await db.query(
              'products',
              where: 'id = ?',
              whereArgs: [e.productId],
            );
            if (productRows.isEmpty) return;

            final product = productRows.first;
            final currentStock = (product['stock'] as num).toDouble();
            final lowStockAlert = (product['low_stock_alert'] as num?)?.toDouble() ?? 10.0;

            if (currentStock <= lowStockAlert) {
              // TODO: Send notification
              // await NotificationService.sendLowStockAlert(
              //   companyId: e.companyId,
              //   productId: e.productId,
              //   productName: product['name'],
              //   currentStock: currentStock,
              //   threshold: lowStockAlert,
              // );
              // For now, just log it
              // ignore: avoid_print
              print('⚠️  LOW STOCK ALERT: Product #${e.productId} now at $currentStock (threshold: $lowStockAlert)');
            }
          } catch (err) {
            // ignore: avoid_print
            print('❌ Inventory alert listener error: $err');
          }
        }
      }),
    );

    _disposers.add(
      DomainEventBus.instance.on<ProductCreatedEvent>((e) async {
        // When a product is added, optionally initialize inventory tracking defaults.
        // TODO: Could auto-create reorder templates, set default thresholds, etc.
        // For now, just log
        // ignore: avoid_print
        print('✅ Product created: #${e.productId}');
      }),
    );
  }

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
  }
}

