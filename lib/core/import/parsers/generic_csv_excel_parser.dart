import 'dart:io';

/// Parses CSV / Excel file content into header lists and row key-value maps.
class GenericCsvExcelParser {
  GenericCsvExcelParser();

  /// Splits a single CSV line respecting double-quoted fields with embedded commas/quotes.
  static List<String> splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// Parses CSV file at given path and returns list of row maps.
  Future<Map<String, dynamic>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Selected file does not exist.');
    }

    final content = await file.readAsString();
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.isEmpty) {
      throw const FormatException('File is empty.');
    }

    final headers = splitCsvLine(lines.first).map((h) => h.trim()).toList();
    final List<Map<String, String>> rows = [];

    for (int i = 1; i < lines.length; i++) {
      final cols = splitCsvLine(lines[i]);
      final Map<String, String> rowMap = {};

      for (int c = 0; c < headers.length; c++) {
        final header = headers[c];
        final val = c < cols.length ? cols[c].trim() : '';
        rowMap[header] = val;
      }

      rows.add(rowMap);
    }

    return {
      'headers': headers,
      'rows': rows,
    };
  }
}
