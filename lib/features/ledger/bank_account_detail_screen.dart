import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class BankAccountDetailScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  final int companyId;
  const BankAccountDetailScreen(
      {super.key, required this.account, required this.companyId});

  @override
  State<BankAccountDetailScreen> createState() => _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState extends State<BankAccountDetailScreen> {
  List<Map<String, dynamic>> _transactions = [];
  double _balance = 0;
  bool _loading = true;

  int get _accountId => widget.account['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getBankTransactions(_accountId);
    final accounts = await DBHelper.instance.getBankAccounts(widget.companyId);
    final match = accounts.where((a) => a['id'] == _accountId).toList();
    setState(() {
      _transactions = rows;
      _balance = match.isNotEmpty
          ? (match.first['current_balance'] as num).toDouble()
          : (widget.account['current_balance'] as num).toDouble();
      _loading = false;
    });
  }

  void _showForm() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'deposit';
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bank Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Deposit'),
                        value: 'deposit',
                        groupValue: type,
                        onChanged: (v) => setDialogState(() => type = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Withdraw'),
                        value: 'withdrawal',
                        groupValue: type,
                        onChanged: (v) => setDialogState(() => type = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (Rs.) *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${date.toIso8601String().substring(0, 10)}'),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                await DBHelper.instance.insertBankTransaction({
                  'company_id': widget.companyId,
                  'bank_account_id': _accountId,
                  'type': type,
                  'amount': amount,
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
        title: const Text('Transaction Delete Karein?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteBankTransaction(t['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.account['bank_name'] as String)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  child: Column(
                    children: [
                      const Text('Current Balance', style: TextStyle(fontSize: 13)),
                      Text(
                        'Rs. ${_balance.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('Abhi koi transaction nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _transactions.length,
                          itemBuilder: (ctx, i) {
                            final t = _transactions[i];
                            final isDeposit = t['type'] == 'deposit';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isDeposit ? Colors.green : Colors.red,
                                ),
                                title: Text(isDeposit ? 'Deposit' : 'Withdrawal'),
                                subtitle: Text(
                                    '${(t['transaction_date'] as String).substring(0, 10)}  •  ${t['description'] ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${(t['amount'] as num).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDeposit ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
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
}
