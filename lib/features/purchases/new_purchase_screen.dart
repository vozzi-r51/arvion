import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/purchase_service.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/utils/currency_formatter.dart';

class _PurchaseCartItem {
  final int productId;
  final int? variantId;
  final String name;
  double unitCost; // Price per base unit
  double qty; // Quantity in selected unit

  String baseUnit;
  String? secondaryUnit;
  double conversionFactor;
  bool isSecondary = false;

  late final TextEditingController costController;
  late final TextEditingController qtyController;

  _PurchaseCartItem({
    required this.productId,
    this.variantId,
    required this.name,
    required this.unitCost,
    required this.qty,
    this.baseUnit = 'Pc',
    this.secondaryUnit,
    this.conversionFactor = 1,
  }) {
    costController =
        TextEditingController(text: displayCost.toStringAsFixed(0));
    qtyController =
        TextEditingController(text: qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1));
  }

  void updateControllers() {
    final cStr = displayCost.toStringAsFixed(0);
    if (costController.text != cStr) {
      costController.text = cStr;
    }
    final qStr = qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1);
    if (qtyController.text != qStr) {
      qtyController.text = qStr;
    }
  }

  void dispose() {
    costController.dispose();
    qtyController.dispose();
  }

  double get displayCost =>
      isSecondary ? unitCost * conversionFactor : unitCost;
  double get total => displayCost * qty;
  double get baseQty => isSecondary ? qty * conversionFactor : qty;
}

