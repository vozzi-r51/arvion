import '../../database/db_helper.dart';

/// Multi-Level BOM & Recursive Dependency Engine.
class MultiLevelBomEngine {
  MultiLevelBomEngine._();

  /// Recursively checks if adding `candidateRawMaterialId` to `finishedProductId` BOM creates a circular dependency.
  /// Traverses down the candidate's BOM tree to ensure `finishedProductId` is never an ancestor or descendant.
  static Future<void> detectCircularDependency({
    required int companyId,
    required int finishedProductId,
    required int candidateRawMaterialId,
  }) async {
    if (finishedProductId == candidateRawMaterialId) {
      throw StateError('Cannot create BOM: Product cannot be a raw material of itself.');
    }

    final db = await DBHelper.instance.database;
    final visited = <int>{finishedProductId};

    await _checkCycleRecursive(
      db: db,
      companyId: companyId,
      currentProductId: candidateRawMaterialId,
      targetProductId: finishedProductId,
      visited: visited,
      depth: 0,
    );
  }

  static Future<void> _checkCycleRecursive({
    required dynamic db,
    required int companyId,
    required int currentProductId,
    required int targetProductId,
    required Set<int> visited,
    required int depth,
  }) async {
    if (depth > 15) {
      throw StateError('Cannot save BOM: Maximum recursion depth exceeded (corrupt/deep cycle).');
    }

    if (currentProductId == targetProductId || visited.contains(currentProductId)) {
      throw StateError('Cannot create BOM: Circular dependency detected involving Product #$currentProductId.');
    }

    visited.add(currentProductId);

    // Find if currentProductId has its own BOM
    final bomRows = await db.query(
      'bill_of_materials',
      columns: ['id'],
      where: 'company_id = ? AND finished_product_id = ?',
      whereArgs: [companyId, currentProductId],
    );

    for (final bom in bomRows) {
      final bomId = bom['id'] as int;
      final itemRows = await db.query(
        'bom_items',
        columns: ['raw_material_product_id'],
        where: 'bom_id = ?',
        whereArgs: [bomId],
      );

      for (final item in itemRows) {
        final nextRawId = item['raw_material_product_id'] as int;
        await _checkCycleRecursive(
          db: db,
          companyId: companyId,
          currentProductId: nextRawId,
          targetProductId: targetProductId,
          visited: Set<int>.from(visited),
          depth: depth + 1,
        );
      }
    }
  }

  /// Recursively calculates total raw material requirements and sub-assembly shortages for a production quantity.
  static Future<Map<String, dynamic>> calculateTotalMaterialRequirements({
    required int companyId,
    required int finishedProductId,
    required double quantityToProduce,
  }) async {
    final db = await DBHelper.instance.database;
    final Map<int, double> requiredMaterials = {};
    final List<Map<String, dynamic>> subAssemblyShortages = [];

    await _expandRequirementsRecursive(
      db: db,
      companyId: companyId,
      productId: finishedProductId,
      quantityNeeded: quantityToProduce,
      requiredMaterials: requiredMaterials,
      subAssemblyShortages: subAssemblyShortages,
      depth: 0,
    );

    return {
      'requiredMaterials': requiredMaterials,
      'subAssemblyShortages': subAssemblyShortages,
    };
  }

  static Future<void> _expandRequirementsRecursive({
    required dynamic db,
    required int companyId,
    required int productId,
    required double quantityNeeded,
    required Map<int, double> requiredMaterials,
    required List<Map<String, dynamic>> subAssemblyShortages,
    required int depth,
  }) async {
    if (depth > 10) return;

    final bomRows = await db.query(
      'bill_of_materials',
      where: 'company_id = ? AND finished_product_id = ?',
      whereArgs: [companyId, productId],
      limit: 1,
    );

    if (bomRows.isEmpty) {
      // Base raw material
      requiredMaterials[productId] = (requiredMaterials[productId] ?? 0.0) + quantityNeeded;
      return;
    }

    // Has BOM -> Sub-assembly / Manufactured item
    final bomId = bomRows.first['id'] as int;
    final itemRows = await db.query(
      'bom_items',
      where: 'bom_id = ?',
      whereArgs: [bomId],
    );

    // Check available stock of this sub-assembly
    final prodRows = await db.query(
      'products',
      columns: ['name', 'current_stock'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    final currentStock = prodRows.isNotEmpty ? (prodRows.first['current_stock'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final name = prodRows.isNotEmpty ? prodRows.first['name'] as String : 'Product #$productId';

    if (depth > 0 && currentStock < quantityNeeded) {
      final shortage = quantityNeeded - currentStock;
      subAssemblyShortages.add({
        'productId': productId,
        'productName': name,
        'bomId': bomId,
        'required': quantityNeeded,
        'available': currentStock,
        'shortage': shortage,
      });
    }

    for (final item in itemRows) {
      final rawId = item['raw_material_product_id'] as int;
      final qtyPerUnit = (item['quantity_required'] as num).toDouble();
      final totalChildNeeded = quantityNeeded * qtyPerUnit;

      await _expandRequirementsRecursive(
        db: db,
        companyId: companyId,
        productId: rawId,
        quantityNeeded: totalChildNeeded,
        requiredMaterials: requiredMaterials,
        subAssemblyShortages: subAssemblyShortages,
        depth: depth + 1,
      );
    }
  }
}
