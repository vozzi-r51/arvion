import 'base_repository.dart';

/// Repository for HR, Employees, Attendance, Salaries, Advance & Commissions.
class HrRepository extends BaseRepository {
  HrRepository();

  Future<int> createEmployee(Map<String, dynamic> data) async {
    return await db.insert('employees', data);
  }

  Future<List<Map<String, dynamic>>> listEmployees(int companyId) async {
    return await db.query(
      'employees',
      where: 'company_id = ? AND deleted_at IS NULL',
      whereArgs: [companyId],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getEmployeeById(int id) async {
    final rows =
        await db.query('employees', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> data) async {
    await db.update('employees', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteEmployee(int id) async {
    await db.update(
      'employees',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> recordAttendance(Map<String, dynamic> data) async {
    return await db.insert('attendance', data);
  }

  Future<List<Map<String, dynamic>>> getAttendance(int employeeId,
      {String? month}) async {
    String where = 'employee_id = ?';
    List<dynamic> args = [employeeId];
    if (month != null) {
      where += ' AND date LIKE ?';
      args.add('$month%');
    }
    return await db.query('attendance',
        where: where, whereArgs: args, orderBy: 'date DESC');
  }

  Future<int> recordSalary(Map<String, dynamic> data) async {
    return await db.insert('salary_payments', data);
  }

  Future<int> recordAdvance(Map<String, dynamic> data) async {
    return await db.insert('advance_salary', data);
  }

  Future<int> recordCommission(Map<String, dynamic> data) async {
    return await db.insert('commissions', data);
  }
}
