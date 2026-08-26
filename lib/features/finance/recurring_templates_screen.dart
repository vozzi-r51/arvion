import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class RecurringTemplatesScreen extends StatefulWidget {
  final int companyId;
  const RecurringTemplatesScreen({super.key, required this.companyId});

  @override
  State<RecurringTemplatesScreen> createState() => _RecurringTemplatesScreenState();
}

class _RecurringTemplatesScreenState extends State<RecurringTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getRecurringTemplates(widget.companyId);
    setState(() {
      _templates = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final amountCtrl = TextEditingController(text: existing?['amount']?.toString() ?? '');
    final categoryCtrl = TextEditingController(text: existing?['category'] ?? '');
    String type = existing?['type'] ?? 'expense';
    String frequency = existing?['frequency'] ?? 'monthly';
    DateTime nextDue = existing != null 
        ? DateTime.parse(existing['next_due_date']) 
        : DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nayi Recurring Template' : 'Template Edit Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: (v) => setDialogState(() => frequency = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Next Due: ${nextDue.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDue,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => nextDue = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0 || categoryCtrl.text.isEmpty) return;

                final data = {
                  'company_id': widget.companyId,
                  'type': type,
                  'category': categoryCtrl.text,
                  'amount': amt,
                  'frequency': frequency,
                  'next_due_date': nextDue.toIso8601String(),
                  'active': 1,
                  'created_at': DateTime.now().toIso8601String(),
                };

                await DBHelper.instance.insertRecurringTemplate(data);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Items')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (ctx, i) {
                final t = _templates[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(t['type'] == 'expense' ? Icons.remove_circle_outline : Icons.add_circle_outline, 
                      color: t['type'] == 'expense' ? Colors.red : Colors.green),
                    title: Text(t['category']),
                    subtitle: Text('Rs. ${t['amount']} • ${t['frequency'].toUpperCase()}\nNext: ${t['next_due_date'].substring(0, 10)}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await DBHelper.instance.deleteRecurringTemplate(t['id']);
                        _load();
                      },
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
