import '../repositories/purchase_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/supplier_repository.dart';
import '../events/domain_event_bus.dart';
import '../database/db_helper.dart';

/// High-level service coordinating multi-repository operations for purchases.
class PurchaseService {
  final PurchaseRepository _purchaseRepo;

  PurchaseService({
    required PurchaseRepository purchaseRepository,
    InventoryRepository? inventoryRepository,
    SupplierRepository? supplierRepository,
  })  : _purchaseRepo = purchaseRepository;

  /// Create a purchase with items, handle stock additions, AP updates.
  Future<int> createPurchaseWithItems({
    required Map<String, dynamic> purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    // TODO Phase 5: Move stock addition + AP update logic here.
    // For Phase 4, use legacy DBHelper method as transition layer.
    final purchaseId = await DBHelper.instance.insertPurchaseWithItems(
      purchase: purchase,
      items: items,
    );

    // Emit event so listeners (audit, ledger) react
    DomainEventBus.instance.emit(PurchaseCompletedEvent(
      purchaseId: purchaseId,
      companyId: purchase['company_id'] as int,
      total: (purchase['total'] as num).toDouble(),
      supplierId: purchase['supplier_id'] as int?,
    ));

    return purchaseId;
  }

  /// Get today's purchase total.
  Future<double> getTodaysPurchaseTotal(int companyId) async {
    return await _purchaseRepo.getTodaysPurchaseTotal(companyId);
  }

  /// List purchases paginated.
  Future<List<Map<String, dynamic>>> listPurchases(
    int companyId, {
    int? limit,
    int? offset,
  }) async {
    return await _purchaseRepo.listPurchases(companyId,
        limit: limit, offset: offset);
  }

  /// Get purchase items.
  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    return await _purchaseRepo.getPurchaseItems(purchaseId);
  }
}
