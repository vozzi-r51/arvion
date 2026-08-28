import '../../database/db_helper.dart';
import '../models/import_models.dart';

/// Pre-import Duplicate Detection Engine against existing database records.
class DuplicateDetector {
  DuplicateDetector._();

  /// Flags duplicate rows against existing database entities.
  static Future<List<ParsedRow>> detectDuplicates({
    required int companyId,
    required List<ParsedRow> rows,
    required ImportEntityType entityType,
  }) async {
    switch (entityType) {
      case ImportEntityType.products:
        final existingProducts = await DBHelper.instance.getProducts(companyId);
        final existingMap = <String, Map<String, dynamic>>{};

        for (final p in existingProducts) {
          final normName = _normalize(p['name'] as String? ?? '');
          final sku = (p['product_code'] as String? ?? '').trim().toLowerCase();
          final barcode = (p['barcode'] as String? ?? '').trim().toLowerCase();

          if (normName.isNotEmpty) existingMap[normName] = p;
          if (sku.isNotEmpty) existingMap['sku:$sku'] = p;
          if (barcode.isNotEmpty) existingMap['bar:$barcode'] = p;
        }

        for (final row in rows) {
          if (!row.isValid) continue;
          final name = _normalize(row.mappedData['name']?.toString() ?? '');
          final sku = (row.mappedData['product_code']?.toString() ?? '')
              .trim()
              .toLowerCase();
          final barcode = (row.mappedData['barcode']?.toString() ?? '')
              .trim()
              .toLowerCase();

          if (existingMap.containsKey(name) ||
              (sku.isNotEmpty && existingMap.containsKey('sku:$sku')) ||
              (barcode.isNotEmpty && existingMap.containsKey('bar:$barcode'))) {
            row.isDuplicate = true;
            row.existingRecord = existingMap[name] ??
                existingMap['sku:$sku'] ??
                existingMap['bar:$barcode'];
          }
        }
        break;

      case ImportEntityType.customers:
        final existingCustomers =
            await DBHelper.instance.getCustomers(companyId);
        final existingMap = <String, Map<String, dynamic>>{};

        for (final c in existingCustomers) {
          final normName = _normalize(c['name'] as String? ?? '');
          final mobile = (c['mobile'] as String? ?? '').trim();
          if (normName.isNotEmpty) existingMap[normName] = c;
          if (mobile.isNotEmpty) existingMap['mob:$mobile'] = c;
        }

        for (final row in rows) {
          if (!row.isValid) continue;
          final name = _normalize(row.mappedData['name']?.toString() ?? '');
          final mobile = (row.mappedData['mobile']?.toString() ?? '').trim();

          if (existingMap.containsKey(name) ||
              (mobile.isNotEmpty && existingMap.containsKey('mob:$mobile'))) {
            row.isDuplicate = true;
            row.existingRecord =
                existingMap[name] ?? existingMap['mob:$mobile'];
          }
        }
        break;

      case ImportEntityType.suppliers:
        final existingSuppliers =
            await DBHelper.instance.getSuppliers(companyId);
        final existingMap = <String, Map<String, dynamic>>{};

        for (final s in existingSuppliers) {
          final normName = _normalize(s['company_name'] as String? ?? '');
          final phone = (s['phone'] as String? ?? '').trim();
          if (normName.isNotEmpty) existingMap[normName] = s;
          if (phone.isNotEmpty) existingMap['ph:$phone'] = s;
        }

        for (final row in rows) {
          if (!row.isValid) continue;
          final name =
              _normalize(row.mappedData['company_name']?.toString() ?? '');
          final phone = (row.mappedData['phone']?.toString() ?? '').trim();

          if (existingMap.containsKey(name) ||
              (phone.isNotEmpty && existingMap.containsKey('ph:$phone'))) {
            row.isDuplicate = true;
            row.existingRecord = existingMap[name] ?? existingMap['ph:$phone'];
          }
        }
        break;

      case ImportEntityType.openingBalances:
        // Opening balances don't require duplicate detection prior to posting
        break;
    }

    return rows;
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
