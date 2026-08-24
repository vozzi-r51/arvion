import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class BalanceSheetTab extends StatefulWidget {
  final int companyId;
  const BalanceSheetTab({super.key, required this.companyId});

  @override
  State<BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends State<BalanceSheetTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await DBHelper.instance.ensureChartOfAccounts(widget.companyId);
    final rows = await DBHelper.instance.getTrialBalance(widget.companyId);
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  double _balance(Map<String, dynamic> r, {required bool normalDebit}) {
    final debit = (r['total_debit'] as num).toDouble();
    final credit = (r['total_credit'] as num).toDouble();
    return normalDebit ? debit - credit : credit - debit;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final assets = _rows.where((r) => r['type'] == 'asset').toList();
    final liabilities = _rows.where((r) => r['type'] == 'liability').toList();
    final equity = _rows.where((r) => r['type'] == 'equity').toList();
    final income = _rows.where((r) => r['type'] == 'income').toList();
    final expense = _rows.where((r) => r['type'] == 'expense').toList();

    final totalAssets = assets.fold(0.0, (s, r) => s + _balance(r, normalDebit: true));
    final totalLiabilities = liabilities.fold(0.0, (s, r) => s + _balance(r, normalDebit: false));
    final totalEquity = equity.fold(0.0, (s, r) => s + _balance(r, normalDebit: false));
    final netIncome = income.fold(0.0, (s, r) => s + _balance(r, normalDebit: false)) -
        expense.fold(0.0, (s, r) => s + _balance(r, normalDebit: true));
    final totalEquityWithIncome = totalEquity + netIncome;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Assets', assets, true, Colors.blue),
          _totalRow('Total Assets', totalAssets, bold: true),
          const SizedBox(height: 20),
          _section('Liabilities', liabilities, false, Colors.red),
          _totalRow('Total Liabilities', totalLiabilities, bold: true),
          const SizedBox(height: 20),
          _section('Equity', equity, false, Colors.purple),
          _totalRow('Net Income (is period ka)', netIncome),
          _totalRow('Total Equity', totalEquityWithIncome, bold: true),
          const Divider(height: 32, thickness: 2),
          _totalRow('Liabilities + Equity', totalLiabilities + totalEquityWithIncome, bold: true),
          const SizedBox(height: 8),
          Text(
            (totalAssets - (totalLiabilities + totalEquityWithIncome)).abs() < 0.01
                ? 'Balance Sheet balanced hai ✓'
                : 'Farq: Rs. ${(totalAssets - (totalLiabilities + totalEquityWithIncome)).toStringAsFixed(0)}',
            style: TextStyle(
              color: (totalAssets - (totalLiabilities + totalEquityWithIncome)).abs() < 0.01
                  ? Colors.green
                  : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Note: Ye sheet Journal entries se banti hai. Ab Sales, Purchase aur Payments khud-ba-khud is mein post ho rahi hain.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> rows, bool normalDebit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r['name'] as String),
                  Text(_balance(r, normalDebit: normalDebit).toStringAsFixed(0)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        : const TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(0), style: style),
        ],
      ),
    );
  }
}
