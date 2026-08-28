import '../../database/db_helper.dart';

/// Work Center & Production Routing Step Enforcement Service.
class WorkCenterRoutingService {
  WorkCenterRoutingService._();

  /// Create a Work Center for a company.
  static Future<int> createWorkCenter({
    required int companyId,
    required String name,
    String? code,
    double capacityPerDay = 100,
    double costPerHour = 0,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('work_centers', {
      'company_id': companyId,
      'code': code ?? name.toUpperCase().replaceAll(' ', '_'),
      'name': name,
      'capacity_per_day': capacityPerDay,
      'cost_per_hour': costPerHour,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Add a Routing Step to a BOM.
  static Future<int> addRoutingStep({
    required int bomId,
    required int workCenterId,
    required int stepOrder,
    required String stepName,
    int estimatedTimeMinutes = 30,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('bom_routing_steps', {
      'bom_id': bomId,
      'work_center_id': workCenterId,
      'step_order': stepOrder,
      'step_name': stepName,
      'estimated_time_minutes': estimatedTimeMinutes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Initializes production routing progress records for a new Production Order from its BOM routing.
  static Future<void> initializeOrderRoutingProgress({
    required int productionOrderId,
    required int bomId,
  }) async {
    final db = await DBHelper.instance.database;
    final steps = await db.query(
      'bom_routing_steps',
      where: 'bom_id = ?',
      whereArgs: [bomId],
      orderBy: 'step_order ASC',
    );

    for (final step in steps) {
      await db.insert('production_routing_progress', {
        'production_order_id': productionOrderId,
        'routing_step_id': step['id'] as int,
        'status': 'pending',
      });
    }
  }

  /// Checks if all routing steps for a production order are marked completed.
  /// Throws StateError if routing steps are incomplete.
  static Future<bool> areAllRoutingStepsCompleted(int productionOrderId) async {
    final db = await DBHelper.instance.database;
    final steps = await db.query(
      'production_routing_progress',
      where: 'production_order_id = ?',
      whereArgs: [productionOrderId],
    );

    if (steps.isEmpty) return true; // No routing steps required

    final incomplete = steps.where((s) => s['status'] != 'completed').toList();
    if (incomplete.isNotEmpty) {
      throw StateError(
        'Production routing is not complete (${incomplete.length} steps remaining). Please complete all required steps first.',
      );
    }

    return true;
  }

  /// Updates progress status for a specific routing step in a Production Order.
  static Future<void> updateRoutingStepStatus({
    required int productionOrderId,
    required int routingStepId,
    required String status, // 'pending', 'in_progress', 'completed'
    String? completedBy,
  }) async {
    final db = await DBHelper.instance.database;
    await db.update(
      'production_routing_progress',
      {
        'status': status,
        'completed_at': status == 'completed' ? DateTime.now().toIso8601String() : null,
        'completed_by': completedBy,
      },
      where: 'production_order_id = ? AND routing_step_id = ?',
      whereArgs: [productionOrderId, routingStepId],
    );
  }
}
