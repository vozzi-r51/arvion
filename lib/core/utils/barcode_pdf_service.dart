import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'currency_formatter.dart';

class BarcodePdfService {
  BarcodePdfService._();

  static Future<void> printBarcodeLabels({
    required List<Map<String, dynamic>> products,
    Map<String, dynamic>? company,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return [
            pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 0.6,
              children: products.map((p) {
                final barcode = p['barcode'] as String? ??
                    p['product_code'] as String? ??
                    'N/A';
                final name = p['name'] as String? ?? 'Unknown';
                final price = p['retail_price']?.toString() ?? '0';

                return pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(name,
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: barcode,
                        width: 100,
                        height: 40,
                        drawText: true,
                        textStyle: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(CurrencyFormatter.formatFromCompany(double.tryParse(price) ?? 0, company, decimalPlaces: 0),
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'barcode_labels.pdf',
    );
  }
}
