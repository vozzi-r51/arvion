import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/export/pdf_report_service.dart';
import 'package:printing/printing.dart';

class CustomerReportScreen extends StatefulWidget {
  final int companyId;
  const CustomerReportScreen({super.key, required this.companyId});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  List<Map<String, dynamic>> _customers = [];
  String _currency = 'Rs.';
  bool _loading = true;

  double get _totalReceivable =>
      _customers.fold(0.0, (sum, c) => sum + (c['current_balance'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getReceivables(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    setState(() {
      _customers = rows;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Customer Report (Receivables)'),
          actions: [
            IconButton(
                icon: const Icon(Icons.ios_share), onPressed: _showExportMenu)
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: Colors.red.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text('Total Receivable (aap ko milne wale)',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            '$_currency ${_totalReceivable.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _customers.isEmpty
                      ? const Center(child: Text('Koi customer due nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _customers.length,
                          itemBuilder: (ctx, i) {
                            final c = _customers[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    (c['name'] as String).isNotEmpty
                                        ? (c['name'] as String)[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(c['name'] as String),
                                subtitle: Text(c['mobile'] as String? ?? ''),
                                trailing: Text(
                                  '$_currency ${(c['current_balance'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
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
      fileName: 'Customer_Receivables',
      headers: ['Customer', 'Mobile', 'Balance'],
      rows: _customers
          .map((c) => [c['name'], c['mobile'], c['current_balance']])
          .toList(),
    );
  }

  Future<void> _exportPdf() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Customer', 'Mobile', 'Balance'];
    final rows = _customers
        .map((c) => [
              c['name'].toString(),
              c['mobile']?.toString() ?? '',
              CurrencyFormatter.formatFromCompany((c['current_balance'] as num?) ?? 0, company, decimalPlaces: 0),
            ])
        .toList();

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'Customer Receivables Report',
      columns: columns,
      rows: rows,
      summary: {
        'Total Receivable': '$_currency ${_totalReceivable.toStringAsFixed(0)}',
        'Customer Count': _customers.length.toString(),
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'customer_report.pdf');
  }
}
