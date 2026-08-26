import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';
import '../../core/export/pdf_report_service.dart';
import 'package:printing/printing.dart';

class SupplierReportScreen extends StatefulWidget {
  final int companyId;
  const SupplierReportScreen({super.key, required this.companyId});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  String _currency = 'Rs.';
  bool _loading = true;

  double get _totalPayable =>
      _suppliers.fold(0.0, (sum, s) => sum + (s['current_balance'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getPayables(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    setState(() {
      _suppliers = rows;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Report (Payables)'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _showExportMenu)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: Colors.purple.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text('Total Payable (aap ne dene wale)',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            '$_currency ${_totalPayable.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _suppliers.isEmpty
                      ? const Center(child: Text('Koi supplier due nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _suppliers.length,
                          itemBuilder: (ctx, i) {
                            final s = _suppliers[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Icon(Icons.local_shipping,
                                      color: Colors.white, size: 18),
                                ),
                                title: Text(s['company_name'] as String),
                                subtitle: Text(s['phone'] as String? ?? ''),
                                trailing: Text(
                                  '$_currency ${(s['current_balance'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }


  Future<void> _showExportMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as CSV'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'csv') _exportCsv();
    if (choice == 'pdf') _exportPdf();
  }

  Future<void> _exportCsv() async {
    await CsvExportService.exportAndShare(
      fileName: 'Supplier_Payables',
      headers: ['Supplier', 'Phone', 'Balance'],
      rows: _suppliers.map((s) => [s['company_name'], s['phone'], s['current_balance']]).toList(),
    );
  }

  Future<void> _exportPdf() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Supplier', 'Phone', 'Balance'];
    final rows = _suppliers
        .map((s) => [
              s['company_name'].toString(),
              s['phone']?.toString() ?? '',
              'Rs. ${s['current_balance']}',
            ])
        .toList();

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'Supplier Payables Report',
      columns: columns,
      rows: rows,
      summary: {
        'Total Payable': '$_currency ${_totalPayable.toStringAsFixed(0)}',
        'Supplier Count': _suppliers.length.toString(),
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'supplier_report.pdf');
  }
}
