import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class CashBookScreen extends StatefulWidget {
  final int companyId;
  const CashBookScreen({super.key, required this.companyId});

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  double get _cashIn => _transactions
      .where((t) => t['type'] == 'in')
      .fold(0.0, (sum, t) => sum + (t['amount'] as num));

  double get _cashOut => _transactions
      .where((t) => t['type'] == 'out')
      .fold(0.0, (sum, t) => sum + (t['amount'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getCashTransactions(widget.companyId);
    setState(() {
      _transactions = rows;
      _loading = false;
    });
  }

  void _showForm() {
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'in';
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cash Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cash In'),
                        value: 'in',
                        groupValue: type,
                        onChanged: (v) => setDialogState(() => type = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cash Out'),
                        value: 'out',
                        groupValue: type,
                        onChanged: (v) => setDialogState(() => type = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Amount (Rs.) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
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
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
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
                await DBHelper.instance.insertCashTransaction({
                  'company_id': widget.companyId,
                  'type': type,
                  'amount': amount,
                  'category': categoryCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'transaction_date': date.toIso8601String(),
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

  Future<void> _confirmDelete(Map<String, dynamic> t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entry Delete Karein?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteCashTransaction(t['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Book')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _totalCard('Cash In', _cashIn, Colors.green),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _totalCard('Cash Out', _cashOut, Colors.red),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _totalCard(
                            'Net',
                            _cashIn - _cashOut,
                            (_cashIn - _cashOut) >= 0
                                ? Colors.blue
                                : Colors.red),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('Abhi koi entry nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _transactions.length,
                          itemBuilder: (ctx, i) {
                            final t = _transactions[i];
                            final isIn = t['type'] == 'in';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isIn
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isIn ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                    (t['category'] as String?)?.isNotEmpty ==
                                            true
                                        ? t['category'] as String
                                        : (isIn ? 'Cash In' : 'Cash Out')),
                                subtitle: Text(
                                    '${(t['transaction_date'] as String).substring(0, 10)}  •  ${t['description'] ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${(t['amount'] as num).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isIn ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      onPressed: () => _confirmDelete(t),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _totalCard(String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
