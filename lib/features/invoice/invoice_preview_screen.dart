import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'invoice_pdf_service.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> company;
  final Map<String, dynamic> sale;
  final List<Map<String, dynamic>> items;

  const InvoicePreviewScreen({
    super.key,
    required this.company,
    required this.sale,
    required this.items,
  });

  Future<void> _saveToDownloads(BuildContext context) async {
    try {
      final pdfBytes = await InvoicePdfService.generateSaleInvoice(
        company: company,
        sale: sale,
        items: items,
        paperSize: InvoicePaperSize.a4,
      );

      // On Android, we try to save to the Downloads folder
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) throw Exception("Downloads folder nahi mila");

      final fileName =
          'Invoice_${sale['invoice_number']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = p.join(downloadsDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Downloads mein save ho gayi: $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save fail ho gaya: $e')),
        );
      }
    }
  }

  Future<void> _shareDirect(String platform) async {
    final pdfBytes = await InvoicePdfService.generateSaleInvoice(
      company: company,
      sale: sale,
      items: items,
      paperSize: InvoicePaperSize.thermal80mm,
    );

    final temp = await getTemporaryDirectory();
    final path = p.join(temp.path, 'Invoice_${sale['invoice_number']}.pdf');
    await File(path).writeAsBytes(pdfBytes);

    await Share.shareXFiles([XFile(path)],
        text: 'Invoice # ${sale['invoice_number']} from ${company['name']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save to Downloads',
            onPressed: () => _saveToDownloads(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => _shareDirect('all'),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => InvoicePdfService.generateSaleInvoice(
          company: company,
          sale: sale,
          items: items,
          paperSize: format == PdfPageFormat.a4
              ? InvoicePaperSize.a4
              : InvoicePaperSize.thermal80mm,
        ),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
