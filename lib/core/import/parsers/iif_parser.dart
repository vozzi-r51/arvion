import 'dart:io';
import '../models/import_models.dart';
import '../services/smart_column_mapper.dart';

/// QuickBooks Desktop IIF (Intuit Interchange Format) Text Parser (Phase 2 Architecture).
/// Parses tab-delimited !ITEMLIST and !CUSTLIST records into standard BizManager mappings.
class IifParser {
  IifParser();

  Future<Map<String, dynamic>> parseIifFile({
    required String filePath,
    required ImportEntityType entityType,
  }) async {
    final file = File(filePath);
    final lines = await file.readAsLines();

    List<String> headers = [];
    final List<Map<String, String>> rows = [];
    final String targetHeaderPrefix =
        entityType == ImportEntityType.products ? '!INVITEM' : '!CUST';

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final tokens = line.split('\t').map((t) => t.trim()).toList();

      if (tokens.isEmpty) continue;

      if (tokens.first.toUpperCase() == targetHeaderPrefix) {
        // Header definition line
        headers = tokens.sublist(1);
      } else if (headers.isNotEmpty && tokens.first.startsWith('INVITEM') ||
          tokens.first.startsWith('CUST')) {
        // Data line
        final values = tokens.sublist(1);
        final Map<String, String> rowMap = {};

        for (int i = 0; i < headers.length; i++) {
          final h = headers[i];
          final val = i < values.length ? values[i] : '';
          rowMap[h] = val;
        }

        rows.add(rowMap);
      }
    }

    if (headers.isEmpty) {
      // Fallback default headers if IIF header tag missing
      headers = entityType == ImportEntityType.products
          ? ['NAME', 'INVITEMTYPE', 'DESC', 'PRICE', 'COST', 'QTYONHAND']
          : ['NAME', 'COMPANYNAME', 'PHONE1', 'BADDR1', 'SALESTAXCODE'];
    }

    final mappings = SmartColumnMapper.mapColumns(
      headers: headers,
      entityType: entityType,
      source: ImportSource.quickbooks,
    );

    return {
      'headers': headers,
      'mappings': mappings,
      'rows': rows,
    };
  }
}
