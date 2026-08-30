import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/db_helper.dart';
import '../../core/notifications/sms_service.dart';

class SupplierLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  final int companyId;
  const SupplierLedgerScreen(
      {super.key, required this.supplier, required this.companyId});

  @override
  State<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends State<SupplierLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  double _currentBalance = 0;
  String _currency = 'Rs.';
  bool _loading = true;

  int get _supplierId => widget.supplier['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final allPurchases = await DBHelper.instance.getPurchases(widget.companyId);
    final purchases =
        allPurchases.where((p) => p['supplier_id'] == _supplierId).toList();
    final payments = await DBHelper.instance.getSupplierPayments(_supplierId);

    final entries = <Map<String, dynamic>>[];

    for (final p in purchases) {
      entries.add({
        'date': p['purchase_date'],
        'type': 'purchase',
        'label': 'Purchase ${p['invoice_number']}',
        'detail':
            'Total: Rs. ${(p['total_amount'] as num).toStringAsFixed(0)}, '
                'Paid: Rs. ${(p['paid_amount'] as num).toStringAsFixed(0)}',
        'amount': (p['due_amount'] as num).toDouble(),
      });
    }

    for (final pay in payments) {
      entries.add({
        'date': pay['payment_date'],
        'type': 'payment',
        'label': 'Payment Made',
        'detail':
            pay['notes'] as String? ?? pay['payment_method'] as String? ?? '',
        'amount': (pay['amount'] as num).toDouble(),
      });
    }

    entries
        .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    final freshSupplier = await DBHelper.instance.getSupplierById(_supplierId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    final balance = freshSupplier != null
        ? (freshSupplier['current_balance'] as num).toDouble()
        : (widget.supplier['current_balance'] as num).toDouble();

    setState(() {
      _entries = entries;
      _currentBalance = balance;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  Future<void> _remind() async {
    if (_currentBalance <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Balance 0 hai.')));
      return;
    }

    final selectedTone = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reminder Tone Chunein'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Calm'),
            child: const ListTile(
                leading: Icon(Icons.sentiment_satisfied, color: Colors.green),
                title: Text('Calm (Friendly)')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Firm'),
            child: const ListTile(
                leading: Icon(Icons.sentiment_neutral, color: Colors.orange),
                title: Text('Firm (Formal)')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Strict'),
            child: const ListTile(
                leading:
                    Icon(Icons.sentiment_very_dissatisfied, color: Colors.red),
                title: Text('Strict (Urgent)')),
          ),
        ],
      ),
    );

    if (selectedTone == null) return;

    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    final shopName = company?['name'] ?? 'Hamari Shop';
    final supplierName = widget.supplier['company_name'] ?? 'Supplier';
    final balanceStr = _currentBalance.toStringAsFixed(0);

    String message = '';
    if (selectedTone == 'Calm') {
      message =
          "Asalam-o-Alaikum $supplierName, umeed hai aap khairiyat se honge. Aik choti si guzarish hai ke humara baki balance Rs. $balanceStr baki hai. Is par thori tawaja dein. Shukriya - $shopName";
    } else if (selectedTone == 'Firm') {
      message =
          "Dear $supplierName, ye aapke balance Rs. $balanceStr ki settlement ke baray mein enquiry hai. Regards - $shopName";
    } else {
      message =
          "URGENT: $supplierName, aapka balance Rs. $balanceStr kafi arsay se pending hai. Ye final reminder hai. - $shopName";
    }

    final String mobile = widget.supplier['phone'] ?? '';
    final String whatsapp = widget.supplier['whatsapp'] ?? mobile;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (whatsapp.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.message, color: Colors.green),
                title: const Text('WhatsApp Direct Message'),
                onTap: () => Navigator.pop(ctx, 'wa'),
              ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue),
              title: const Text('Device SMS App (Direct SMS)'),
              onTap: () => Navigator.pop(ctx, 'device_sms'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue, color: Colors.purple),
              title: const Text('SMS Gateway (HTTP API)'),
              onTap: () => Navigator.pop(ctx, 'sms'),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.grey),
              title: const Text('Other Share Options'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'wa') {
      String cleanPhone = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0'))
        cleanPhone = '92' + cleanPhone.substring(1);
      final url =
          "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}";
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } else if (choice == 'device_sms') {
      await SMSService.sendDeviceSMS(mobile: mobile, message: message);
    } else if (choice == 'sms') {
      final success =
          await SMSService.sendSMS(mobile: mobile, message: message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success
                ? 'SMS bhej diya gaya'
                : 'SMS fail ho gaya (Check settings/internet)')));
      }
    } else if (choice == 'share') {
      await Share.share(message, subject: 'Payment Enquiry');
    }
  }

  Future<void> _recordPayment() async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'Cash';
    DateTime date = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Payment Record Karein'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (Rs.) *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Cash', 'Bank', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setDialogState(() => method = v ?? 'Cash'),
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
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                await DBHelper.instance.insertSupplierPayment({
                  'company_id': widget.companyId,
                  'supplier_id': _supplierId,
                  'amount': amount,
                  'payment_date': date.toIso8601String(),
                  'payment_method': method,
                  'notes': notesCtrl.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplier['company_name']} - Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Remind Supplier',
            onPressed: _remind,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  child: Column(
                    children: [
                      const Text('Current Balance',
                          style: TextStyle(fontSize: 13)),
                      Text(
                        '$_currency ${_currentBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              _currentBalance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Text('Abhi koi ledger entry nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _entries.length,
                          itemBuilder: (ctx, i) {
                            final e = _entries[i];
                            final isPurchase = e['type'] == 'purchase';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isPurchase
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: isPurchase ? Colors.red : Colors.green,
                                ),
                                title: Text(e['label'] as String),
                                subtitle: Text(
                                    '${(e['date'] as String).substring(0, 10)}  •  ${e['detail']}'),
                                trailing: Text(
                                  '$_currency ${(e['amount'] as double).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPurchase ? Colors.red : Colors.green,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Payment Record Karein'),
      ),
    );
  }
}
