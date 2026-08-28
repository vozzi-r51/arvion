import 'dart:io';
import '../models/import_models.dart';
import '../services/smart_column_mapper.dart';
import 'generic_csv_excel_parser.dart';

/// Specialized Tally ERP & Tally Prime Excel & XML Parser.
class TallyImportParser {
  TallyImportParser();

  Future<Map<String, dynamic>> parseFile({
    required String filePath,
    required ImportEntityType entityType,
  }) async {
    final lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.xml')) {
      return await _parseTallyXml(filePath, entityType);
    }

    // Default Excel/CSV fallback for Tally exports
    final genericResult = await GenericCsvExcelParser().parseFile(filePath);
    final List<String> headers = List<String>.from(genericResult['headers']);
    final List<Map<String, String>> rows = List<Map<String, String>>.from(genericResult['rows']);

    final mappings = SmartColumnMapper.mapColumns(
      headers: headers,
      entityType: entityType,
      source: ImportSource.tally,
    );

    return {
      'headers': headers,
      'mappings': mappings,
      'rows': rows,
    };
  }

  /// Parses Tally XML export files safely.
  Future<Map<String, dynamic>> _parseTallyXml(String filePath, ImportEntityType entityType) async {
    final file = File(filePath);
    final content = await file.readAsString();

    final List<String> headers = entityType == ImportEntityType.products
        ? ['Stock Item Name', 'Closing Balance', 'Rate', 'Amount']
        : ['Ledger Name', 'Opening Balance', 'Phone', 'Address'];

    final List<Map<String, String>> rows = [];

    // Simple regex extraction for Tally XML tags
    final itemMatches = RegExp(r'<STOCKITEM NAME="([^"]+)">([\s\S]*?)</STOCKITEM>', caseSensitive: false)
        .allMatches(content);

    for (final match in itemMatches) {
      final name = match.group(1) ?? '';
      final body = match.group(2) ?? '';

      final rateMatch = RegExp(r'<RATE>([^<]+)</RATE>').firstMatch(body);
      final qtyMatch = RegExp(r'<OPENINGBALANCE>([^<]+)</OPENINGBALANCE>').firstMatch(body);

      rows.add({
        'Stock Item Name': name,
        'Closing Balance': qtyMatch?.group(1) ?? '0',
        'Rate': rateMatch?.group(1) ?? '0',
        'Amount': '0',
      });
    }

    final mappings = SmartColumnMapper.mapColumns(
      headers: headers,
      entityType: entityType,
      source: ImportSource.tally,
    );

    return {
      'headers': headers,
      'mappings': mappings,
      'rows': rows,
    };
  }
}
