import '../../database/db_helper.dart';

/// Construction & Project-Based Business Engine.
class ProjectManagementService {
  ProjectManagementService._();

  static Future<int> createProject({
    required int companyId,
    int? customerId,
    required String projectName,
    required String projectNumber,
    double budgetAmount = 0,
    String? startDate,
    String? expectedEndDate,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('projects', {
      'company_id': companyId,
      'customer_id': customerId,
      'project_name': projectName,
      'project_number': projectNumber,
      'budget_amount': budgetAmount,
      'status': 'in_progress',
      'completion_percent': 0.0,
      'start_date': startDate ?? DateTime.now().toIso8601String().substring(0, 10),
      'expected_end_date': expectedEndDate,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateCompletionPercent(int projectId, double percent) async {
    if (percent < 0 || percent > 100) {
      throw RangeError('Completion percent must be between 0 and 100.');
    }

    final db = await DBHelper.instance.database;
    await db.update(
      'projects',
      {'completion_percent': percent, 'status': percent == 100 ? 'completed' : 'in_progress'},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }
}
