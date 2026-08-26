import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuotationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> quotation;
  const QuotationDetailScreen({super.key, required this.quotation});

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final rows = await DBHelper.instance.getQuotationItems(widget.quotation['id'] as int);
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _convertToSale() async {
    if (_converting) return;

    String saleType = 'cash';
    final TextEditingController paidCtrl = TextEditingController(text: widget.quotation['total_amount'].toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Convert to Sale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Is quotation ko sale mein badlein. Payment method select karein:'),
              RadioListTile<String>(
                title: const Text('Cash Sale'),
                value: 'cash',
                groupValue: saleType,
                onChanged: (v) => setDialogState(() {
                  saleType = v!;
                  paidCtrl.text = widget.quotation['total_amount'].toString();
                }),
              ),
              RadioListTile<String>(
                title: const Text('Due / Credit Sale'),
                value: 'due',
                groupValue: saleType,
                onChanged: (v) => setDialogState(() => saleType = v!),
              ),
              if (saleType == 'due')
                TextField(
                  controller: paidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Paid Amount (Rs.)'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (saleType == 'due' && widget.quotation['customer_id'] == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Due sale ke liye customer hona zaroori hai.')));
                  return;
                }
                Navigator.pop(ctx, {'type': saleType, 'paid': double.tryParse(paidCtrl.text) ?? 0});
              },
              child: const Text('Convert'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _converting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final allowNegativeStock = prefs.getBool('allow_negative_stock') ?? false;

      final invoiceNumber = await DBHelper.instance.generateInvoiceNumber(widget.quotation['company_id'] as int);
      
      final double total = (widget.quotation['total_amount'] as num).toDouble();
      final double paid = (result['paid'] as num).toDouble();
      final double due = (total - paid).clamp(0, double.infinity);

      final saleData = {
        'company_id': widget.quotation['company_id'],
        'invoice_number': invoiceNumber,
        'customer_id': widget.quotation['customer_id'],
        'customer_name': widget.quotation['customer_name'],
        'sale_type': result['type'],
        'subtotal': widget.quotation['subtotal'],
        'discount_amount': widget.quotation['discount_amount'],
        'tax_amount': widget.quotation['tax_amount'],
        'total_amount': total,
        'paid_amount': paid,
        'due_amount': due,
        'payment_method': result['type'] == 'cash' ? 'Cash' : 'Due',
        'sale_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      await DBHelper.instance.convertQuotationToSale(
        quoteId: widget.quotation['id'] as int,
        saleData: saleData,
        allowNegativeStock: allowNegativeStock,
      );

      await AuditLogger.log(
        companyId: widget.quotation['company_id'] as int,
        module: 'Quotation',
        action: 'CONVERT',
        description: 'Quotation ${widget.quotation['quote_number']} ko Sale $invoiceNumber mein badla',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale ban gayi hai!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final isConverted = q['status'] == 'converted';

    return Scaffold(
      appBar: AppBar(title: Text(q['quote_number'])),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Customer: ${q['customer_name'] ?? 'Walk-in'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Date: ${q['quote_date'].toString().substring(0, 10)}'),
                      Text('Status: ${q['status'].toUpperCase()}', style: TextStyle(color: isConverted ? Colors.green : Colors.orange)),
                      const Divider(height: 32),
                      const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._items.map((it) => ListTile(
                        title: Text(it['product_name']),
                        subtitle: Text('${it['quantity']} x Rs. ${it['unit_price']}'),
                        trailing: Text('Rs. ${(it['total'] as num).toStringAsFixed(0)}'),
                      )),
                      const Divider(),
                      _summaryRow('Subtotal', q['subtotal']),
                      _summaryRow('Discount', q['discount_amount']),
                      _summaryRow('Tax', q['tax_amount']),
                      const Divider(),
                      _summaryRow('Total', q['total_amount'], bold: true),
                    ],
                  ),
                ),
                if (!isConverted)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: _converting ? null : _convertToSale,
                      icon: _converting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle),
                      label: const Text('Convert to Sale'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _summaryRow(String label, dynamic value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('Rs. ${(value as num).toStringAsFixed(0)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }
}
