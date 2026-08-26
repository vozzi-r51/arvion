import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';

class _QuoteCartItem {
  final int productId;
  final String name;
  double unitPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double purchasePrice;
  double qty;
  String? packing;

  String baseUnit;
  String? secondaryUnit;
  double conversionFactor;
  bool isSecondary;

  late final TextEditingController priceController;
  late final TextEditingController qtyController;

  _QuoteCartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.purchasePrice,
    required this.qty,
    this.packing,
    this.baseUnit = 'Pc',
    this.secondaryUnit,
    this.conversionFactor = 1,
    this.isSecondary = false,
  }) {
    priceController = TextEditingController(text: displayPrice.toStringAsFixed(0));
    qtyController = TextEditingController(text: qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1));
  }

  void updateControllers() {
    final pStr = displayPrice.toStringAsFixed(0);
    if (priceController.text != pStr) {
      priceController.text = pStr;
    }
    final qStr = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1);
    if (qtyController.text != qStr) {
      qtyController.text = qStr;
    }
  }

  void dispose() {
    priceController.dispose();
    qtyController.dispose();
  }

  double get displayPrice => isSecondary ? unitPrice * conversionFactor : unitPrice;
  double get total => displayPrice * qty;
  double get baseQty => isSecondary ? qty * conversionFactor : qty;
}

class NewQuotationScreen extends StatefulWidget {
  final int companyId;
  const NewQuotationScreen({super.key, required this.companyId});

  @override
  State<NewQuotationScreen> createState() => _NewQuotationScreenState();
}

