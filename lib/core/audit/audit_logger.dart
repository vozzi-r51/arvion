import 'dart:convert';
import '../auth/session.dart';
import '../database/db_helper.dart';

/// Central place to write audit trail entries with before/after state diff.
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
    String? userName,
    Map<String, dynamic>? beforeValue,
    Map<String, dynamic>? afterValue,
  }) async {
    final effectiveUser = userName ?? Session.userIdentifier;
    await DBHelper.instance.insertAuditLog({
      'company_id': companyId,
      'module': module,
      'action': action,
      'description': description,
      'user_name': effectiveUser,
      'before_value': beforeValue != null ? jsonEncode(beforeValue) : null,
      'after_value': afterValue != null ? jsonEncode(afterValue) : null,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
