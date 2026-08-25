import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/utils/error_handler.dart';
import 'customer_form_screen.dart';
import '../ledger/customer_ledger_screen.dart';
import '../shell/main_shell.dart';

class CustomerListScreen extends StatefulWidget {
  final int companyId;
  const CustomerListScreen({super.key, required this.companyId});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ErrorHandler.run(context, () async {
      final rows = await DBHelper.instance.getCustomers(widget.companyId, searchQuery: _query);
      if (mounted) {
        setState(() => _customers = rows);
      }
    }, onFinish: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerFormScreen(companyId: widget.companyId, existing: existing),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openLedger(Map<String, dynamic> customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLedgerScreen(
          customer: customer,
          companyId: widget.companyId,
        ),
      ),
    );
    _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Delete Karein?'),
        content: Text('"${c['name']}" delete ho jayega. Baad mein Recycle Bin se restore ho sakta hai.'),
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
      await ErrorHandler.run(context, () async {
        await DBHelper.instance.deleteCustomer(c['id'] as int);
        await AuditLogger.log(
          companyId: widget.companyId,
          module: 'Customer',
          action: AuditLogger.delete,
          description: 'Customer delete kiya: ${c['name']}',
        );
        _load();
      }, errorTitle: 'Delete fail ho gaya');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Customers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Naam ya mobile se search karein',
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
                : _customers.isEmpty
                ? const Center(child: Text('Abhi koi customer nahi bana'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                final balance = (c['current_balance'] as num).toDouble();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        (c['name'] as String).isNotEmpty
                            ? (c['name'] as String)[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(c['name'] as String),
                    subtitle: Text(
                        '${c['mobile'] ?? ''}  •  ${c['customer_type'] ?? ''}\nBalance: Rs. ${balance.toStringAsFixed(0)}',
                        style: TextStyle(color: balance > 0 ? Colors.red : Colors.green)),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'ledger') _openLedger(c);
                        if (value == 'edit') _openForm(existing: c);
                        if (value == 'delete') _confirmDelete(c);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'ledger', child: Text('Ledger Dekhein')),
                        PopupMenuItem(value: 'edit', child: Text('Edit Karein')),
                        PopupMenuItem(value: 'delete', child: Text('Delete Karein')),
                      ],
                    ),
                    onTap: () => _openLedger(c),
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