import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class NewPurchaseReturnScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? initialPurchase;
  const NewPurchaseReturnScreen({super.key, required this.companyId, this.initialPurchase});

  @override
  State<NewPurchaseReturnScreen> createState() => _NewPurchaseReturnScreenState();
}

class _ReturnLine {
  final int? productId;
  final String productName;
  final double unitCost;
  final double maxQty;
  double returnQty;
  bool selected;

  _ReturnLine({
    required this.productId,
    required this.productName,
    required this.unitCost,
    required this.maxQty,
    required this.returnQty,
    this.selected = false,
  });

  double get total => selected ? unitCost * returnQty : 0;
}

class _NewPurchaseReturnScreenState extends State<NewPurchaseReturnScreen> {
  Map<String, dynamic>? _selectedPurchase;
  List<_ReturnLine> _lines = [];
  bool _saving = false;
  bool _loadingItems = false;

  double get _total => _lines.fold(0, (sum, l) => sum + l.total);

  @override
  void initState() {
    super.initState();
    if (widget.initialPurchase != null) {
      _selectedPurchase = widget.initialPurchase;
      _loadItemsForSelectedPurchase();
    }
  }

  Future<void> _loadItemsForSelectedPurchase() async {
    setState(() => _loadingItems = true);
    final items =
        await DBHelper.instance.getPurchaseItems(_selectedPurchase!['id'] as int);
    setState(() {
      _lines = items
          .map((it) => _ReturnLine(
                productId: it['product_id'] as int?,
                productName: it['product_name'] as String,
                unitCost: (it['unit_cost'] as num).toDouble(),
                maxQty: (it['quantity'] as num).toDouble(),
                returnQty: (it['quantity'] as num).toDouble(),
              ))
          .toList();
      _loadingItems = false;
    });
  }

  Future<void> _pickPurchase() async {
    final purchase = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PurchasePickerSheet(companyId: widget.companyId),
    );
    if (purchase == null) return;

    setState(() => _selectedPurchase = purchase);
    await _loadItemsForSelectedPurchase();
  }

  Future<void> _save() async {
    if (_selectedPurchase == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pehle purchase select karein')));
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
        await DBHelper.instance.generatePurchaseReturnNumber(widget.companyId);

    final returnData = {
      'company_id': widget.companyId,
      'purchase_id': _selectedPurchase!['id'],
      'supplier_id': _selectedPurchase!['supplier_id'],
      'supplier_name': _selectedPurchase!['supplier_name'],
      'return_number': returnNumber,
      'return_date': DateTime.now().toIso8601String(),
      'total_amount': _total,
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = selectedLines
        .map((l) => {
              'product_id': l.productId,
              'product_name': l.productName,
              'quantity': l.returnQty,
              'unit_cost': l.unitCost,
              'total': l.total,
            })
        .toList();

    await DBHelper.instance
        .insertPurchaseReturnWithItems(purchaseReturn: returnData, items: itemsData);

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Return save ho gaya ($returnNumber)')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Return')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _pickPurchase,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(_selectedPurchase == null
                  ? 'Purchase Select Karein'
                  : '${_selectedPurchase!['invoice_number']} — ${_selectedPurchase!['supplier_name'] ?? 'Not Selected'}'),
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
                          Text('Rs. ${line.unitCost.toStringAsFixed(0)} each  •  Max: ${line.maxQty}'),
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
          if (!_loadingItems && _selectedPurchase != null && _lines.isEmpty)
            const Expanded(child: Center(child: Text('Is purchase mein koi item nahi mila'))),
          if (_selectedPurchase != null)
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Return Total', style: TextStyle(fontSize: 16)),
                      Text('Rs. ${_total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ye amount supplier ke balance se kam ho jayega (jo dena hai).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

class _PurchasePickerSheet extends StatefulWidget {
  final int companyId;
  const _PurchasePickerSheet({required this.companyId});

  @override
  State<_PurchasePickerSheet> createState() => _PurchasePickerSheetState();
}

class _PurchasePickerSheetState extends State<_PurchasePickerSheet> {
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getPurchases(widget.companyId);
    setState(() {
      _purchases = rows;
      _filtered = rows;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _filtered = _purchases.where((s) {
        final invoice = (s['invoice_number'] as String).toLowerCase();
        final supplier = (s['supplier_name'] as String? ?? '').toLowerCase();
        final q = query.toLowerCase();
        return invoice.contains(q) || supplier.contains(q);
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
            Text('Purchase Select Karein', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Invoice number ya supplier se search karein',
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('Koi purchase nahi mili'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            return ListTile(
                              title: Text(s['invoice_number'] as String),
                              subtitle: Text(
                                  '${s['supplier_name'] ?? 'Not Selected'}  •  Rs. ${s['total_amount']}'),
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
