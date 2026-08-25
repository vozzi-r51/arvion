import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../shell/main_shell.dart';

class ExpenseListScreen extends StatefulWidget {
  final int companyId;
  const ExpenseListScreen({super.key, required this.companyId});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  static const _categories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Transport',
    'Maintenance',
    'Miscellaneous',
    'Other',
  ];

  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getExpenses(widget.companyId);
    setState(() {
      _expenses = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final amountCtrl =
        TextEditingController(text: existing != null ? '${existing['amount']}' : '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final customCategoryCtrl = TextEditingController();
    String category = existing?['category'] as String? ?? _categories.first;
    DateTime date = existing != null
        ? DateTime.tryParse(existing['expense_date'] as String) ?? DateTime.now()
        : DateTime.now();
    String paymentMethod = existing?['payment_method'] as String? ?? 'Cash';

    if (!_categories.contains(category)) {
      customCategoryCtrl.text = category;
      category = 'Other';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Naya Expense' : 'Expense Edit Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Other'),
                ),
                if (category == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCategoryCtrl,
                    decoration: const InputDecoration(labelText: 'Category Naam'),
                  ),
                ],
                const SizedBox(height: 8),
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
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: ['Cash', 'Bank', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => paymentMethod = v ?? 'Cash'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
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
                final finalCategory =
                    category == 'Other' ? customCategoryCtrl.text.trim() : category;
                if (finalCategory.isEmpty) return;

                final data = {
                  'company_id': widget.companyId,
                  'category': finalCategory,
                  'amount': amount,
                  'expense_date': date.toIso8601String(),
                  'payment_method': paymentMethod,
                  'description': descCtrl.text.trim(),
                };

                if (existing == null) {
                  data['created_at'] = DateTime.now().toIso8601String();
                  await DBHelper.instance.insertExpense(data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Expense',
                    action: AuditLogger.create,
                    description: 'Naya expense: $finalCategory (Rs. ${amount.toStringAsFixed(0)})',
                  );
                } else {
                  await DBHelper.instance.updateExpense(existing['id'] as int, data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Expense',
                    action: AuditLogger.update,
                    description: 'Expense update kiya: $finalCategory (Rs. ${amount.toStringAsFixed(0)})',
                  );
                }
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

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expense Delete Karein?'),
        content: Text('"${e['category']}" (Rs. ${e['amount']}) delete ho jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteExpense(e['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Expense',
        action: AuditLogger.delete,
        description: 'Expense delete kiya: ${e['category']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Expenses'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('Abhi koi expense nahi bana'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) {
                    final e = _expenses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.receipt_long, color: Colors.white, size: 18),
                        ),
                        title: Text(e['category'] as String),
                        subtitle: Text(
                            (e['expense_date'] as String).substring(0, 10)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rs. ${(e['amount'] as num).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showForm(existing: e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _confirmDelete(e),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
