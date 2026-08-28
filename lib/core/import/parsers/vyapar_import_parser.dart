import '../models/import_models.dart';
import '../services/smart_column_mapper.dart';
import 'generic_csv_excel_parser.dart';

/// Specialized Vyapar App Excel/CSV Parser.
class VyaparImportParser {
  VyaparImportParser();

  Future<Map<String, dynamic>> parseFile({
    required String filePath,
    required ImportEntityType entityType,
  }) async {
    final genericResult = await GenericCsvExcelParser().parseFile(filePath);
    final List<String> headers = List<String>.from(genericResult['headers']);
    final List<Map<String, String>> rows =
        List<Map<String, String>>.from(genericResult['rows']);

    final mappings = SmartColumnMapper.mapColumns(
      headers: headers,
      entityType: entityType,
      source: ImportSource.vyapar,
    );

    return {
      'headers': headers,
      'mappings': mappings,
      'rows': rows,
    };
  }
}
