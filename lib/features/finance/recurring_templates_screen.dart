import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/recurring_sales_service.dart';
import '../../core/utils/currency_formatter.dart';

class RecurringTemplatesScreen extends StatefulWidget {
  final int companyId;
  final int? initialCustomerId; // For quick setup from Customer Ledger

  const RecurringTemplatesScreen({
    super.key,
    required this.companyId,
    this.initialCustomerId,
  });

  @override
  State<RecurringTemplatesScreen> createState() =>
      _RecurringTemplatesScreenState();
}

class _RecurringTemplatesScreenState extends State<RecurringTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _company;

  bool _loading = true;
  String _currencyCode = 'PKR';
  String _currencySymbol = 'Rs.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company != null) {
      _currencyCode = company['currency_code'] as String? ?? 'PKR';
      _currencySymbol = company['currency_symbol'] as String? ?? 'Rs.';
    }

    final rows =
        await DBHelper.instance.getRecurringTemplates(widget.companyId);
    final custs = await DBHelper.instance.getCustomers(widget.companyId);
    final prods = await DBHelper.instance.getProducts(widget.companyId);

    if (!mounted) return;
    setState(() {
      _templates = rows;
      _customers = custs;
      _products = prods;
      _company = company;
      _loading = false;
    });

    if (widget.initialCustomerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForm(preselectedCustomerId: widget.initialCustomerId);
      });
    }
  }

  void _duplicateTemplate(Map<String, dynamic> template) async {
    final copyData = RecurringSalesService.prepareDuplicateTemplate(template);
    final db = await DBHelper.instance.database;
    await db.insert('recurring_templates', copyData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Template duplicated as "${copyData['category']}"!')),
    );
    _load();
  }

  void _showForm({Map<String, dynamic>? existing, int? preselectedCustomerId}) {
    final categoryCtrl =
        TextEditingController(text: existing?['category'] ?? '');
    final amountCtrl =
        TextEditingController(text: existing?['amount']?.toString() ?? '');
    String type = existing?['type'] ??
        (preselectedCustomerId != null ? 'sale' : 'expense');
    String frequency = existing?['frequency'] ?? 'monthly';
    int? selectedCustomerId = existing?['customer_id'] ?? preselectedCustomerId;

    DateTime nextDue = existing != null && existing['next_due_date'] != null
        ? DateTime.parse(existing['next_due_date'])
        : DateTime.now();

    List<Map<String, dynamic>> cartItems = [];
    if (existing?['line_items'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(existing!['line_items']);
        cartItems = List<Map<String, dynamic>>.from(decoded);
      } catch (_) {}
    }

    int? selectedProdId;
    double itemQty = 1;
    double itemPrice = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double calculatedSubtotal = 0;
          for (final item in cartItems) {
            calculatedSubtotal +=
                ((item['quantity'] as num) * (item['unit_price'] as num))
                    .toDouble();
          }

          return AlertDialog(
            title: Text(existing == null
                ? 'Nayi Recurring Template'
                : 'Template Edit Karein'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(
                            value: 'income', child: Text('Income')),
                        DropdownMenuItem(
                            value: 'sale', child: Text('Sale / Invoice')),
                      ],
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                    TextField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Template Name / Description')),
                    if (type == 'sale') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: selectedCustomerId,
                        decoration: const InputDecoration(
                            labelText: 'Select Customer *'),
                        items: _customers
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['name'] as String),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedCustomerId = v),
                      ),
                      const SizedBox(height: 16),
                      const Text('Invoice Items (Cart Picker):',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Cart item picker controls
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedProdId,
                              decoration:
                                  const InputDecoration(labelText: 'Product'),
                              items: _products
                                  .map((p) => DropdownMenuItem<int>(
                                        value: p['id'] as int,
                                        child: Text(p['name'] as String),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  final p = _products
                                      .firstWhere((prod) => prod['id'] == v);
                                  setDialogState(() {
                                    selectedProdId = v;
                                    itemPrice = (p['retail_price'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              decoration:
                                  const InputDecoration(labelText: 'Qty'),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                  text: itemQty.toStringAsFixed(0)),
                              onChanged: (v) =>
                                  itemQty = double.tryParse(v) ?? 1,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.blue),
                            onPressed: () {
                              if (selectedProdId != null && itemQty > 0) {
                                setDialogState(() {
                                  cartItems.add({
                                    'product_id': selectedProdId,
                                    'quantity': itemQty,
                                    'unit_price': itemPrice,
                                  });
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Cart Items List
                      ...cartItems.map((item) {
                        final p = _products.firstWhere(
                          (prod) => prod['id'] == item['product_id'],
                          orElse: () =>
                              {'name': 'Product #${item['product_id']}'},
                        );
                        final tot = (item['quantity'] as num) *
                            (item['unit_price'] as num);
                        return ListTile(
                          dense: true,
                          title: Text(p['name'] as String),
                          subtitle: Text(
                              '${item['quantity']} x Rs. ${item['unit_price']} = Rs. $tot'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red, size: 18),
                            onPressed: () =>
                                setDialogState(() => cartItems.remove(item)),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(CurrencyFormatter.formatFromCompany(calculatedSubtotal, _company, decimalPlaces: 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ] else ...[
                      TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Amount')),
                    ],
                    DropdownButtonFormField<String>(
                      value: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (v) => setDialogState(() => frequency = v!),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Next Due: ${nextDue.toIso8601String().substring(0, 10)}'),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: nextDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setDialogState(() => nextDue = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  double finalAmt = 0;
                  if (type == 'sale') {
                    if (selectedCustomerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Customer Select Karein!')));
                      return;
                    }
                    if (cartItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('At least 1 product add karein!')));
                      return;
                    }
                    finalAmt = calculatedSubtotal;
                  } else {
                    finalAmt = double.tryParse(amountCtrl.text) ?? 0;
                  }

                  final data = {
                    'company_id': widget.companyId,
                    'type': type,
                    'category': categoryCtrl.text.isNotEmpty
                        ? categoryCtrl.text
                        : 'Recurring $type',
                    'amount': finalAmt,
                    'frequency': frequency,
                    'next_due_date': nextDue.toIso8601String().substring(0, 10),
                    'active': 1,
                    'customer_id': selectedCustomerId,
                    'line_items': type == 'sale' ? jsonEncode(cartItems) : null,
                    'created_at': DateTime.now().toIso8601String(),
                  };

                  if (existing != null) {
                    final db = await DBHelper.instance.database;
                    await db.update('recurring_templates', data,
                        where: 'id = ?', whereArgs: [existing['id']]);
                  } else {
                    await DBHelper.instance.insertRecurringTemplate(data);
                  }

                  Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Save Template'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Templates & Invoices')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('Koi recurring template nahi mili.'))
              : ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (ctx, i) {
                    final t = _templates[i];
                    final isSale = t['type'] == 'sale';
                    final isExpense = t['type'] == 'expense';

                    final formattedAmt = CurrencyFormatter.format(
                      (t['amount'] as num).toDouble(),
                      currencyCode: _currencyCode,
                      symbol: _currencySymbol,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          isSale
                              ? Icons.event_repeat
                              : (isExpense
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline),
                          color: isSale
                              ? Colors.blue
                              : (isExpense ? Colors.red : Colors.green),
                        ),
                        title: Text(
                            t['category'] as String? ?? 'Recurring Item',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Type: ${t['type'].toString().toUpperCase()} • ${t['frequency'].toUpperCase()}\nNext Due: ${t['next_due_date']} • Amount: $formattedAmt'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_outlined,
                                  color: Colors.indigo),
                              tooltip: 'Duplicate Template',
                              onPressed: () => _duplicateTemplate(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.blue),
                              onPressed: () => _showForm(existing: t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () async {
                                await DBHelper.instance
                                    .deleteRecurringTemplate(t['id']);
                                _load();
                              },
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
