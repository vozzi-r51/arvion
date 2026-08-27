import '../models/cost_center.dart';
import 'base_repository.dart';

/// Owns cost center (branch/department/warehouse) master data.
/// Every transaction can be tagged with a cost center for dimensional reporting.
class CostCenterRepository extends BaseRepository {
  CostCenterRepository();

  /// Create a new cost center.
  Future<int> createCostCenter({
    required int companyId,
    required String code,
    required String name,
    required String type, // 'branch' | 'department' | 'warehouse' | 'store'
    String? description,
  }) async {
    final id = await db.insert('cost_centers', {
      'company_id': companyId,
      'code': code,
      'name': name,
      'type': type,
      'description': description,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// List all active cost centers for a company.
  Future<List<CostCenter>> listCostCenters(int companyId) async {
    final rows = await db.query(
      'cost_centers',
      where: 'company_id = ? AND is_active = 1',
      whereArgs: [companyId],
      orderBy: 'type ASC, name ASC',
    );
    return rows.map((r) => CostCenter.fromMap(r)).toList();
  }

  /// Get cost centers filtered by type (e.g., all branches).
  Future<List<CostCenter>> listByType(int companyId, String type) async {
    final rows = await db.query(
      'cost_centers',
      where: 'company_id = ? AND type = ? AND is_active = 1',
      whereArgs: [companyId, type],
      orderBy: 'name ASC',
    );
    return rows.map((r) => CostCenter.fromMap(r)).toList();
  }

  /// Get a specific cost center.
  Future<CostCenter?> getCostCenterById(int id) async {
    final rows = await db.query(
      'cost_centers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CostCenter.fromMap(rows.first);
  }

  /// Update cost center details.
  Future<void> updateCostCenter(
    int id, {
    String? name,
    String? description,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isActive != null) updates['is_active'] = isActive ? 1 : 0;

    if (updates.isNotEmpty) {
      await db.update('cost_centers', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Soft-deactivate a cost center (don't delete historical data).
  Future<void> deactivateCostCenter(int id) async {
    await db.update(
      'cost_centers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get cost center count for a company.
  Future<int> getCostCenterCount(int companyId) async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM cost_centers WHERE company_id = ? AND is_active = 1",
      [companyId],
    );
    return (rows.first['c'] as num).toInt();
  }
}
