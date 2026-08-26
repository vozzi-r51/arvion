import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportService {
  PdfReportService._();

  static Future<Uint8List> generateReport({
    required Map<String, dynamic> company,
    required String title,
    required List<String> columns,
    required List<dynamic> rows,
    required Map<String, String> summary,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildHeader(company, title),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildTable(columns, rows),
          pw.SizedBox(height: 20),
          _buildSummary(summary),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> company, String title) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company['name'] ?? 'ARVION',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                if (company['address'] != null)
                  pw.Text(company['address'], style: const pw.TextStyle(fontSize: 9)),
                if (company['phone'] != null)
                  pw.Text('Ph: ${company['phone']}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Report Date: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: PdfColors.blue900),
        pw.SizedBox(height: 15),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    );
  }

  static pw.Widget _buildTable(List<String> columns, List<dynamic> rows) {
    return pw.TableHelper.fromTextArray(
      headers: columns,
      data: rows.map((r) => (r as List).map((c) => c.toString()).toList()).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _buildSummary(Map<String, String> summary) {
    if (summary.isEmpty) return pw.SizedBox();
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: summary.entries.map((e) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('${e.key}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
