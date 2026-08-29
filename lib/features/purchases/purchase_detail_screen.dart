import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../returns/new_purchase_return_screen.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items =
        await DBHelper.instance.getPurchaseItems(widget.purchase['id'] as int);
    final companyId = widget.purchase['company_id'] as int?;
    final company = companyId != null
        ? await DBHelper.instance.getCompanyById(companyId)
        : null;
    if (!mounted) return;
    setState(() {
      _items = items;
      _company = company;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchase = widget.purchase;
    return Scaffold(
      appBar: AppBar(title: Text(purchase['invoice_number'] as String)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Supplier: ${purchase['supplier_name'] ?? 'Not Selected'}'),
                        Text(
                            'Date: ${(purchase['purchase_date'] as String).substring(0, 16).replaceFirst('T', ' ')}'),
                        Text('Payment: ${purchase['payment_method']}'),
                        if ((purchase['purchase_type'] as String) == 'due')
                          Text(
                            'Due Amount: Rs. ${(purchase['due_amount'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._items.map((item) => Card(
                      child: ListTile(
                        title: Text(item['product_name'] as String),
                        subtitle: Text(
                            '${item['quantity']} x ${CurrencyFormatter.formatFromCompany((item['unit_cost'] as num?) ?? 0, _company, decimalPlaces: 0)}'),
                        trailing: Text(
                            CurrencyFormatter.formatFromCompany(item['total'] as num, _company, decimalPlaces: 0)),
                      ),
                    )),
                const Divider(height: 32),
                _summaryRow('Subtotal', purchase['subtotal'] as num),
                _summaryRow('Discount', purchase['discount_amount'] as num),
                _summaryRow('Total', purchase['total_amount'] as num,
                    bold: true),
                _summaryRow('Paid', purchase['paid_amount'] as num),
                _summaryRow('Due', purchase['due_amount'] as num),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewPurchaseReturnScreen(
                                companyId: purchase['company_id'] as int,
                                initialPurchase: purchase,
                              ),
                            ),
                          );
                          if (result == true && mounted) _load();
                        },
                  icon: const Icon(Icons.keyboard_return, color: Colors.red),
                  label: const Text('Return Items',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                ),
              ],
            ),
    );
  }

  Widget _summaryRow(String label, num value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.formatFromCompany(value, _company, decimalPlaces: 0), style: style),
        ],
      ),
    );
  }
}
