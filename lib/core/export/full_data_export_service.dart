import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';

/// Full Business Data Export Service.
/// Exports complete business data across 15+ domain entities into CSV/Excel compatible files
/// while excluding sensitive secrets (PINs, passwords, encryption keys).
class FullDataExportService {
  FullDataExportService._();

  static Future<Map<String, int>> exportFullBusinessData(int companyId) async {
    final db = await DBHelper.instance.database;

    final company = await db.query('companies', where: 'id = ?', whereArgs: [companyId]);
    final products = await db.query('products', where: 'company_id = ?', whereArgs: [companyId]);
    final customers = await db.query('customers', where: 'company_id = ?', whereArgs: [companyId]);
    final suppliers = await db.query('suppliers', where: 'company_id = ?', whereArgs: [companyId]);
    final sales = await db.query('sales', where: 'company_id = ?', whereArgs: [companyId]);
    final purchases = await db.query('purchases', where: 'company_id = ?', whereArgs: [companyId]);
    final expenses = await db.query('expenses', where: 'company_id = ?', whereArgs: [companyId]);
    final stockAdjustments = await db.query('stock_adjustments', where: 'company_id = ?', whereArgs: [companyId]);
    final accounts = await db.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
    final journals = await db.query('journal_entries', where: 'company_id = ?', whereArgs: [companyId]);
    final costCenters = await db.query('cost_centers', where: 'company_id = ?', whereArgs: [companyId]);
    final fixedAssets = await db.query('fixed_assets', where: 'company_id = ?', whereArgs: [companyId]);
    final budgets = await db.query('budgets', where: 'company_id = ?', whereArgs: [companyId]);
    final bankAccounts = await db.query('bank_accounts', where: 'company_id = ?', whereArgs: [companyId]);
    final bankTransactions = await db.query('bank_transactions', where: 'company_id = ?', whereArgs: [companyId]);
    final boms = await db.query('bill_of_materials', where: 'company_id = ?', whereArgs: [companyId]);
    final productionOrders = await db.query('production_orders', where: 'company_id = ?', whereArgs: [companyId]);
    final serviceJobs = await db.query('service_jobs', where: 'company_id = ?', whereArgs: [companyId]);
    final restaurantTables = await db.query('restaurant_tables', where: 'company_id = ?', whereArgs: [companyId]);
    final auditLogs = await db.query('audit_log', where: 'company_id = ?', whereArgs: [companyId]);

    final tempDir = await getTemporaryDirectory();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final exportDir = Directory(p.join(tempDir.path, 'BizManager_FullExport_${todayStr}_${DateTime.now().millisecondsSinceEpoch}'));
    await exportDir.create(recursive: true);

    final List<XFile> filesToShare = [];

    Future<void> writeTableCsv(String filename, List<Map<String, dynamic>> records) async {
      if (records.isEmpty) return;
      final file = File(p.join(exportDir.path, filename));

      // Extract sanitize headers
      final headers = records.first.keys
          .where((k) => k != 'pin_hash' && k != 'pin_salt' && k != 'db_encryption_key' && k != 'security_answer')
          .toList();

      final rows = [
        headers,
        ...records.map((r) => headers.map((h) => r[h]).toList()),
      ];

      await file.writeAsString(_toCsv(rows));
      filesToShare.add(XFile(file.path));
    }

    await writeTableCsv('1_company_profile.csv', company);
    await writeTableCsv('2_products.csv', products);
    await writeTableCsv('3_customers.csv', customers);
    await writeTableCsv('4_suppliers.csv', suppliers);
    await writeTableCsv('5_sales_invoices.csv', sales);
    await writeTableCsv('6_purchases_invoices.csv', purchases);
    await writeTableCsv('7_expenses.csv', expenses);
    await writeTableCsv('8_stock_adjustments.csv', stockAdjustments);
    await writeTableCsv('9_chart_of_accounts.csv', accounts);
    await writeTableCsv('10_journal_entries.csv', journals);
    await writeTableCsv('11_cost_centers.csv', costCenters);
    await writeTableCsv('12_fixed_assets.csv', fixedAssets);
    await writeTableCsv('13_budgets.csv', budgets);
    await writeTableCsv('14_bank_accounts.csv', bankAccounts);
    await writeTableCsv('15_bank_transactions.csv', bankTransactions);
    await writeTableCsv('16_boms.csv', boms);
    await writeTableCsv('17_production_orders.csv', productionOrders);
    await writeTableCsv('18_service_jobs.csv', serviceJobs);
    await writeTableCsv('19_restaurant_tables.csv', restaurantTables);
    await writeTableCsv('20_audit_log.csv', auditLogs);

    if (filesToShare.isNotEmpty) {
      await Share.shareXFiles(
        filesToShare,
        text: 'BizManager Full Business Data Export ($todayStr)',
      );
    }

    return {
      'products': products.length,
      'customers': customers.length,
      'suppliers': suppliers.length,
      'sales': sales.length,
      'purchases': purchases.length,
      'expenses': expenses.length,
      'journals': journals.length,
      'bankTransactions': bankTransactions.length,
    };
  }

  static String _toCsv(List<List<dynamic>> rows) {
    return rows.map((row) => row.map((cell) {
      final str = cell?.toString() ?? '';
      if (str.contains(',') || str.contains('"') || str.contains('\n')) {
        return '"${str.replaceAll('"', '""')}"';
      }
      return str;
    }).join(',')).join('\n');
  }
}
