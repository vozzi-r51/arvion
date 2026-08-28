import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/pdf_report_service.dart';
import 'date_range_bar.dart';
import 'package:printing/printing.dart';

class TaxReportScreen extends StatefulWidget {
  final int companyId;
  const TaxReportScreen({super.key, required this.companyId});

  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  Map<String, double>? _data;
  String _currency = 'Rs.';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await DBHelper.instance.getTaxSummary(
      widget.companyId,
      _from.toIso8601String().substring(0, 10),
      _to.toIso8601String().substring(0, 10),
    );
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    setState(() {
      _data = res;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_data == null) return;
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Description', 'Amount (Rs.)'];
    final rows = [
      ['Total Sales (Inclusive)', _data!['total_sales']!.toStringAsFixed(2)],
      [
        'Tax Collected (Output GST)',
        _data!['tax_collected']!.toStringAsFixed(2)
      ],
      [
        'Total Purchases (Inclusive)',
        _data!['total_purchases']!.toStringAsFixed(2)
      ],
      ['Tax Paid (Input GST)', _data!['tax_paid']!.toStringAsFixed(2)],
    ];

    final netPayable = _data!['tax_collected']! - _data!['tax_paid']!;

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'GST / Tax Summary Report',
      columns: columns,
      rows: rows,
      summary: {
        'Net Tax Payable': '$_currency ${netPayable.toStringAsFixed(2)}',
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'tax_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final netPayable =
        (_data?['tax_collected'] ?? 0) - (_data?['tax_paid'] ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST / Tax Summary'),
        actions: [
          IconButton(
              onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf)),
        ],
      ),
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
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statCard('Total Sales', _data!['total_sales']!, Colors.blue),
                  _statCard('Tax Collected (Output)', _data!['tax_collected']!,
                      Colors.teal),
                  const Divider(height: 32),
                  _statCard('Total Purchases', _data!['total_purchases']!,
                      Colors.orange),
                  _statCard('Tax Paid (Input)', _data!['tax_paid']!,
                      Colors.deepOrange),
                  const Divider(height: 32),
                  Card(
                    color: netPayable >= 0
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Net Tax Payable',
                              style: TextStyle(fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            '$_currency ${netPayable.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  netPayable >= 0 ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            netPayable >= 0
                                ? 'Payable to Govt'
                                : 'Input Credit Available',
                            style: TextStyle(
                                fontSize: 11,
                                color: netPayable >= 0
                                    ? Colors.red
                                    : Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, double value, Color color) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(
          '$_currency ${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 15),
        ),
      ),
    );
  }
}
