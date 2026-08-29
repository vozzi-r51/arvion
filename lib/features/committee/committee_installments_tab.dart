import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';

class CommitteeInstallmentsTab extends StatefulWidget {
  final int companyId;
  final int committeeId;
  final double defaultAmount;
  const CommitteeInstallmentsTab({
    super.key,
    required this.companyId,
    required this.committeeId,
    required this.defaultAmount,
  });

  @override
  State<CommitteeInstallmentsTab> createState() =>
      _CommitteeInstallmentsTabState();
}

class _CommitteeInstallmentsTabState extends State<CommitteeInstallmentsTab> {
  List<Map<String, dynamic>> _installments = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final installments =
        await DBHelper.instance.getCommitteeInstallments(widget.committeeId);
    final members =
        await DBHelper.instance.getCommitteeMembers(widget.committeeId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _installments = installments;
      _members = members;
      _company = company;
      _loading = false;
    });
  }

  void _showRecordDialog() {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pehle Members tab mein member add karein')));
      return;
    }

    int? selectedMemberId = _members.first['id'] as int;
    final amountCtrl =
        TextEditingController(text: widget.defaultAmount.toStringAsFixed(0));
    final now = DateTime.now();
    final monthCtrl = TextEditingController(
        text: '${now.year}-${now.month.toString().padLeft(2, '0')}');
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Installment Record Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedMemberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: _members
                      .map((m) => DropdownMenuItem<int>(
                            value: m['id'] as int,
                            child: Text(m['member_name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMemberId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: monthCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Month (yyyy-mm)', hintText: 'jaise: 2026-08'),
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
                      'Date: ${paymentDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setDialogState(() => paymentDate = picked);
                  },
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
                if (amount == null || amount <= 0 || selectedMemberId == null)
                  return;
                await DBHelper.instance.insertCommitteeInstallment({
                  'company_id': widget.companyId,
                  'committee_id': widget.committeeId,
                  'member_id': selectedMemberId,
                  'month': monthCtrl.text.trim(),
                  'amount': amount,
                  'payment_date': paymentDate.toIso8601String(),
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

  String _memberName(int memberId) {
    final match = _members.where((m) => m['id'] == memberId);
    return match.isNotEmpty ? match.first['member_name'] as String : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _installments.isEmpty
          ? const Center(child: Text('Abhi koi installment record nahi hai'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _installments.length,
              itemBuilder: (ctx, i) {
                final inst = _installments[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                    title: Text(_memberName(inst['member_id'] as int)),
                    subtitle: Text(
                        'Month: ${inst['month']}  •  ${(inst['payment_date'] as String).substring(0, 10)}'),
                    trailing: Text(
                      CurrencyFormatter.formatFromCompany(inst['amount'] as num, _company, decimalPlaces: 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecordDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
