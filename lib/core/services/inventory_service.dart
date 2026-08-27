import '../repositories/inventory_repository.dart';

/// High-level service coordinating Inventory & Stock operations.
class InventoryService {
  final InventoryRepository _inventoryRepo;

  InventoryService({required InventoryRepository inventoryRepository})
      : _inventoryRepo = inventoryRepository;

  Future<int> createProduct(Map<String, dynamic> product) async {
    final id = await _inventoryRepo.createProduct(product);
    return id;
  }

  Future<List<Map<String, dynamic>>> listProducts(int companyId) async {
    return await _inventoryRepo.listProducts(companyId);
  }

  Future<int> getProductCount(int companyId) async {
    return await _inventoryRepo.getProductCount(companyId);
  }

  Future<int> getLowStockCount(int companyId) async {
    return await _inventoryRepo.getLowStockCount(companyId);
  }

  Future<void> adjustStock({
    required int productId,
    required int companyId,
    required double delta,
    String reason = 'manual',
  }) async {
    await _inventoryRepo.adjustStock(
      productId: productId,
      companyId: companyId,
      delta: delta,
      reason: reason,
    );
  }
}
