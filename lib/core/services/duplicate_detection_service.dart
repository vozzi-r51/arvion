import '../database/db_helper.dart';
import '../utils/phone_formatter.dart';

/// Service for Company-Scoped Duplicate Customer & Supplier Detection.
class DuplicateDetectionService {
  DuplicateDetectionService._();

  static String normalizeName(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Finds potential duplicate customer in the same company by normalized name or phone.
  /// Excludes excludeCustomerId when editing an existing customer.
  static Future<Map<String, dynamic>?> findCustomerDuplicate({
    required int companyId,
    required String name,
    String? mobile,
    int? excludeCustomerId,
  }) async {
    final normName = normalizeName(name);
    if (normName.isEmpty) return null;

    final normPhone = mobile != null ? PhoneFormatter.toWhatsAppNumber(mobile) : '';

    final db = await DBHelper.instance.database;
    final customers = await db.query(
      'customers',
      where: 'company_id = ? AND (deleted_at IS NULL OR deleted_at = "")',
      whereArgs: [companyId],
    );

    for (final c in customers) {
      final id = c['id'] as int;
      if (excludeCustomerId != null && id == excludeCustomerId) continue;

      final existingName = normalizeName(c['name'] as String? ?? '');
      final existingMobile = PhoneFormatter.toWhatsAppNumber(c['mobile'] as String? ?? '');

      final isNameMatch = existingName.isNotEmpty && existingName == normName;
      final isPhoneMatch = normPhone.isNotEmpty && existingMobile.isNotEmpty && existingMobile == normPhone;

      if (isNameMatch || isPhoneMatch) {
        return c;
      }
    }

    return null;
  }

  /// Finds potential duplicate supplier in the same company by normalized company name or phone.
  /// Excludes excludeSupplierId when editing an existing supplier.
  static Future<Map<String, dynamic>?> findSupplierDuplicate({
    required int companyId,
    required String companyName,
    String? phone,
    int? excludeSupplierId,
  }) async {
    final normName = normalizeName(companyName);
    if (normName.isEmpty) return null;

    final normPhone = phone != null ? PhoneFormatter.toWhatsAppNumber(phone) : '';

    final db = await DBHelper.instance.database;
    final suppliers = await db.query(
      'suppliers',
      where: 'company_id = ? AND (deleted_at IS NULL OR deleted_at = "")',
      whereArgs: [companyId],
    );

    for (final s in suppliers) {
      final id = s['id'] as int;
      if (excludeSupplierId != null && id == excludeSupplierId) continue;

      final existingName = normalizeName(s['company_name'] as String? ?? '');
      final existingPhone = PhoneFormatter.toWhatsAppNumber(s['phone'] as String? ?? '');

      final isNameMatch = existingName.isNotEmpty && existingName == normName;
      final isPhoneMatch = normPhone.isNotEmpty && existingPhone.isNotEmpty && existingPhone == normPhone;

      if (isNameMatch || isPhoneMatch) {
        return s;
      }
    }

    return null;
  }
}
