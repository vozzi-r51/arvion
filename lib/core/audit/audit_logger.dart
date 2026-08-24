import '../database/db_helper.dart';

/// Central place to write audit trail entries. Call this after any
/// meaningful change so there's a record of who/what/when — not a
/// replacement for proper multi-user accounts (this app is single-PIN,
/// single-device), but a log of activity on this device for this company.
class AuditLogger {
  AuditLogger._();

  static const login = 'login';
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const stockChange = 'stock_change';

  static Future<void> log({
    required int companyId,
    required String module,
    required String action,
    required String description,
  }) async {
    await DBHelper.instance.insertAuditLog({
      'company_id': companyId,
      'module': module,
      'action': action,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
