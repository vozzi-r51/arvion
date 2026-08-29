import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';

class ChequeListScreen extends StatefulWidget {
  final int companyId;
  final String type; // 'received' or 'issued'
  const ChequeListScreen(
      {super.key, required this.companyId, required this.type});

  @override
  State<ChequeListScreen> createState() => _ChequeListScreenState();
}

class _ChequeListScreenState extends State<ChequeListScreen> {
  List<Map<String, dynamic>> _cheques = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows =
        await DBHelper.instance.getCheques(widget.companyId, type: widget.type);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _cheques = rows;
      _company = company;
      _loading = false;
    });
  }

  void _showAddDialog() {
    final partyCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime chequeDate = DateTime.now();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(widget.type == 'received'
              ? 'Cheque Wasool Karein'
              : 'Cheque Issue Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: partyCtrl,
                  decoration: InputDecoration(
                      labelText: widget.type == 'received'
                          ? 'Customer/Party Naam *'
                          : 'Payee Naam *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(labelText: 'Bank Naam'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Cheque Number'),
                ),
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
                  title: Text(
                      'Cheque Date: ${chequeDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: chequeDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setDialogState(() => chequeDate = picked);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
                if (partyCtrl.text.trim().isEmpty ||
                    amount == null ||
                    amount <= 0) return;
                await DBHelper.instance.insertCheque({
                  'company_id': widget.companyId,
                  'type': widget.type,
                  'party_name': partyCtrl.text.trim(),
                  'bank_name': bankCtrl.text.trim(),
                  'cheque_number': numberCtrl.text.trim(),
                  'amount': amount,
                  'cheque_date': chequeDate.toIso8601String(),
                  'status': 'pending',
                  'notes': notesCtrl.text.trim(),
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

  void _showStatusDialog(Map<String, dynamic> cheque) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Status Update Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('Pending'),
              onTap: () async {
                await DBHelper.instance
                    .updateChequeStatus(cheque['id'] as int, 'pending');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Cleared'),
              onTap: () async {
                await DBHelper.instance
                    .updateChequeStatus(cheque['id'] as int, 'cleared');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Bounced'),
              onTap: () async {
                await DBHelper.instance
                    .updateChequeStatus(cheque['id'] as int, 'bounced');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cheque Delete Karein?'),
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
      await DBHelper.instance.deleteCheque(c['id'] as int);
      _load();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cleared':
        return Colors.green;
      case 'bounced':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'cleared':
        return 'Cleared';
      case 'bounced':
        return 'Bounced';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cheques.isEmpty
              ? const Center(child: Text('Abhi koi cheque nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cheques.length,
                  itemBuilder: (ctx, i) {
                    final c = _cheques[i];
                    final status = c['status'] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(status).withOpacity(0.15),
                          child: Icon(Icons.receipt_long,
                              color: _statusColor(status), size: 18),
                        ),
                        title: Text(c['party_name'] as String),
                        subtitle: Text(
                            '${c['bank_name'] ?? ''}  •  #${c['cheque_number'] ?? ''}\n${(c['cheque_date'] as String).substring(0, 10)}'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                CurrencyFormatter.formatFromCompany(c['amount'] as num, _company, decimalPlaces: 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => _showStatusDialog(c),
                              child: Chip(
                                label: Text(_statusLabel(status),
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor:
                                    _statusColor(status).withOpacity(0.15),
                                labelStyle:
                                    TextStyle(color: _statusColor(status)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        onLongPress: () => _confirmDelete(c),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
