import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class BudgetVsActualScreen extends StatefulWidget {
  final int companyId;
  const BudgetVsActualScreen({super.key, required this.companyId});

  @override
  State<BudgetVsActualScreen> createState() => _BudgetVsActualScreenState();
}

class _BudgetVsActualScreenState extends State<BudgetVsActualScreen> {
  String _selectedMonth = DateTime.now().toIso8601String().substring(0, 7); // "2026-08"
  List<Map<String, dynamic>> _report = [];
  bool _loading = true;

  static const _defaultCategories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Marketing',
    'Office Supplies',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = sl<BudgetRepository>();
    final list = await repo.getBudgetVsActual(widget.companyId, _selectedMonth);
    setState(() {
      _report = list;
      _loading = false;
    });
  }

  void _showSetBudgetDialog(String category, double currentBudget) {
    final amountCtrl = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Monthly Budget: $category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_selectedMonth ke liye budget set karein:', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Budgeted Amount (Rs.) *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              await sl<BudgetRepository>().setBudget(
                companyId: widget.companyId,
                periodMonth: _selectedMonth,
                category: category,
                budgetedAmount: amount,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget vs Actual Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Month: $_selectedMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Categories Budget Set Karein'),
                  onPressed: () {
                    for (final cat in _defaultCategories) {
                      final match = _report.firstWhere((r) => r['category'] == cat, orElse: () => {'budgeted': 0.0});
                      _showSetBudgetDialog(cat, (match['budgeted'] as num).toDouble());
                      break;
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report.isEmpty
                    ? AppEmptyState(
                        icon: Icons.pie_chart_outline,
                        title: 'Koi Budget Set Nahi',
                        message: 'Apni expense categories ke monthly budgets set karein taake variance track ho sake.',
                        actionLabel: 'Set Monthly Budget',
                        onAction: () => _showSetBudgetDialog('Rent', 0.0),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _report.length,
                        itemBuilder: (ctx, i) {
                          final item = _report[i];
                          final category = item['category'] as String;
                          final budgeted = (item['budgeted'] as num).toDouble();
                          final actual = (item['actual'] as num).toDouble();
                          final percent = (item['percentUsed'] as num).toDouble();
                          final isOver = item['isOverBudget'] as bool;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _showSetBudgetDialog(category, budgeted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Budget: Rs. ${budgeted.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text('Actual: Rs. ${actual.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isOver ? Colors.red : Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: (percent / 100.0).clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey.shade200,
                                    color: isOver ? Colors.red : (percent >= 80 ? Colors.orange : Colors.green),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOver ? '⚠️ Over Budget by Rs. ${(actual - budgeted).toStringAsFixed(0)} (${percent.toStringAsFixed(0)}%)' : '${percent.toStringAsFixed(0)}% utilized',
                                    style: TextStyle(fontSize: 11, fontWeight: isOver ? FontWeight.bold : FontWeight.normal, color: isOver ? Colors.red : Colors.grey.shade700),
                                  ),
                                ],
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
}