class NewPurchaseScreen extends StatefulWidget {
  final int companyId;
  const NewPurchaseScreen({super.key, required this.companyId});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final List<_PurchaseCartItem> _cart = [];
  List<Map<String, dynamic>> _suppliers = [];
  Map<String, dynamic>? _company;
  int? _selectedSupplierId;
  String _purchaseType = 'cash'; // 'cash' or 'due'
  DateTime _purchaseDate = DateTime.now();
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final rows = await DBHelper.instance.getSuppliers(widget.companyId);
      final company = await DBHelper.instance.getCompanyById(widget.companyId);
      if (!mounted) return;
      setState(() {
        _suppliers = rows;
        _company = company;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppliers load nahi ho sake: $error')),
      );
    }
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;
  double get _taxAmount => double.tryParse(_taxCtrl.text.trim()) ?? 0;
  double get _grandTotal =>
      (_subtotal - _discount + _taxAmount).clamp(0, double.infinity);

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = DateTime(picked.year, picked.month, picked.day,
            _purchaseDate.hour, _purchaseDate.minute, _purchaseDate.second);
      });
    }
  }

  Future<void> _openProductPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(companyId: widget.companyId),
    );
    if (selected == null) return;

    final productId = selected['id'] as int;
    final hasVariants = (selected['has_variants'] ?? 0) == 1;

    int? selectedVariantId;
    String variantLabel = '';
    double variantCost = (selected['purchase_price'] as num).toDouble();

    if (hasVariants) {
      final variants = await DBHelper.instance.getProductVariants(productId);
      if (variants.isNotEmpty && mounted) {
        final chosenVariant = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => ListView.builder(
            itemCount: variants.length,
            itemBuilder: (c, i) {
              final v = variants[i];
              final combo = v['attribute_combo'] as String;
              return ListTile(
                title: Text(combo),
                subtitle: Text('Stock: ${v['current_stock']}'),
                onTap: () => Navigator.pop(c, v),
              );
            },
          ),
        );
        if (chosenVariant == null) return;
        selectedVariantId = chosenVariant['id'] as int;
        variantLabel = ' (${chosenVariant['attribute_combo']})';
      }
    }

    final existingIndex = _cart.indexWhere(
        (c) => c.productId == productId && c.variantId == selectedVariantId);

    if (existingIndex >= 0) {
      setState(() {
        _cart[existingIndex].qty += 1;
        _cart[existingIndex].updateControllers();
      });
    } else {
      setState(() {
        _cart.add(_PurchaseCartItem(
          productId: productId,
          variantId: selectedVariantId,
          name: '${selected['name']}$variantLabel',
          unitCost: variantCost,
          qty: 1,
          baseUnit: selected['base_unit'] as String? ?? 'Pc',
          secondaryUnit: selected['secondary_unit'] as String?,
          conversionFactor:
              (selected['conversion_factor'] as num?)?.toDouble() ?? 1,
        ));
      });
    }
  }

  void _removeItem(int index) {
    _cart[index].dispose();
    setState(() => _cart.removeAt(index));
  }

  Future<void> _savePurchase() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart khali hai')));
      return;
    }

    if (_purchaseType == 'due' && _selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Due purchase ke liye supplier select karna zaroori hai')),
      );
      return;
    }

    setState(() => _saving = true);

    final paidAmount = _purchaseType == 'cash'
        ? _grandTotal
        : (double.tryParse(_paidCtrl.text.trim()) ?? 0);
    final dueAmount = (_grandTotal - paidAmount).clamp(0, double.infinity);

    final invoiceNumber =
        await DBHelper.instance.generatePurchaseInvoiceNumber(widget.companyId);

    String? supplierName;
    if (_selectedSupplierId != null) {
      final s = _suppliers.firstWhere((s) => s['id'] == _selectedSupplierId);
      supplierName = s['company_name'] as String;
    }

    final purchaseData = {
      'company_id': widget.companyId,
      'invoice_number': invoiceNumber,
      'supplier_id': _selectedSupplierId,
      'supplier_name': supplierName,
      'purchase_type': _purchaseType,
      'subtotal': _subtotal,
      'discount_amount': _discount,
      'tax_amount': _taxAmount,
      'total_amount': _grandTotal,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'payment_method': _purchaseType == 'cash' ? 'Cash' : 'Due',
      'purchase_date': _purchaseDate.toIso8601String(),
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = _cart
        .map((c) => {
              'product_id': c.productId,
              'variant_id': c.variantId,
              'product_name': c.name,
              'quantity': c.baseQty,
              'unit_cost': c.unitCost,
              'packing': c.isSecondary ? c.secondaryUnit : c.baseUnit,
              'total': c.total,
            })
        .toList();

    try {
      await sl<PurchaseService>().createPurchaseWithItems(
        purchase: purchaseData,
        items: itemsData,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase save nahi ho saki: $error')),
      );
      return;
    }

    await AuditLogger.log(
      companyId: widget.companyId,
      module: 'Purchase',
      action: AuditLogger.create,
      description:
          'Purchase banayi: $invoiceNumber (Rs. ${_grandTotal.toStringAsFixed(0)})',
    );
    await AuditLogger.log(
      companyId: widget.companyId,
      module: 'Product',
      action: AuditLogger.stockChange,
      description:
          'Stock barha ${_cart.length} product(s) ka — Purchase $invoiceNumber ki wajah se',
    );

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase save ho gayi ($invoiceNumber)')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    for (final item in _cart) {
      item.dispose();
    }
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text(
                'Purchase Date: ${_purchaseDate.toIso8601String().substring(0, 10)}'),
            trailing: TextButton(
                onPressed: _pickPurchaseDate, child: const Text('Badlein')),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text('Cart khali hai — product add karein'))
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18, color: Colors.red),
                                    onPressed: () => _removeItem(i),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: item.qtyController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Quantity', isDense: true),
                                      onChanged: (v) {
                                        final val = double.tryParse(v) ?? 0;
                                        setState(() => item.qty = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: item.costController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Unit Cost (Rs.)',
                                          isDense: true),
                                      onChanged: (v) {
                                        final val = double.tryParse(v) ?? 0;
                                        setState(() {
                                          if (item.isSecondary) {
                                            item.unitCost =
                                                val / item.conversionFactor;
                                          } else {
                                            item.unitCost = val;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  if (item.secondaryUnit != null &&
                                      item.secondaryUnit!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8.0, top: 12),
                                      child: FilterChip(
                                        label: Text(
                                            item.isSecondary
                                                ? item.secondaryUnit!
                                                : item.baseUnit,
                                            style:
                                                const TextStyle(fontSize: 10)),
                                        selected: item.isSecondary,
                                        onSelected: (v) => setState(() {
                                          item.isSecondary = v;
                                          item.updateControllers();
                                        }),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 80,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Text(
                                        CurrencyFormatter.formatFromCompany(item.total, _company, decimalPlaces: 0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2)),
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
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Select Nahi Kiya')),
                    ..._suppliers.map((s) => DropdownMenuItem<int?>(
                          value: s['id'] as int,
                          child: Text(s['company_name'] as String),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedSupplierId = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cash'),
                        value: 'cash',
                        groupValue: _purchaseType,
                        onChanged: (v) => setState(() => _purchaseType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due'),
                        value: 'due',
                        groupValue: _purchaseType,
                        onChanged: (v) => setState(() => _purchaseType = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Discount (Rs.)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _taxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Tax (GST)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_purchaseType == 'due') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _paidCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Paid Amount (Rs.)'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16)),
                    Text(
                      CurrencyFormatter.formatFromCompany(_grandTotal, _company, decimalPlaces: 0),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _savePurchase,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Purchase Complete Karein'),
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
    try {
      final rows = await DBHelper.instance.getProducts(
        widget.companyId,
        searchQuery: _query,
      );
      if (!mounted) return;
      setState(() {
        _products = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Products load nahi ho sake: $error')),
      );
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null) return;
    setState(() => _query = code);
    _load();
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
            Text('Product Select Karein',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search karein',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scan,
                ),
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
                              subtitle: Text(
                                  'Current Stock: ${p['current_stock']}  •  Cost: Rs. ${p['purchase_price']}'),
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
