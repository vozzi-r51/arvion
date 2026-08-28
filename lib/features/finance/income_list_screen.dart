import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_empty_state.dart';

class IncomeListScreen extends StatefulWidget {
  final int companyId;
  const IncomeListScreen({super.key, required this.companyId});

  @override
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  static const _categories = [
    'Other Income',
    'Rental Income',
    'Commission',
    'Refund',
    'Miscellaneous',
    'Other',
  ];

  List<Map<String, dynamic>> _income = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getIncome(widget.companyId);
    setState(() {
      _income = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final amountCtrl = TextEditingController(
        text: existing != null ? '${existing['amount']}' : '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final customCategoryCtrl = TextEditingController();
    String category = existing?['category'] as String? ?? _categories.first;
    DateTime date = existing != null
        ? DateTime.tryParse(existing['income_date'] as String) ?? DateTime.now()
        : DateTime.now();

    if (!_categories.contains(category)) {
      customCategoryCtrl.text = category;
      category = 'Other';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Naya Income' : 'Income Edit Karein'),
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
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? 'Other'),
                ),
                if (category == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCategoryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Category Naam'),
                  ),
                ],
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                final finalCategory = category == 'Other'
                    ? customCategoryCtrl.text.trim()
                    : category;
                if (finalCategory.isEmpty) return;

                final data = {
                  'company_id': widget.companyId,
                  'category': finalCategory,
                  'amount': amount,
                  'income_date': date.toIso8601String(),
                  'description': descCtrl.text.trim(),
                };

                if (existing == null) {
                  data['created_at'] = DateTime.now().toIso8601String();
                  await DBHelper.instance.insertIncome(data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Income',
                    action: AuditLogger.create,
                    description:
                        'Naya income: $finalCategory (Rs. ${amount.toStringAsFixed(0)})',
                  );
                } else {
                  await DBHelper.instance
                      .updateIncome(existing['id'] as int, data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Income',
                    action: AuditLogger.update,
                    description:
                        'Income update kiya: $finalCategory (Rs. ${amount.toStringAsFixed(0)})',
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

  Future<void> _confirmDelete(Map<String, dynamic> inc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Income Delete Karein?'),
        content: Text(
            '"${inc['category']}" (Rs. ${inc['amount']}) delete ho jayega.'),
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
      await DBHelper.instance.deleteIncome(inc['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Income',
        action: AuditLogger.delete,
        description: 'Income delete kiya: ${inc['category']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? ListView.builder(
              itemCount: 8,
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            )
          : _income.isEmpty
              ? AppEmptyState(
                  icon: Icons.savings_outlined,
                  title: 'Abhi koi income entry nahi hui',
                  message:
                      'Sales ke elawa baki income (jaise commission, rent) yahan add karein.',
                  actionLabel: 'Nayi Income',
                  onAction: () => _showForm(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _income.length,
                  itemBuilder: (ctx, i) {
                    final inc = _income[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                        side: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.1)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.12),
                          child: const Icon(Icons.savings_outlined,
                              color: Colors.green, size: 20),
                        ),
                        title: Text(
                          inc['category'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            (inc['income_date'] as String).substring(0, 10)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                'Rs. ${(inc['amount'] as num).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: AppSpacing.s),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showForm(existing: inc);
                                } else if (val == 'delete') {
                                  _confirmDelete(inc);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(color: Colors.red))),
                              ],
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
