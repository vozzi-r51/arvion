import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';
import '../../core/export/pdf_report_service.dart';
import 'date_range_bar.dart';
import 'package:printing/printing.dart';

class ExpenseReportScreen extends StatefulWidget {
  final int companyId;
  const ExpenseReportScreen({super.key, required this.companyId});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _breakdown = [];
  bool _loading = true;

  double get _total =>
      _breakdown.fold(0.0, (sum, e) => sum + (e['total'] as num));

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance
        .getExpenseCategoryBreakdown(widget.companyId, _iso(_from), _iso(_to));
    setState(() {
      _breakdown = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Report'), actions: [
        IconButton(
            icon: const Icon(Icons.ios_share), onPressed: _showExportMenu)
      ]),
      body: Column(
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            onFromChanged: (d) {
              setState(() => _from = d);
              _load();
            },
            onToChanged: (d) {
              setState(() => _to = d);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              color: Colors.orange.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Text('Total Expenses',
                        style: TextStyle(fontSize: 13)),
                    Text(
                      'Rs. ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _breakdown.isEmpty
                    ? const Center(
                        child: Text('Is range mein koi expense nahi hai'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _breakdown.length,
                        itemBuilder: (ctx, i) {
                          final e = _breakdown[i];
                          final amount = (e['total'] as num).toDouble();
                          final percent =
                              _total > 0 ? (amount / _total * 100) : 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(e['category'] as String),
                              subtitle: Text(
                                  '${percent.toStringAsFixed(0)}% of total'),
                              trailing: Text(
                                'Rs. ${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
      fileName: 'Expense_Report',
      headers: ['Category', 'Total'],
      rows: _breakdown.map((e) => [e['category'], e['total']]).toList(),
    );
  }

  Future<void> _exportPdf() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Category', 'Total Amount'];
    final rows = _breakdown
        .map((e) => [
              e['category'].toString(),
              'Rs. ${e['total']}',
            ])
        .toList();

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'Expense Breakdown Report',
      columns: columns,
      rows: rows,
      summary: {
        'Total Expenses': 'Rs. ${_total.toStringAsFixed(0)}',
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'expense_report.pdf');
  }
}
