import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';

class FullDataExportService {
  FullDataExportService._();

  static Future<void> exportAllToCsv(int companyId) async {
    final products = await DBHelper.instance.getProducts(companyId);
    final customers = await DBHelper.instance.getCustomers(companyId);
    final sales = await DBHelper.instance.getSales(companyId);

    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(p.join(tempDir.path, 'ARVION_Export_${DateTime.now().millisecondsSinceEpoch}'));
    await exportDir.create(recursive: true);

    // 1. Products
    final prodFile = File(p.join(exportDir.path, 'products.csv'));
    final prodData = [
      ['ID', 'Name', 'Code', 'Barcode', 'Category', 'Purchase Price', 'Retail Price', 'Stock'],
      ...products.map((p) => [
        p['id'], p['name'], p['product_code'], p['barcode'], p['category_name'],
        p['purchase_price'], p['retail_price'], p['current_stock']
      ]),
    ];
    await prodFile.writeAsString(_toCsv(prodData));

    // 2. Customers
    final custFile = File(p.join(exportDir.path, 'customers.csv'));
    final custData = [
      ['ID', 'Name', 'Mobile', 'Type', 'Balance'],
      ...customers.map((c) => [
        c['id'], c['name'], c['mobile'], c['customer_type'], c['current_balance']
      ]),
    ];
    await custFile.writeAsString(_toCsv(custData));

    // 3. Sales
    final salesFile = File(p.join(exportDir.path, 'sales_history.csv'));
    final salesData = [
      ['Invoice', 'Date', 'Customer', 'Subtotal', 'Discount', 'Tax', 'Total', 'Paid', 'Due', 'Status'],
      ...sales.map((s) => [
        s['invoice_number'], s['sale_date'], s['customer_name'] ?? 'Walk-in',
        s['subtotal'], s['discount_amount'], s['tax_amount'], s['total_amount'],
        s['paid_amount'], s['due_amount'], s['status']
      ]),
    ];
    await salesFile.writeAsString(_toCsv(salesData));

    // Share all files
    await Share.shareXFiles(
      [
        XFile(prodFile.path),
        XFile(custFile.path),
        XFile(salesFile.path),
      ],
      text: 'ARVION Business Data Export (CSV)',
    );
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
