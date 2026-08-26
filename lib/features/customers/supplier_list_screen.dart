import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_empty_state.dart';
import 'supplier_form_screen.dart';
import '../ledger/supplier_ledger_screen.dart';
import '../shell/main_shell.dart';

class SupplierListScreen extends StatefulWidget {
  final int companyId;
  const SupplierListScreen({super.key, required this.companyId});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows =
    await DBHelper.instance.getSuppliers(widget.companyId, searchQuery: _query);
    setState(() {
      _suppliers = rows;
      _loading = false;
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SupplierFormScreen(companyId: widget.companyId, existing: existing),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openLedger(Map<String, dynamic> supplier) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupplierLedgerScreen(
          supplier: supplier,
          companyId: widget.companyId,
        ),
      ),
    );
    _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supplier Delete Karein?'),
        content: Text('"${s['company_name']}" delete ho jayega. Baad mein Recycle Bin se restore ho sakta hai.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteSupplier(s['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Supplier',
        action: AuditLogger.delete,
        description: 'Supplier delete kiya: ${s['company_name']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Vendors / Suppliers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Company naam ya phone se search karein',
                border: OutlineInputBorder(borderRadius: AppRadius.medium),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => AppSkeleton.listTile(),
                  )
                : _suppliers.isEmpty
                    ? AppEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'Abhi koi supplier nahi bana',
                        message: _query.isEmpty
                            ? 'Jin vendors se aap maal khareedte hain unhein add karein.'
                            : 'Aapki search ke mutabiq koi supplier nahi mila.',
                        actionLabel: _query.isEmpty ? 'Naya Supplier' : null,
                        onAction: _query.isEmpty ? () => _openForm() : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                        itemCount: _suppliers.length,
                        itemBuilder: (ctx, i) {
                          final s = _suppliers[i];
                          final balance = (s['current_balance'] as num).toDouble();
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: AppSpacing.m),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.medium,
                              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                                child: const Icon(Icons.local_shipping_outlined, color: Colors.indigo, size: 20),
                              ),
                              title: Text(
                                s['company_name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  '${s['contact_person'] ?? ''}  •  ${s['phone'] ?? ''}\nBalance: ${balance.toStringAsFixed(0)}',
                                  style: TextStyle(color: balance > 0 ? Colors.red : Colors.green)),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => _openLedger(s),
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (_) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.history),
                                          title: const Text('Ledger Dekhein'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _openLedger(s);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.edit_outlined),
                                          title: const Text('Edit Karein'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _openForm(existing: s);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete_outline, color: Colors.red),
                                          title: const Text('Delete Karein', style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _confirmDelete(s);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}