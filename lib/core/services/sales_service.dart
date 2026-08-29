import '../repositories/sales_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/customer_repository.dart';
import '../events/domain_event_bus.dart';
import '../database/db_helper.dart';

/// High-level service that coordinates multi-repository operations for sales.
/// Keeps screens free of business logic orchestration — just call
/// `createSaleWithItems()` and everything (stock, AR, events) happens.
class SalesService {
  final SalesRepository _salesRepo;

  SalesService({
    required SalesRepository salesRepository,
    InventoryRepository? inventoryRepository,
    CustomerRepository? customerRepository,
  })  : _salesRepo = salesRepository;

  /// Create a sale with items, handle stock deductions, AR updates.
  /// This is the screen-friendly entry point — all complexity hidden inside.
  Future<int> createSaleWithItems({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required bool allowNegativeStock,
  }) async {
    // For now, delegate to the legacy DBHelper method (which handles everything).
    // This is the transition layer: screens call the service, service can gradually
    // move logic to repositories without breaking screens.
    //
    // TODO: Over time, move stock deduction + AR update logic here:
    // 1. Create sale via repository (emits event)
    // 2. For each item, deduct stock via inventory repo
    // 3. If sale.is_due, update customer balance via customer repo
    // 4. All done—event has already triggered audit + ledger listeners
    //
    // For Phase 4, we keep using DBHelper to avoid rewriting the complex
    // transaction logic. Phase 5 will refactor this fully.

    final saleId = await DBHelper.instance.insertSaleWithItems(
      sale: sale,
      items: items,
      allowNegativeStock: allowNegativeStock,
    );

    // After legacy method completes, emit the event so listeners react
    // (audit log, journal posting, etc.)
    DomainEventBus.instance.emit(SaleCompletedEvent(
      saleId: saleId,
      companyId: sale['company_id'] as int,
      total: (sale['total'] as num).toDouble(),
      customerId: sale['customer_id'] as int?,
    ));

    return saleId;
  }

  /// Void a sale — calls repository, emits event.
  Future<void> voidSale(int saleId, int companyId) async {
    await _salesRepo.voidSale(saleId, companyId);
    // Event already emitted by repository
  }

  /// Get today's sales total (for dashboards / AI).
  Future<double> getTodaysSalesTotal(int companyId) async {
    return await _salesRepo.getTodaysSalesTotal(companyId);
  }

  /// Fetch paginated sales list.
  Future<List<Map<String, dynamic>>> listSales(
    int companyId, {
    int? limit,
    int? offset,
  }) async {
    return await _salesRepo.listSales(companyId, limit: limit, offset: offset);
  }

  /// Get sale items.
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    return await _salesRepo.getSaleItems(saleId);
  }
}
