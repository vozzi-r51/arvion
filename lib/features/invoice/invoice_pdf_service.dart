import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum InvoicePaperSize { a4, thermal80mm }

class InvoicePdfService {
  InvoicePdfService._();

  static Future<Uint8List> generateSaleInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required InvoicePaperSize paperSize,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logo = _loadImage(company['logo_path'] as String?);
    pw.MemoryImage? stamp = _loadImage(company['shop_stamp_path'] as String?);
    pw.MemoryImage? signature =
        _loadImage(company['signature_path'] as String?);

    final pageFormat = paperSize == InvoicePaperSize.a4
        ? PdfPageFormat.a4
        : const PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 4 * PdfPageFormat.mm,
          );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => paperSize == InvoicePaperSize.a4
            ? _buildA4Content(company, sale, items, logo, stamp, signature)
            : _buildThermalContent(company, sale, items, logo, stamp, signature),
      ),
    );

    return doc.save();
  }

  static pw.MemoryImage? _loadImage(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildA4Content(
    Map<String, dynamic> company,
    Map<String, dynamic> sale,
    List<Map<String, dynamic>> items,
    pw.MemoryImage? logo,
    pw.MemoryImage? stamp,
    pw.MemoryImage? signature,
  ) {
    final currency = company['currency_symbol'] ?? 'Rs.';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: PdfColor(0.06, 0.12, 0.18),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  if (logo != null) ...[
                    pw.Image(logo, width: 44, height: 44),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company['name'] as String? ?? 'ARVION',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Smart Business. Simple Control.',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    '# ${sale['invoice_number']}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Bill To',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  sale['customer_name'] as String? ?? 'Walk-in Customer',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text((sale['sale_date'] as String).substring(0, 10),
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  data: sale['invoice_number'] as String,
                  barcode: pw.Barcode.qrCode(),
                  width: 52,
                  height: 52,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        _itemsTable(items),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _totalRow('Subtotal', sale['subtotal'] as num, currency),
              _totalRow('Discount', sale['discount_amount'] as num, currency),
              _totalRow('Tax', (sale['tax_amount'] as num?) ?? 0, currency),
              _totalRow('Total', sale['total_amount'] as num, currency, bold: true),
              _totalRow('Paid', sale['paid_amount'] as num, currency),
              _totalRow('Due', sale['due_amount'] as num, currency),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (stamp != null)
              pw.Column(children: [
                pw.Image(stamp, width: 70, height: 70),
                pw.Text('Shop Stamp', style: const pw.TextStyle(fontSize: 8)),
              ]),
            if (signature != null)
              pw.Column(children: [
                pw.Image(signature, width: 100, height: 50),
                pw.Text('Signature', style: const pw.TextStyle(fontSize: 8)),
              ]),
          ],
        ),
        if ((company['invoice_footer'] as String?)?.isNotEmpty == true) ...[
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              company['invoice_footer'] as String,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildThermalContent(
    Map<String, dynamic> company,
    Map<String, dynamic> sale,
    List<Map<String, dynamic>> items,
    pw.MemoryImage? logo,
    pw.MemoryImage? stamp,
    pw.MemoryImage? signature,
  ) {
    final currency = company['currency_symbol'] ?? 'Rs.';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: PdfColor(0.06, 0.12, 0.18),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 28, height: 28),
                pw.SizedBox(width: 6),
              ],
              pw.Text(
                company['name'] as String? ?? 'ARVION',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        if ((company['address'] as String?)?.isNotEmpty == true)
          pw.Text(company['address'] as String,
              style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
        if ((company['phone'] as String?)?.isNotEmpty == true)
          pw.Text('Ph: ${company['phone']}', style: const pw.TextStyle(fontSize: 7)),
        if ((company['email'] as String?)?.isNotEmpty == true)
          pw.Text('Email: ${company['email']}', style: const pw.TextStyle(fontSize: 7)),
        pw.SizedBox(height: 6),
        pw.Text('--------------------------------'),
        pw.Text('Invoice: ${sale['invoice_number']}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text((sale['sale_date'] as String).substring(0, 16).replaceFirst('T', ' '),
            style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Customer: ${sale['customer_name'] ?? 'Walk-in Customer'}',
            style: const pw.TextStyle(fontSize: 7)),
        pw.Text('--------------------------------'),
        ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${item['product_name']} ${item['packing'] != null ? '(${item['packing']})' : ''}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item['quantity']} x ${item['unit_price']}',
                          style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('Rs. ${(item['total'] as num).toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            )),
        pw.Text('--------------------------------'),
        _thermalRow('Subtotal', sale['subtotal'] as num, currency),
        _thermalRow('Discount', sale['discount_amount'] as num, currency),
        _thermalRow('Tax', (sale['tax_amount'] as num?) ?? 0, currency),
        _thermalRow('Total', sale['total_amount'] as num, currency, bold: true),
        _thermalRow('Paid', sale['paid_amount'] as num, currency),
        _thermalRow('Due', sale['due_amount'] as num, currency),
        pw.SizedBox(height: 10),
        if (stamp != null || signature != null) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              if (stamp != null)
                pw.Column(children: [
                  pw.Image(stamp, width: 40, height: 40),
                  pw.Text('Stamp', style: const pw.TextStyle(fontSize: 6)),
                ]),
              if (signature != null)
                pw.Column(children: [
                  pw.Image(signature, width: 60, height: 30),
                  pw.Text('Signature', style: const pw.TextStyle(fontSize: 6)),
                ]),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
        pw.BarcodeWidget(
          data: sale['invoice_number'] as String,
          barcode: pw.Barcode.qrCode(),
          width: 60,
          height: 60,
        ),
        pw.SizedBox(height: 8),
        if ((company['invoice_footer'] as String?)?.isNotEmpty == true)
          pw.Text(company['invoice_footer'] as String,
              style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _itemsTable(List<Map<String, dynamic>> items) {
    return pw.Column(
      children: [
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 1, child: pw.Text('Pack', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
        ),
        ...items.map((item) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(item['product_name'] as String)),
                  pw.Expanded(flex: 1, child: pw.Text(item['packing']?.toString() ?? '-')),
                  pw.Expanded(flex: 1, child: pw.Text('${item['quantity']}')),
                  pw.Expanded(flex: 2, child: pw.Text('${item['unit_price']}')),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Rs. ${(item['total'] as num).toStringAsFixed(0)}')),
                ],
              ),
            )),
      ],
    );
  }

  static pw.Widget _totalRow(String label, num value, String currency, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)
        : const pw.TextStyle(fontSize: 11);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: style)),
          pw.SizedBox(
              width: 80,
              child: pw.Text('$currency ${value.toStringAsFixed(0)}',
                  style: style, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _thermalRow(String label, num value, String currency, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
        : const pw.TextStyle(fontSize: 9);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('$currency ${value.toStringAsFixed(0)}', style: style),
      ],
    );
  }
}
