import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/db_helper.dart';
import '../../core/notifications/sms_service.dart';
import '../finance/recurring_templates_screen.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final int companyId;
  const CustomerLedgerScreen(
      {super.key, required this.customer, required this.companyId});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  double _currentBalance = 0;
  double _loyaltyPoints = 0;
  String _currency = 'Rs.';
  bool _loading = true;

  int get _customerId => widget.customer['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final allSales = await DBHelper.instance.getSales(widget.companyId);
    final sales =
        allSales.where((s) => s['customer_id'] == _customerId).toList();
    final payments = await DBHelper.instance.getCustomerPayments(_customerId);

    final entries = <Map<String, dynamic>>[];

    for (final s in sales) {
      entries.add({
        'date': s['sale_date'],
        'type': 'sale',
        'label': 'Sale ${s['invoice_number']}',
        'detail':
            'Total: Rs. ${(s['total_amount'] as num).toStringAsFixed(0)}, '
                'Paid: Rs. ${(s['paid_amount'] as num).toStringAsFixed(0)}',
        'amount': (s['due_amount'] as num).toDouble(),
      });
    }

    for (final p in payments) {
      entries.add({
        'date': p['payment_date'],
        'type': 'payment',
        'label': 'Payment Received',
        'detail': p['notes'] as String? ?? p['payment_method'] as String? ?? '',
        'amount': (p['amount'] as num).toDouble(),
      });
    }

    entries
        .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    final freshCustomer = await DBHelper.instance.getCustomerById(_customerId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);

    final balance = freshCustomer != null
        ? (freshCustomer['current_balance'] as num).toDouble()
        : (widget.customer['current_balance'] as num).toDouble();
    final points = freshCustomer != null
        ? (freshCustomer['loyalty_points'] as num?)?.toDouble() ?? 0
        : (widget.customer['loyalty_points'] as num?)?.toDouble() ?? 0;

    setState(() {
      _entries = entries;
      _currentBalance = balance;
      _loyaltyPoints = points;
      if (company != null) _currency = company['currency_symbol'] ?? 'Rs.';
      _loading = false;
    });
  }

  Future<void> _remind() async {
    if (_currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Balance 0 hai, reminder ki zaroorat nahi.')));
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
                title: Text('Strict (Final Warning)')),
          ),
        ],
      ),
    );

    if (selectedTone == null) return;

    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    final shopName = company?['name'] ?? 'Hamari Shop';
    final customerName = widget.customer['name'] ?? 'Customer';
    final balanceStr = _currentBalance.toStringAsFixed(0);

    String message = '';
    if (selectedTone == 'Calm') {
      message =
          "Asalam-o-Alaikum $customerName, umeed hai aap khairiyat se honge. Aik choti si guzarish hai ke aapka balance Rs. $balanceStr baki hai. Jab asani ho, settlement kar dein. Shukriya - $shopName";
    } else if (selectedTone == 'Firm') {
      message =
          "Dear $customerName, ye aapke balance Rs. $balanceStr ki settlement ke liye reminder hai. Bara-e-meharbani jald az jald payment clear kar dein. Regards - $shopName";
    } else {
      message =
          "URGENT: $customerName, aapka balance Rs. $balanceStr kafi arsay se pending hai. Ye final reminder hai. Baraye meharbani aaj hi payment clear karein warna humein sakht iqdam uthana paray ga. - $shopName";
    }

    final String mobile = widget.customer['mobile'] ?? '';
    final String whatsapp = widget.customer['whatsapp'] ?? mobile;

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
              title: const Text('SMS Notification (Gateway)'),
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
      await Share.share(message, subject: 'Payment Reminder');
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
                await DBHelper.instance.insertCustomerPayment({
                  'company_id': widget.companyId,
                  'customer_id': _customerId,
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
        title: Text('${widget.customer['name']} - Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_repeat, color: Colors.white),
            tooltip: 'Set up Recurring Invoice',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecurringTemplatesScreen(
                    companyId: widget.companyId,
                    initialCustomerId: _customerId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Remind Customer',
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Current Balance',
                              style: TextStyle(fontSize: 11)),
                          Text(
                            '$_currency ${_currentBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _currentBalance > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Loyalty Points',
                              style: TextStyle(fontSize: 11)),
                          Text(
                            _loyaltyPoints.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
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
                            final isSale = e['type'] == 'sale';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isSale
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: isSale ? Colors.red : Colors.green,
                                ),
                                title: Text(e['label'] as String),
                                subtitle: Text(
                                    '${(e['date'] as String).substring(0, 10)}  •  ${e['detail']}'),
                                trailing: Text(
                                  '$_currency ${(e['amount'] as double).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSale ? Colors.red : Colors.green,
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
