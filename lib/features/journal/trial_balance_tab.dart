import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class TrialBalanceTab extends StatefulWidget {
  final int companyId;
  const TrialBalanceTab({super.key, required this.companyId});

  @override
  State<TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends State<TrialBalanceTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  double get _totalDebit => _rows.fold(0.0, (s, r) => s + (r['total_debit'] as num));
  double get _totalCredit => _rows.fold(0.0, (s, r) => s + (r['total_credit'] as num));

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final balanced = (_totalDebit - _totalCredit).abs() < 0.01;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Expanded(flex: 3, child: Text('Account', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Debit', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          ..._rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(r['name'] as String)),
                    Expanded(child: Text((r['total_debit'] as num).toStringAsFixed(0))),
                    Expanded(child: Text((r['total_credit'] as num).toStringAsFixed(0))),
                  ],
                ),
              )),
          const Divider(thickness: 2),
          Row(
            children: [
              const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text(_totalDebit.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text(_totalCredit.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            balanced ? 'Trial Balance balanced hai ✓' : 'Balanced nahi hai — check karein',
            style: TextStyle(color: balanced ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
