import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Lightweight CSV writer + share helper. CSV opens directly in Excel /
/// Google Sheets, so this covers "Export to Excel" without pulling in a
/// full xlsx-writing package (lower risk, same practical result for the
/// user — open the file, it's a spreadsheet).
class CsvExportService {
  CsvExportService._();

  static String _escape(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<void> exportAndShare({
    required String fileName,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escape).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(tempDir.path, '$fileName.csv');
    final file = File(path);
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(path)], text: fileName);
  }
}
