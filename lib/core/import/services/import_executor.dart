import '../../database/db_helper.dart';
import '../models/import_models.dart';

/// Transaction-Safe Database Execution Engine for Universal Data Import.
class ImportExecutor {
  ImportExecutor._();

  /// Executes database insertions/updates inside an atomic SQL transaction.
  /// If any fatal error occurs, rolls back changes completely.
  static Future<ImportSummary> executeImport({
    required int companyId,
    required List<ParsedRow> rows,
    required ImportEntityType entityType,
    required DuplicatePolicy duplicatePolicy,
    String sourceName = 'CSV/Excel Import',
  }) async {
    final validRows = rows.where((r) => r.isValid).toList();
    final invalidRows = rows.where((r) => !r.isValid).toList();
    final duplicateRows = validRows.where((r) => r.isDuplicate).toList();

    int importedCount = 0;
    int skippedCount = invalidRows.length;

    final db = await DBHelper.instance.database;

    try {
      await db.transaction((txn) async {
        // Cache categories and brands maps for product import
        Map<String, int> categoryMap = {};
        Map<String, int> brandMap = {};

        if (entityType == ImportEntityType.products) {
          final categories = await txn.query('categories', where: 'company_id = ?', whereArgs: [companyId]);
          for (final c in categories) {
            categoryMap[(c['name'] as String).toLowerCase().trim()] = c['id'] as int;
          }

          final brands = await txn.query('brands', where: 'company_id = ?', whereArgs: [companyId]);
          for (final b in brands) {
            brandMap[(b['name'] as String).toLowerCase().trim()] = b['id'] as int;
          }
        }

        for (final row in validRows) {
          if (row.isDuplicate && duplicatePolicy == DuplicatePolicy.skip) {
            skippedCount++;
            continue;
          }

          final data = Map<String, dynamic>.from(row.mappedData);
          data['company_id'] = companyId;

          switch (entityType) {
            case ImportEntityType.products:
              final categoryName = (data['category_name'] as String? ?? '').trim();
              if (categoryName.isNotEmpty) {
                int? catId = categoryMap[categoryName.toLowerCase()];
                if (catId == null) {
                  catId = await txn.insert('categories', {
                    'company_id': companyId,
                    'name': categoryName,
                    'status': 'active',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  categoryMap[categoryName.toLowerCase()] = catId;
                }
                data['category_id'] = catId;
              }
              data.remove('category_name');

              final brandName = (data['brand_name'] as String? ?? '').trim();
              if (brandName.isNotEmpty) {
                int? bId = brandMap[brandName.toLowerCase()];
                if (bId == null) {
                  bId = await txn.insert('brands', {
                    'company_id': companyId,
                    'name': brandName,
                    'featured': 0,
                    'display_order': 0,
                    'status': 'active',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  brandMap[brandName.toLowerCase()] = bId;
                }
                data['brand_id'] = bId;
              }
              data.remove('brand_name');

              data['purchase_price'] = double.tryParse(data['purchase_price']?.toString() ?? '0') ?? 0.0;
              data['retail_price'] = double.tryParse(data['retail_price']?.toString() ?? '0') ?? 0.0;
              data['wholesale_price'] = double.tryParse(data['wholesale_price']?.toString() ?? '0') ?? 0.0;
              data['current_stock'] = double.tryParse(data['current_stock']?.toString() ?? '0') ?? 0.0;
              data['low_stock_level'] = double.tryParse(data['low_stock_level']?.toString() ?? '0') ?? 0.0;
              data['status'] = 'active';
              data['created_at'] = DateTime.now().toIso8601String();

              if (row.isDuplicate && duplicatePolicy == DuplicatePolicy.overwrite && row.existingRecord != null) {
                final existingId = row.existingRecord!['id'] as int;
                await txn.update('products', data, where: 'id = ?', whereArgs: [existingId]);
              } else {
                await txn.insert('products', data);
              }
              importedCount++;
              break;

            case ImportEntityType.customers:
              data['current_balance'] = double.tryParse(data['current_balance']?.toString() ?? '0') ?? 0.0;
              data['credit_limit'] = double.tryParse(data['credit_limit']?.toString() ?? '0') ?? 0.0;
              data['customer_type'] = data['customer_type'] ?? 'Retail';
              data['created_at'] = DateTime.now().toIso8601String();

              if (row.isDuplicate && duplicatePolicy == DuplicatePolicy.overwrite && row.existingRecord != null) {
                final existingId = row.existingRecord!['id'] as int;
                await txn.update('customers', data, where: 'id = ?', whereArgs: [existingId]);
              } else {
                await txn.insert('customers', data);
              }
              importedCount++;
              break;

            case ImportEntityType.suppliers:
              data['current_balance'] = double.tryParse(data['current_balance']?.toString() ?? '0') ?? 0.0;
              data['created_at'] = DateTime.now().toIso8601String();

              if (row.isDuplicate && duplicatePolicy == DuplicatePolicy.overwrite && row.existingRecord != null) {
                final existingId = row.existingRecord!['id'] as int;
                await txn.update('suppliers', data, where: 'id = ?', whereArgs: [existingId]);
              } else {
                await txn.insert('suppliers', data);
              }
              importedCount++;
              break;

            case ImportEntityType.openingBalances:
              // Post to cash book or customer/supplier ledgers
              final name = data['account_or_name']?.toString() ?? '';
              final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;

              if (name.isNotEmpty && amount != 0) {
                await txn.insert('cash_book', {
                  'company_id': companyId,
                  'type': amount > 0 ? 'in' : 'out',
                  'amount': amount.abs(),
                  'description': 'Opening Balance Import: $name',
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
              importedCount++;
              break;
          }
        }
      });
    } catch (e) {
      // Transaction rolled back automatically on error
      return ImportSummary(
        totalRows: rows.length,
        validRows: validRows.length,
        invalidRows: invalidRows.length,
        duplicateRows: duplicateRows.length,
        importedCount: 0,
        skippedCount: rows.length,
      );
    }

    return ImportSummary(
      totalRows: rows.length,
      validRows: validRows.length,
      invalidRows: invalidRows.length,
      duplicateRows: duplicateRows.length,
      importedCount: importedCount,
      skippedCount: skippedCount,
    );
  }
}
