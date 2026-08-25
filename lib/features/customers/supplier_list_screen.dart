import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Company naam ya phone se search karein',
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _suppliers.isEmpty
                ? const Center(child: Text('Abhi koi supplier nahi bana'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _suppliers.length,
              itemBuilder: (ctx, i) {
                final s = _suppliers[i];
                final balance = (s['current_balance'] as num).toDouble();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.local_shipping,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(s['company_name'] as String),
                    subtitle: Text(
                        '${s['contact_person'] ?? ''}  •  ${s['phone'] ?? ''}\nBalance: Rs. ${balance.toStringAsFixed(0)}',
                        style: TextStyle(color: balance > 0 ? Colors.red : Colors.green)),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'ledger') _openLedger(s);
                        if (value == 'edit') _openForm(existing: s);
                        if (value == 'delete') _confirmDelete(s);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'ledger', child: Text('Ledger Dekhein')),
                        PopupMenuItem(value: 'edit', child: Text('Edit Karein')),
                        PopupMenuItem(value: 'delete', child: Text('Delete Karein')),
                      ],
                    ),
                    onTap: () => _openLedger(s),
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