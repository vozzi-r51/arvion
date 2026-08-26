import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';
import '../../core/export/pdf_report_service.dart';
import 'date_range_bar.dart';
import 'package:printing/printing.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/providers/terminology_provider.dart';
import '../sales/sale_detail_screen.dart';

class SalesReportScreen extends StatefulWidget {
  final int companyId;
  const SalesReportScreen({super.key, required this.companyId});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _sales = [];
  String _currency = 'Rs.';
  bool _loading = true;

  double get _totalSales =>
      _sales.fold(0.0, (sum, s) => sum + (s['total_amount'] as num));
  double get _totalDue =>
      _sales.fold(0.0, (sum, s) => sum + (s['due_amount'] as num));

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance
        .getSalesBetween(widget.companyId, _iso(_from), _iso(_to));
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    setState(() {
      _sales = rows;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final term = context.watch<TerminologyProvider>();
    final saleLabel = term.get('sale');

    return Scaffold(
      appBar: AppBar(title: Text('$saleLabel Report'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _showExportMenu)]),
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
          Expanded(
            child: _loading
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => AppSkeleton.listTile(),
                  )
                : _sales.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Koi $saleLabel nahi mili',
                        message: 'Is range mein abhi tak koi $saleLabel record nahi hui.',
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.l),
                            child: Row(
                              children: [
                                Expanded(
                                    child: _summaryCard(
                                        'Total ${saleLabel}s', _totalSales, Colors.teal, _currency)),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                    child: _summaryCard(
                                        'Total Due', _totalDue, Colors.red, _currency)),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                    child: _summaryCard(
                                        'Invoices', _sales.length.toDouble(), Colors.blue, _currency,
                                        isCount: true)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                              itemCount: _sales.length,
                              itemBuilder: (ctx, i) {
                                final s = _sales[i];
                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: AppSpacing.s),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.medium,
                                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      '$saleLabel ${s['invoice_number']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${(s['sale_date'] as String).substring(0, 10)}  •  ${s['customer_name'] ?? 'Walk-in'}',
                                    ),
                                    trailing: Text(
                                      '$_currency ${(s['total_amount'] as num).toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SaleDetailScreen(
                                          sale: s,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double value, Color color, String currency, {bool isCount = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              isCount ? value.toStringAsFixed(0) : '$currency ${value.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ],
        ),
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
      fileName: 'Sales_Report',
      headers: ['Invoice', 'Date', 'Customer', 'Total', 'Due'],
      rows: _sales
          .map((s) => [s['invoice_number'], (s['sale_date'] as String).substring(0, 10),
                s['customer_name'] ?? 'Walk-in', s['total_amount'], s['due_amount']])
          .toList(),
    );
  }

  Future<void> _exportPdf() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Invoice', 'Date', 'Customer', 'Total'];
    final rows = _sales.map((s) => [
      s['invoice_number'].toString(),
      (s['sale_date'] as String).substring(0, 10),
      s['customer_name'] ?? 'Walk-in',
      '$_currency ${s['total_amount']}',
    ]).toList();

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'Sales Report',
      columns: columns,
      rows: rows,
      summary: {
        'Total Sales': '$_currency ${_totalSales.toStringAsFixed(0)}',
        'Total Due': '$_currency ${_totalDue.toStringAsFixed(0)}',
        'Invoice Count': _sales.length.toString(),
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'sales_report.pdf');
  }
}
