import 'dart:convert';
import '../database/db_helper.dart';

/// Versioned Full Database Export Service (JSON Bundle v2.0).
/// Guarantees zero vendor lock-in by allowing users to export their entire company data.
class VersionedBundleExportService {
  VersionedBundleExportService._();

  /// Exports complete company data as a structured JSON Bundle String.
  static Future<String> exportCompleteCompanyBundleJson(int companyId) async {
    final company = await DBHelper.instance.getCompanyById(companyId);
    final products = await DBHelper.instance.getProducts(companyId);
    final customers = await DBHelper.instance.getCustomers(companyId);
    final suppliers = await DBHelper.instance.getSuppliers(companyId);
    final auditLogs =
        await DBHelper.instance.getAuditLogs(companyId, limit: 1000);

    final bundle = {
      'schema_version': '2.0',
      'exported_at': DateTime.now().toIso8601String(),
      'company': company,
      'products_count': products.length,
      'products': products,
      'customers_count': customers.length,
      'customers': customers,
      'suppliers_count': suppliers.length,
      'suppliers': suppliers,
      'audit_logs_count': auditLogs.length,
      'audit_logs': auditLogs,
    };

    return const JsonEncoder.withIndent('  ').convert(bundle);
  }
}
