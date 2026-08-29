import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import 'committee_members_tab.dart';
import 'committee_installments_tab.dart';
import 'committee_draws_tab.dart';

class CommitteeDetailScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic> committee;
  const CommitteeDetailScreen(
      {super.key, required this.companyId, required this.committee});

  @override
  State<CommitteeDetailScreen> createState() => _CommitteeDetailScreenState();
}

class _CommitteeDetailScreenState extends State<CommitteeDetailScreen> {
  double _totalCollected = 0;
  double _totalDrawn = 0;
  Map<String, dynamic>? _company;
  bool _loading = true;

  int get _committeeId => widget.committee['id'] as int;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final installments =
        await DBHelper.instance.getCommitteeInstallments(_committeeId);
    final draws = await DBHelper.instance.getCommitteeDraws(_committeeId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _totalCollected =
          installments.fold(0.0, (sum, i) => sum + (i['amount'] as num));
      _totalDrawn = draws.fold(0.0, (sum, d) => sum + (d['amount'] as num));
      _company = company;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final committee = widget.committee;
    final defaultAmount = (committee['monthly_installment'] as num).toDouble() *
        (committee['total_members'] as num).toDouble();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(committee['name'] as String),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Summary Refresh Karein',
              onPressed: _loadSummary,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Members'),
              Tab(text: 'Installments'),
              Tab(text: 'Draws'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (!_loading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryItem('Collected', _totalCollected, Colors.green),
                    _summaryItem('Drawn', _totalDrawn, Colors.red),
                    _summaryItem(
                        'Balance', _totalCollected - _totalDrawn, Colors.blue),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  CommitteeMembersTab(
                      companyId: widget.companyId, committeeId: _committeeId),
                  CommitteeInstallmentsTab(
                    companyId: widget.companyId,
                    committeeId: _committeeId,
                    defaultAmount:
                        (committee['monthly_installment'] as num).toDouble(),
                  ),
                  CommitteeDrawsTab(
                    companyId: widget.companyId,
                    committeeId: _committeeId,
                    defaultAmount: defaultAmount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 2),
        Text(CurrencyFormatter.formatFromCompany(value, _company, decimalPlaces: 0),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }
}
