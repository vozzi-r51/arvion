import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import 'bank_account_detail_screen.dart';

class BankAccountsScreen extends StatefulWidget {
  final int companyId;
  const BankAccountsScreen({super.key, required this.companyId});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getBankAccounts(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _accounts = rows;
      _company = company;
      _loading = false;
    });
  }

  void _showForm() {
    final bankNameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final openingCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Bank Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameCtrl,
                decoration: const InputDecoration(labelText: 'Bank Naam *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Account Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numberCtrl,
                decoration: const InputDecoration(labelText: 'Account Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: openingCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening Balance'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (bankNameCtrl.text.trim().isEmpty) return;
              final opening = double.tryParse(openingCtrl.text.trim()) ?? 0;
              await DBHelper.instance.insertBankAccount({
                'company_id': widget.companyId,
                'bank_name': bankNameCtrl.text.trim(),
                'account_title': titleCtrl.text.trim(),
                'account_number': numberCtrl.text.trim(),
                'opening_balance': opening,
                'current_balance': opening,
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
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Delete Karein?'),
        content: Text('"${a['bank_name']}" delete ho jayega.'),
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
      await DBHelper.instance.deleteBankAccount(a['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Book')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(child: Text('Abhi koi bank account nahi bana'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _accounts.length,
                  itemBuilder: (ctx, i) {
                    final a = _accounts[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.account_balance,
                              color: Colors.white, size: 18),
                        ),
                        title: Text(a['bank_name'] as String),
                        subtitle: Text(a['account_title'] as String? ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.formatFromCompany(a['current_balance'] as num, _company, decimalPlaces: 0),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () => _confirmDelete(a),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BankAccountDetailScreen(
                                  account: a, companyId: widget.companyId),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
