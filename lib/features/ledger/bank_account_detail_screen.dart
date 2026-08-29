import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import 'bank_statement_import_screen.dart';

class BankAccountDetailScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  final int companyId;
  const BankAccountDetailScreen(
      {super.key, required this.account, required this.companyId});

  @override
  State<BankAccountDetailScreen> createState() =>
      _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState extends State<BankAccountDetailScreen> {
  List<Map<String, dynamic>> _transactions = [];
  double _balance = 0;
  bool _loading = true;
  Map<String, dynamic>? _company;

  bool _reconcileMode = false;
  final _statementCtrl = TextEditingController(text: '0');
  final Set<int> _reconciledSelection = {};

  int get _accountId => widget.account['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getBankTransactions(_accountId);
    final accounts = await DBHelper.instance.getBankAccounts(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    final match = accounts.where((a) => a['id'] == _accountId).toList();
    if (!mounted) return;
    setState(() {
      _transactions = rows;
      _company = company;
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
      await DBHelper.instance.deleteBankTransaction(t['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account['bank_name'] as String),
        actions: [
          if (!_reconcileMode) ...[
            IconButton(
              icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
              tooltip: 'Import Bank Statement',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BankStatementImportScreen(
                      companyId: widget.companyId,
                      initialBankAccountId: widget.account['id'] as int,
                    ),
                  ),
                );
                if (result == true) _load();
              },
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _reconcileMode = true;
                _reconciledSelection.clear();
              }),
              icon: const Icon(Icons.checklist, color: Colors.white),
              label: const Text('Reconcile',
                  style: TextStyle(color: Colors.white)),
            ),
          ] else
            IconButton(
              onPressed: () => setState(() => _reconcileMode = false),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_reconcileMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    child: Column(
                      children: [
                        const Text('Current Book Balance',
                            style: TextStyle(fontSize: 13)),
                        Text(
                          CurrencyFormatter.formatFromCompany(_balance, _company, decimalPlaces: 0),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  _buildReconcileHeader(),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text('Abhi koi transaction nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _transactions.length,
                          itemBuilder: (ctx, i) {
                            final t = _transactions[i];
                            final isDeposit = t['type'] == 'deposit';
                            final isReconciled = t['is_reconciled'] == 1;

                            if (_reconcileMode && isReconciled)
                              return const SizedBox.shrink();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: _reconcileMode
                                    ? Checkbox(
                                        value: _reconciledSelection
                                            .contains(t['id']),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _reconciledSelection
                                                  .add(t['id'] as int);
                                            } else {
                                              _reconciledSelection
                                                  .remove(t['id']);
                                            }
                                          });
                                        },
                                      )
                                    : Icon(
                                        isDeposit
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: isDeposit
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                title:
                                    Text(isDeposit ? 'Deposit' : 'Withdrawal'),
                                subtitle: Text(
                                    '${(t['transaction_date'] as String).substring(0, 10)}  •  ${t['description'] ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isReconciled && !_reconcileMode)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(Icons.verified,
                                            size: 16, color: Colors.blue),
                                      ),
                                    Text(
                                      CurrencyFormatter.formatFromCompany(t['amount'] as num, _company, decimalPlaces: 0),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDeposit
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    if (!_reconcileMode)
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
                if (_reconcileMode)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _reconciledSelection.isEmpty
                          ? null
                          : () async {
                              await DBHelper.instance
                                  .markTransactionsReconciled(
                                      _reconciledSelection.toList());
                              setState(() => _reconcileMode = false);
                              _load();
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                          'Mark ${_reconciledSelection.length} Selected as Reconciled'),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _reconcileMode
          ? null
          : FloatingActionButton(
              onPressed: _showForm,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildReconcileHeader() {
    double statementBalance = double.tryParse(_statementCtrl.text) ?? 0;

    // Logic: Starting Balance (Already Reconciled) + Changes from Newly Selected
    double alreadyReconciledSum = 0;
    for (var t in _transactions) {
      if (t['is_reconciled'] == 1) {
        final amt = (t['amount'] as num).toDouble();
        alreadyReconciledSum += (t['type'] == 'deposit' ? amt : -amt);
      }
    }

    double selectedSum = 0;
    for (var t in _transactions) {
      if (_reconciledSelection.contains(t['id'])) {
        final amt = (t['amount'] as num).toDouble();
        selectedSum += (t['type'] == 'deposit' ? amt : -amt);
      }
    }

    double calculatedBalance = alreadyReconciledSum + selectedSum;
    double diff = calculatedBalance - statementBalance;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statementCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Statement Balance (Rs.)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _reconcileInfo('Calculated', calculatedBalance),
              _reconcileInfo('Difference', diff,
                  color: diff == 0 ? Colors.green : Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reconcileInfo(String label, double val, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          CurrencyFormatter.formatFromCompany(val, _company, decimalPlaces: 0),
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }
}
