import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/fiscal_year_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class FiscalYearClosingScreen extends StatefulWidget {
  final int companyId;
  const FiscalYearClosingScreen({super.key, required this.companyId});

  @override
  State<FiscalYearClosingScreen> createState() =>
      _FiscalYearClosingScreenState();
}

class _FiscalYearClosingScreenState extends State<FiscalYearClosingScreen> {
  List<Map<String, dynamic>> _closings = [];
  bool _loading = true;
  int _selectedYear = DateTime.now().year - 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = sl<FiscalYearRepository>();
    final list = await repo.listClosings(widget.companyId);
    setState(() {
      _closings = list;
      _loading = false;
    });
  }

  Future<void> _confirmCloseFiscalYear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fiscal Year $_selectedYear Close Karein?'),
        content: Text(
          'Fiscal Year $_selectedYear (01 Jan $_selectedYear - 31 Dec $_selectedYear) ke tamam Revenue aur Expense accounts close ho kar Net Profit Retained Earnings mein transfer ho jayega aur Lock Date update ho jayegi.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Fiscal Year'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await sl<FiscalYearRepository>().closeFiscalYear(
        companyId: widget.companyId,
        fiscalYear: _selectedYear,
        startDate: '$_selectedYear-01-01',
        endDate: '$_selectedYear-12-31',
        closedBy: 'Owner',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Fiscal Year $_selectedYear kamyabi se close ho gaya! Net Profit: Rs. ${(res['netProfit'] as double).toStringAsFixed(0)}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiscal Year-End Closing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_clock, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text('Year-End Closing Process',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Saal ke aakhir par Net Profit/Loss ko Revenue aur Expense accounts se Retained Earnings account mein transfer karein aur fiscal year lock karein.',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              DropdownButton<int>(
                                value: _selectedYear,
                                items: [2024, 2025, 2026]
                                    .map((y) => DropdownMenuItem(
                                        value: y,
                                        child: Text('Fiscal Year $y')))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setState(() => _selectedYear = v);
                                },
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _confirmCloseFiscalYear,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Close Year'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Past Fiscal Year Closings',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _closings.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.history,
                            title: 'Pehle Koi Fiscal Year Close Nahi Hua',
                            message:
                                'Pichle fiscal saal ko close karne ke liye uper diye gaye button par click karein.',
                          )
                        : ListView.builder(
                            itemCount: _closings.length,
                            itemBuilder: (ctx, i) {
                              final c = _closings[i];
                              final net = (c['net_profit'] as num).toDouble();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: net >= 0
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                        net >= 0
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: net >= 0
                                            ? Colors.green
                                            : Colors.red),
                                  ),
                                  title: Text('Fiscal Year ${c['fiscal_year']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      'Closed on ${c['closed_at'].toString().substring(0, 10)} by ${c['closed_by']}'),
                                  trailing: Text(
                                      'Net: Rs. ${net.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: net >= 0
                                              ? Colors.green
                                              : Colors.red)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
