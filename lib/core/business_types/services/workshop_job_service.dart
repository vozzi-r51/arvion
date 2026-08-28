import '../../database/db_helper.dart';

/// Automotive / Vehicle Workshop Job Engine.
/// Combines Parts (deducts stock) + Labor / Services (zero stock deduction) into a single invoice.
class WorkshopJobService {
  WorkshopJobService._();

  /// Create a customer vehicle record.
  static Future<int> createVehicle({
    required int companyId,
    int? customerId,
    required String registrationNumber,
    String? make,
    String? model,
    int? year,
    int currentOdometer = 0,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('vehicles', {
      'company_id': companyId,
      'customer_id': customerId,
      'registration_number': registrationNumber.toUpperCase().trim(),
      'make': make,
      'model': model,
      'year': year,
      'current_odometer': currentOdometer,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Create a new Workshop Job.
  static Future<int> createWorkshopJob({
    required int companyId,
    int? customerId,
    int? vehicleId,
    required String jobNumber,
    required String complaint,
    String? diagnosis,
    int? technicianId,
    int odometer = 0,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('workshop_jobs', {
      'company_id': companyId,
      'customer_id': customerId,
      'vehicle_id': vehicleId,
      'job_number': jobNumber,
      'status': 'in_progress',
      'opening_date': DateTime.now().toIso8601String().substring(0, 10),
      'odometer': odometer,
      'complaint': complaint,
      'diagnosis': diagnosis,
      'technician_id': technicianId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Evaluates stock deduction rules for workshop line items:
  /// - Parts (product_id != null) -> Deduct physical stock.
  /// - Labor / Service items -> ZERO stock deduction!
  static bool requiresStockDeduction(
      {required String itemType, int? productId}) {
    if (itemType == 'part' && productId != null) return true;
    return false; // Labor and Service items do NOT deduct inventory
  }
}
