import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/pdf_report_service.dart';
import 'date_range_bar.dart';
import 'package:printing/printing.dart';

class ProfitReportScreen extends StatefulWidget {
  final int companyId;
  const ProfitReportScreen({super.key, required this.companyId});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = true;

  double _revenue = 0;
  double _grossProfit = 0;
  double _expenses = 0;
  double _otherIncome = 0;
  String _currency = 'Rs.';

  double get _netProfit => _grossProfit + _otherIncome - _expenses;

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final from = _iso(_from);
    final to = _iso(_to);

    final sales = await DBHelper.instance.getSalesBetween(widget.companyId, from, to);
    final revenue =
        sales.fold(0.0, (sum, s) => sum + (s['total_amount'] as num));
    final grossProfit =
        await DBHelper.instance.getProfitBetween(widget.companyId, from, to);
    final expenseRows =
        await DBHelper.instance.getExpensesBetween(widget.companyId, from, to);
    final expenses =
        expenseRows.fold(0.0, (sum, e) => sum + (e['amount'] as num));
    final incomeRows =
        await DBHelper.instance.getIncomeBetween(widget.companyId, from, to);
    final otherIncome =
        incomeRows.fold(0.0, (sum, e) => sum + (e['amount'] as num));

    final company = await DBHelper.instance.getCompanyById(widget.companyId);

    setState(() {
      _revenue = revenue;
      _grossProfit = grossProfit;
      _expenses = expenses;
      _otherIncome = otherIncome;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss'), actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPdf)]),
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
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _row('Revenue (Sales)', _revenue),
                      _row('Gross Profit (Sales - Cost)', _grossProfit),
                      _row('Other Income', _otherIncome),
                      _row('Expenses', -_expenses),
                      const Divider(height: 32),
                      _row('Net Profit', _netProfit, bold: true),
                      const SizedBox(height: 16),
                      Card(
                        color: _netProfit >= 0
                            ? Colors.green.withOpacity(0.08)
                            : Colors.red.withOpacity(0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                _netProfit >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 36,
                                color: _netProfit >= 0 ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_currency ${_netProfit.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: _netProfit >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(_netProfit >= 0 ? 'Net Profit' : 'Net Loss'),
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

  Widget _row(String label, double value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
        : const TextStyle(fontSize: 15);
    final color = value < 0 ? Colors.red : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$_currency ${value.toStringAsFixed(0)}', style: style.copyWith(color: color)),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company == null) return;

    final columns = ['Description', 'Amount (Rs.)'];
    final rows = [
      ['Revenue (Sales)', _revenue.toStringAsFixed(2)],
      ['Gross Profit', _grossProfit.toStringAsFixed(2)],
      ['Other Income', _otherIncome.toStringAsFixed(2)],
      ['Expenses', (-_expenses).toStringAsFixed(2)],
    ];

    final pdfBytes = await PdfReportService.generateReport(
      company: company,
      title: 'Profit & Loss Report',
      columns: columns,
      rows: rows,
      summary: {
        'Net Profit/Loss': '$_currency ${_netProfit.toStringAsFixed(2)}',
      },
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'profit_loss_report.pdf');
  }
}