class _NewQuotationScreenState extends State<NewQuotationScreen> {
  final List<_QuoteCartItem> _cart = [];
  List<Map<String, dynamic>> _customers = [];
  int? _selectedCustomerId;
  final _discountCtrl = TextEditingController(text: '0');
  final _taxPercentCtrl = TextEditingController(text: '0');
  DateTime _quoteDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final rows = await DBHelper.instance.getCustomers(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _customers = rows;
      if (company != null) {
        _taxPercentCtrl.text = '${company['default_tax_percent'] ?? 0}';
      }
    });
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;
  double get _taxPercent => double.tryParse(_taxPercentCtrl.text.trim()) ?? 0;
  double get _taxAmount => ((_subtotal - _discount).clamp(0, double.infinity)) * _taxPercent / 100;
  double get _grandTotal => (_subtotal - _discount + _taxAmount).clamp(0, double.infinity);

  Future<void> _openProductPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(companyId: widget.companyId),
    );
    if (selected == null) return;

    final productId = selected['id'] as int;
    final existingIndex = _cart.indexWhere((c) => c.productId == productId);

    final retailPrice = (selected['retail_price'] as num).toDouble();
    final wholesalePrice = (selected['wholesale_price'] as num?)?.toDouble() ?? retailPrice;
    
    final isWholesale = _selectedCustomerId != null && 
        _customers.any((c) => c['id'] == _selectedCustomerId && c['customer_type'] == 'Wholesale');

    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].qty += 1;
        _cart[existingIndex].updateControllers();
      } else {
        _cart.add(_QuoteCartItem(
          productId: productId,
          name: selected['name'] as String,
          unitPrice: isWholesale ? wholesalePrice : retailPrice,
          retailPrice: retailPrice,
          wholesalePrice: wholesalePrice,
          purchasePrice: (selected['purchase_price'] as num).toDouble(),
          qty: 1,
          packing: selected['packing'] as String?,
          baseUnit: selected['base_unit'] as String? ?? 'Pc',
          secondaryUnit: selected['secondary_unit'] as String?,
          conversionFactor: (selected['conversion_factor'] as num?)?.toDouble() ?? 1,
        ));
      }
    });
  }

  void _removeItem(int index) {
    _cart[index].dispose();
    setState(() => _cart.removeAt(index));
  }

  void _changeQty(int index, double delta) {
    setState(() {
      final newQty = _cart[index].qty + delta;
      if (newQty > 0) {
        _cart[index].qty = newQty;
        _cart[index].updateControllers();
      }
    });
  }

  Future<void> _saveQuote() async {
    if (_cart.isEmpty) return;

    setState(() => _saving = true);

    final quoteNumber = await DBHelper.instance.generateQuoteNumber(widget.companyId);
    String? customerName;
    if (_selectedCustomerId != null) {
      final c = _customers.firstWhere((c) => c['id'] == _selectedCustomerId);
      customerName = c['name'] as String;
    }

    final quoteData = {
      'company_id': widget.companyId,
      'quote_number': quoteNumber,
      'customer_id': _selectedCustomerId,
      'customer_name': customerName,
      'quote_date': _quoteDate.toIso8601String(),
      'valid_until': _validUntil.toIso8601String(),
      'subtotal': _subtotal,
      'discount_amount': _discount,
      'tax_amount': _taxAmount,
      'total_amount': _grandTotal,
      'status': 'draft',
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = _cart.map((c) => {
      'product_id': c.productId,
      'product_name': c.name,
      'quantity': c.baseQty,
      'unit_price': c.unitPrice,
      'purchase_price': c.purchasePrice,
      'packing': c.isSecondary ? c.secondaryUnit : c.baseUnit,
      'total': c.total,
    }).toList();

    try {
      await DBHelper.instance.insertQuotationWithItems(
        quotation: quoteData,
        items: itemsData,
      );
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Quotation',
        action: AuditLogger.create,
        description: 'Nayi quotation banayi: $quoteNumber',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final item in _cart) {
      item.dispose();
    }
    _discountCtrl.dispose();
    _taxPercentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Quotation')),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () => _removeItem(i),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Rate: ', style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                style: const TextStyle(fontSize: 13),
                                controller: item.priceController,
                                onChanged: (v) {
                                  final val = double.tryParse(v) ?? 0;
                                  setState(() {
                                    if (item.isSecondary) {
                                      item.unitPrice = val / item.conversionFactor;
                                    } else {
                                      item.unitPrice = val;
                                    }
                                  });
                                },
                              ),
                            ),
                            if (item.secondaryUnit != null && item.secondaryUnit!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: FilterChip(
                                  label: Text(item.isSecondary ? item.secondaryUnit! : item.baseUnit, style: const TextStyle(fontSize: 10)),
                                  selected: item.isSecondary,
                                  onSelected: (v) => setState(() {
                                    item.isSecondary = v;
                                    item.updateControllers();
                                  }),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () => _changeQty(i, -1),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                style: const TextStyle(fontSize: 13),
                                controller: item.qtyController,
                                onChanged: (v) {
                                  final val = double.tryParse(v) ?? 0;
                                  setState(() => item.qty = val);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () => _changeQty(i, 1),
                            ),
                            const Spacer(),
                            Text(
                              'Rs. ${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Material(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openProductPicker,
                              icon: const Icon(Icons.add),
                              label: const Text('Product'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _quoteDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _quoteDate = picked);
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_quoteDate.toIso8601String().substring(0, 10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'Customer (optional)', isDense: true),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Walk-in Customer')),
                          ..._customers.map((c) => DropdownMenuItem<int?>(
                            value: c['id'] as int,
                            child: Text(c['name'] as String),
                          )),
                        ],
                        onChanged: (v) => setState(() => _selectedCustomerId = v),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Discount', isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _taxPercentCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Tax %', isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16)),
                          Text(
                            'Rs. ${_grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _saveQuote,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Quotation'),
                      ),
                    ],
                  ),
                ),
              ),
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
    final rows = await DBHelper.instance.getProducts(widget.companyId, searchQuery: _query);
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
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search karein'),
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
                              subtitle: Text('Stock: ${p['current_stock']}  •  Rs. ${p['retail_price']}'),
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
