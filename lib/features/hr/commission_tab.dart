import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';

class CommissionTab extends StatefulWidget {
  final int companyId;
  final int employeeId;
  const CommissionTab(
      {super.key, required this.companyId, required this.employeeId});

  @override
  State<CommissionTab> createState() => _CommissionTabState();
}

class _CommissionTabState extends State<CommissionTab> {
  List<Map<String, dynamic>> _commissions = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  double get _total =>
      _commissions.fold(0.0, (sum, c) => sum + (c['amount'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getCommissions(widget.employeeId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _commissions = rows;
      _company = company;
      _loading = false;
    });
  }

  void _showAddDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Commission Add Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Amount (Rs.) *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text('Date: ${date.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (jaise: sale reference)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                await DBHelper.instance.insertCommission({
                  'company_id': widget.companyId,
                  'employee_id': widget.employeeId,
                  'amount': amount,
                  'commission_date': date.toIso8601String(),
                  'notes': notesCtrl.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.purple.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Total Commission',
                      style: TextStyle(fontSize: 12)),
                  Text(
                    CurrencyFormatter.formatFromCompany(_total, _company, decimalPlaces: 0),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Commission Add Karein'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _commissions.isEmpty
              ? const Center(child: Text('Abhi koi commission entry nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _commissions.length,
                  itemBuilder: (ctx, i) {
                    final c = _commissions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Icon(Icons.percent,
                              color: Colors.white, size: 18),
                        ),
                        title: Text(
                            CurrencyFormatter.formatFromCompany(c['amount'] as num, _company, decimalPlaces: 0)),
                        subtitle: Text(
                            '${(c['commission_date'] as String).substring(0, 10)}  •  ${c['notes'] ?? ''}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
