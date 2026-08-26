import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class _PoCartItem {
  final int productId;
  final String name;
  double unitCost;
  double qty;

  _PoCartItem({
    required this.productId,
    required this.name,
    required this.unitCost,
    required this.qty,
  });

  double get total => unitCost * qty;
}

class NewPurchaseOrderScreen extends StatefulWidget {
  final int companyId;
  final List<Map<String, dynamic>>? initialItems;
  const NewPurchaseOrderScreen({super.key, required this.companyId, this.initialItems});

  @override
  State<NewPurchaseOrderScreen> createState() => _NewPurchaseOrderScreenState();
}

class _NewPurchaseOrderScreenState extends State<NewPurchaseOrderScreen> {
  final List<_PoCartItem> _cart = [];
  List<Map<String, dynamic>> _suppliers = [];
  int? _selectedSupplierId;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (widget.initialItems != null) {
      for (var it in widget.initialItems!) {
        _cart.add(_PoCartItem(
          productId: it['productId'] as int,
          name: it['name'] as String,
          unitCost: it['unitCost'] as double,
          qty: it['qty'] as double,
        ));
      }
    }
  }

  Future<void> _loadSuppliers() async {
    final rows = await DBHelper.instance.getSuppliers(widget.companyId);
    setState(() => _suppliers = rows);
  }

  Future<void> _openProductPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(companyId: widget.companyId),
    );
    if (selected == null) return;

    final productId = selected['id'] as int;
    final existingIndex = _cart.indexWhere((c) => c.productId == productId);

    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].qty += 1;
      } else {
        _cart.add(_PoCartItem(
          productId: productId,
          name: selected['name'] as String,
          unitCost: (selected['purchase_price'] as num).toDouble(),
          qty: 1,
        ));
      }
    });
  }

  void _removeItem(int index) => setState(() => _cart.removeAt(index));

  void _changeQty(int index, double delta) {
    setState(() {
      final newQty = _cart[index].qty + delta;
      if (newQty > 0) _cart[index].qty = newQty;
    });
  }

  Future<void> _save() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart khali hai')));
      return;
    }

    setState(() => _saving = true);

    final poNumber = await DBHelper.instance.generatePoNumber(widget.companyId);

    String? supplierName;
    if (_selectedSupplierId != null) {
      final s = _suppliers.firstWhere((s) => s['id'] == _selectedSupplierId);
      supplierName = s['company_name'] as String;
    }

    final poData = {
      'company_id': widget.companyId,
      'po_number': poNumber,
      'supplier_id': _selectedSupplierId,
      'supplier_name': supplierName,
      'po_date': DateTime.now().toIso8601String(),
      'status': 'draft',
      'total_amount': _total,
      'notes': _notesCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = _cart
        .map((c) => {
              'product_id': c.productId,
              'product_name': c.name,
              'quantity': c.qty,
              'unit_cost': c.unitCost,
              'total': c.total,
            })
        .toList();

    await DBHelper.instance.insertPurchaseOrderWithItems(po: poData, items: itemsData);

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('PO save ho gaya ($poNumber)')));
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Cart khali hai — product add karein'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) {
                      final item = _cart[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Rs. ${item.unitCost.toStringAsFixed(0)} each',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => _changeQty(i, -1),
                              ),
                              Text('${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 1)}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => _changeQty(i, 1),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  'Rs. ${item.total.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
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
                OutlinedButton.icon(
                  onPressed: _openProductPicker,
                  icon: const Icon(Icons.add),
                  label: const Text('Product Add Karein'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: _selectedSupplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Select Nahi Kiya')),
                    ..._suppliers.map((s) => DropdownMenuItem<int?>(
                          value: s['id'] as int,
                          child: Text(s['company_name'] as String),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedSupplierId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16)),
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
                      : const Text('PO Save Karein (Draft)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final int companyId;
  const _ProductPickerSheet({required this.companyId});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await DBHelper.instance.getProducts(widget.companyId, searchQuery: _query);
    setState(() {
      _products = rows;
      _loading = false;
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
            Text('Product Select Karein', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search karein',
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('Koi product nahi mila'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _products.length,
                          itemBuilder: (ctx, i) {
                            final p = _products[i];
                            return ListTile(
                              title: Text(p['name'] as String),
                              subtitle: Text('Cost: Rs. ${p['purchase_price']}'),
                              onTap: () => Navigator.of(context).pop(p),
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
