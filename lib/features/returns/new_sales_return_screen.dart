import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class NewSalesReturnScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? initialSale;
  const NewSalesReturnScreen({super.key, required this.companyId, this.initialSale});

  @override
  State<NewSalesReturnScreen> createState() => _NewSalesReturnScreenState();
}

class _ReturnLine {
  final int? productId;
  final String productName;
  final double unitPrice;
  final double maxQty;
  double returnQty;
  bool selected;

  _ReturnLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.maxQty,
    required this.returnQty,
    this.selected = false,
  });

  double get total => selected ? unitPrice * returnQty : 0;
}

class _NewSalesReturnScreenState extends State<NewSalesReturnScreen> {
  Map<String, dynamic>? _selectedSale;
  List<_ReturnLine> _lines = [];
  String _refundMethod = 'cash';
  bool _saving = false;
  bool _loadingItems = false;

  double get _total => _lines.fold(0, (sum, l) => sum + l.total);

  @override
  void initState() {
    super.initState();
    if (widget.initialSale != null) {
      _selectedSale = widget.initialSale;
      _loadItemsForSelectedSale();
    }
  }

  Future<void> _loadItemsForSelectedSale() async {
    setState(() => _loadingItems = true);
    final items = await DBHelper.instance.getSaleItems(_selectedSale!['id'] as int);
    setState(() {
      _lines = items
          .map((it) => _ReturnLine(
                productId: it['product_id'] as int?,
                productName: it['product_name'] as String,
                unitPrice: (it['unit_price'] as num).toDouble(),
                maxQty: (it['quantity'] as num).toDouble(),
                returnQty: (it['quantity'] as num).toDouble(),
              ))
          .toList();
      _loadingItems = false;
    });
  }

  Future<void> _pickSale() async {
    final sale = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SalePickerSheet(companyId: widget.companyId),
    );
    if (sale == null) return;

    setState(() {
      _selectedSale = sale;
      _refundMethod = 'cash';
    });
    await _loadItemsForSelectedSale();
  }

  Future<void> _save() async {
    if (_selectedSale == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pehle sale select karein')));
      return;
    }
    final selectedLines = _lines.where((l) => l.selected && l.returnQty > 0).toList();
    if (selectedLines.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kam se kam ek item select karein')));
      return;
    }

    setState(() => _saving = true);

    final returnNumber =
        await DBHelper.instance.generateSalesReturnNumber(widget.companyId);

    final returnData = {
      'company_id': widget.companyId,
      'sale_id': _selectedSale!['id'],
      'customer_id': _selectedSale!['customer_id'],
      'customer_name': _selectedSale!['customer_name'],
      'return_number': returnNumber,
      'return_date': DateTime.now().toIso8601String(),
      'total_amount': _total,
      'refund_method': _refundMethod,
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = selectedLines
        .map((l) => {
              'product_id': l.productId,
              'product_name': l.productName,
              'quantity': l.returnQty,
              'unit_price': l.unitPrice,
              'total': l.total,
            })
        .toList();

    await DBHelper.instance
        .insertSalesReturnWithItems(salesReturn: returnData, items: itemsData);

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Return save ho gaya ($returnNumber)')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomer = _selectedSale?['customer_id'] != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Return')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _pickSale,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(_selectedSale == null
                  ? 'Sale Select Karein'
                  : '${_selectedSale!['invoice_number']} — ${_selectedSale!['customer_name'] ?? 'Walk-in Customer'}'),
            ),
          ),
          if (_loadingItems) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loadingItems && _lines.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _lines.length,
                itemBuilder: (ctx, i) {
                  final line = _lines[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: line.selected,
                      onChanged: (v) => setState(() => line.selected = v ?? false),
                      title: Text(line.productName),
                      subtitle: Row(
                        children: [
                          Text('Rs. ${line.unitPrice.toStringAsFixed(0)} each  •  Max: ${line.maxQty}'),
                          const Spacer(),
                          if (line.selected)
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                initialValue: line.returnQty.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true),
                                onChanged: (v) {
                                  final qty = double.tryParse(v) ?? 0;
                                  setState(() =>
                                      line.returnQty = qty.clamp(0, line.maxQty));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (!_loadingItems && _selectedSale != null && _lines.isEmpty)
            const Expanded(child: Center(child: Text('Is sale mein koi item nahi mila'))),
          if (_selectedSale != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cash Refund'),
                          value: 'cash',
                          groupValue: _refundMethod,
                          onChanged: (v) => setState(() => _refundMethod = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Adjust Due'),
                          value: 'adjust_due',
                          groupValue: _refundMethod,
                          onChanged: hasCustomer
                              ? (v) => setState(() => _refundMethod = v!)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Refund Total', style: TextStyle(fontSize: 16)),
                      Text('Rs. ${_total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Return Save Karein'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SalePickerSheet extends StatefulWidget {
  final int companyId;
  const _SalePickerSheet({required this.companyId});

  @override
  State<_SalePickerSheet> createState() => _SalePickerSheetState();
}

class _SalePickerSheetState extends State<_SalePickerSheet> {
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getSales(widget.companyId);
    setState(() {
      _sales = rows;
      _filtered = rows;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _filtered = _sales.where((s) {
        final invoice = (s['invoice_number'] as String).toLowerCase();
        final customer = (s['customer_name'] as String? ?? '').toLowerCase();
        final q = query.toLowerCase();
        return invoice.contains(q) || customer.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Sale Select Karein', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Invoice number ya customer se search karein',
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('Koi sale nahi mili'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            return ListTile(
                              title: Text(s['invoice_number'] as String),
                              subtitle: Text(
                                  '${s['customer_name'] ?? 'Walk-in Customer'}  •  Rs. ${s['total_amount']}'),
                              onTap: () => Navigator.of(context).pop(s),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
