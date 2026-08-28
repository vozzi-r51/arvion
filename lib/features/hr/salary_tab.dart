import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class SalaryTab extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic> employee;
  const SalaryTab({super.key, required this.companyId, required this.employee});

  @override
  State<SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<SalaryTab> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  int get _employeeId => widget.employee['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getSalaryPayments(_employeeId);
    setState(() {
      _payments = rows;
      _loading = false;
    });
  }

  void _showPaySalaryDialog() {
    final defaultSalary = (widget.employee['monthly_salary'] as num).toDouble();
    final amountCtrl =
        TextEditingController(text: defaultSalary.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();
    final now = DateTime.now();
    String month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthCtrl = TextEditingController(text: month);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Salary Pay Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Month (yyyy-mm)', hintText: 'jaise: 2026-08'),
                ),
                const SizedBox(height: 8),
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
                  title: Text(
                      'Date: ${paymentDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setDialogState(() => paymentDate = picked);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
                await DBHelper.instance.insertSalaryPayment({
                  'company_id': widget.companyId,
                  'employee_id': _employeeId,
                  'month': monthCtrl.text.trim(),
                  'amount': amount,
                  'payment_date': paymentDate.toIso8601String(),
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
            color: Colors.teal.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Monthly Salary', style: TextStyle(fontSize: 12)),
                  Text(
                    'Rs. ${(widget.employee['monthly_salary'] as num).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showPaySalaryDialog,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Salary Pay Karein'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _payments.isEmpty
              ? const Center(child: Text('Abhi koi salary payment nahi hui'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _payments.length,
                  itemBuilder: (ctx, i) {
                    final p = _payments[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.payments,
                              color: Colors.white, size: 18),
                        ),
                        title: Text('Month: ${p['month']}'),
                        subtitle: Text(
                            (p['payment_date'] as String).substring(0, 10)),
                        trailing: Text(
                          'Rs. ${(p['amount'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
