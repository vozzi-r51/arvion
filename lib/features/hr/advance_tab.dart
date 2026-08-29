import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';

class AdvanceTab extends StatefulWidget {
  final int companyId;
  final int employeeId;
  const AdvanceTab(
      {super.key, required this.companyId, required this.employeeId});

  @override
  State<AdvanceTab> createState() => _AdvanceTabState();
}

class _AdvanceTabState extends State<AdvanceTab> {
  List<Map<String, dynamic>> _advances = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  double get _totalPending => _advances.fold(
      0.0,
      (sum, a) =>
          sum + ((a['amount'] as num) - (a['recovered_amount'] as num)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getAdvances(widget.employeeId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _advances = rows;
      _company = company;
      _loading = false;
    });
  }

  void _showGiveAdvanceDialog() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Advance Dein'),
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
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
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
                await DBHelper.instance.insertAdvance({
                  'company_id': widget.companyId,
                  'employee_id': widget.employeeId,
                  'amount': amount,
                  'recovered_amount': 0,
                  'advance_date': date.toIso8601String(),
                  'reason': reasonCtrl.text.trim(),
                  'status': 'pending',
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

  void _showRecoverDialog(Map<String, dynamic> advance) {
    final pending =
        (advance['amount'] as num) - (advance['recovered_amount'] as num);
    final amountCtrl = TextEditingController(text: pending.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance Recover Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pending: Rs. ${pending.toStringAsFixed(0)}'),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Recover Amount (Rs.)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              await DBHelper.instance
                  .recoverAdvance(advance['id'] as int, amount);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Recover Karein'),
          ),
        ],
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
            color: Colors.deepOrange.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Total Pending Advance',
                      style: TextStyle(fontSize: 12)),
                  Text(
                    CurrencyFormatter.formatFromCompany(_totalPending, _company, decimalPlaces: 0),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showGiveAdvanceDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Advance Dein'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _advances.isEmpty
              ? const Center(child: Text('Abhi koi advance nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _advances.length,
                  itemBuilder: (ctx, i) {
                    final a = _advances[i];
                    final pending =
                        (a['amount'] as num) - (a['recovered_amount'] as num);
                    final isPending = pending > 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPending
                              ? Colors.deepOrange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            isPending ? Icons.schedule : Icons.check_circle,
                            color: isPending ? Colors.deepOrange : Colors.green,
                            size: 18,
                          ),
                        ),
                        title: Text(
                            CurrencyFormatter.formatFromCompany(a['amount'] as num, _company, decimalPlaces: 0)),
                        subtitle: Text(
                            '${(a['advance_date'] as String).substring(0, 10)}  •  ${a['reason'] ?? ''}\nPending: ${CurrencyFormatter.formatFromCompany(pending, _company, decimalPlaces: 0)}'),
                        isThreeLine: true,
                        trailing: isPending
                            ? TextButton(
                                onPressed: () => _showRecoverDialog(a),
                                child: const Text('Recover'),
                              )
                            : const Text('Cleared',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
