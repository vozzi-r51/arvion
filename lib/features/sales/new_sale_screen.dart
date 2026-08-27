import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/sales_service.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';
import '../invoice/invoice_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CartItem {
  final int productId;
  final int? variantId;
  final String name;
  double unitPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double purchasePrice;
  double qty;
  final double availableStock;
  String? packing;
  final int? categoryId;

  String baseUnit;
  String? secondaryUnit;
  double conversionFactor;
  bool isSecondary;
  
  String? promoLabel;
  double promoDiscount = 0;

  late final TextEditingController priceController;
  late final TextEditingController qtyController;

  _CartItem({
    required this.productId,
    this.variantId,
    required this.name,
    required this.unitPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.purchasePrice,
    required this.qty,
    required this.availableStock,
    this.packing,
    this.categoryId,
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

class NewSaleScreen extends StatefulWidget {
  final int companyId;
  const NewSaleScreen({super.key, required this.companyId});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final List<_CartItem> _cart = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _activePromos = [];
  int? _selectedCustomerId;
  String _saleType = 'cash'; // 'cash' or 'due'
  final _discountCtrl = TextEditingController(text: '0');
  final _taxPercentCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _redeemPointsCtrl = TextEditingController(text: '0');
  
  double _customerPoints = 0;
  double _pointValue = 1.0;
  String _currency = 'Rs.';
  
  Map<String, dynamic>? _company;
  String? _templateFamily;
  String? _selectedTable; // e.g. "Table 4" or "Takeaway"
  
  DateTime _saleDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    final promos = await DBHelper.instance.getActivePromotions(widget.companyId);
    setState(() => _activePromos = promos);
  }

  Future<void> _loadCustomers() async {
    try {
      final rows = await DBHelper.instance.getCustomers(widget.companyId);
      final company = await DBHelper.instance.getCompanyById(widget.companyId);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _customers = rows;
        _company = company;
        _templateFamily = company?['template_family'] as String?;
        _pointValue = prefs.getDouble('loyalty_point_value') ?? 1.0;
        if (company != null) {
          _taxPercentCtrl.text = '${company['default_tax_percent'] ?? 0}';
          _currency = company['currency_symbol'] ?? 'Rs.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customers load nahi ho sake: $error')),
      );
    }
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;
  double get _redeemedPoints => double.tryParse(_redeemPointsCtrl.text.trim()) ?? 0;
  double get _pointsDiscount => _redeemedPoints * _pointValue;
  double get _taxPercent => double.tryParse(_taxPercentCtrl.text.trim()) ?? 0;
  double get _taxAmount => ((_subtotal - _discount - _pointsDiscount).clamp(0, double.infinity)) * _taxPercent / 100;
  double get _grandTotal => (_subtotal - _discount - _pointsDiscount + _taxAmount).clamp(0, double.infinity);

  void _openKOTDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart khali hai')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: Colors.indigo),
            const SizedBox(width: 8),
            Text('KOT — ${_selectedTable ?? "Takeaway"}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${DateTime.now().toIso8601String().substring(11, 16)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            ..._cart.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Text('${item.qty.toStringAsFixed(0)}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.name, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KOT sent to kitchen!')));
            },
            icon: const Icon(Icons.print),
            label: const Text('Print KOT'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTable() async {
    final tables = await DBHelper.instance.getRestaurantTables(widget.companyId);
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Table / Order Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.takeout_dining),
              title: const Text('Takeaway / Delivery'),
              onTap: () => Navigator.pop(ctx, 'Takeaway'),
            ),
            const Divider(),
            if (tables.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No tables added. Add tables from Restaurant Settings.'),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: tables.length,
                itemBuilder: (c, i) {
                  final t = tables[i];
                  return InkWell(
                    onTap: () => Navigator.pop(c, t['table_number'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(t['table_number'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedTable = selected);
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
    double variantPrice = (selected['retail_price'] as num).toDouble();
    double variantStock = (selected['current_stock'] as num).toDouble();

    if (hasVariants) {
      final variants = await DBHelper.instance.getProductVariants(productId);
      if (variants.isNotEmpty && mounted) {
        final chosenVariant = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Quick Variant Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: variants.length,
                  itemBuilder: (c, i) {
                    final v = variants[i];
                    final stock = (v['current_stock'] as num).toDouble();
                    return InkWell(
                      onTap: () => Navigator.pop(c, v),
                      child: Container(
                        decoration: BoxDecoration(
                          color: stock > 0 ? Colors.teal.shade50 : Colors.red.shade50,
                          border: Border.all(color: stock > 0 ? Colors.teal : Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(v['attribute_combo'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            Text('Stock: ${stock.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: stock > 0 ? Colors.teal.shade900 : Colors.red.shade900)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
        if (chosenVariant == null) return;
        selectedVariantId = chosenVariant['id'] as int;
        variantLabel = ' (${chosenVariant['attribute_combo']})';
        if (chosenVariant['price_override'] != null) {
          variantPrice = (chosenVariant['price_override'] as num).toDouble();
        }
        variantStock = (chosenVariant['current_stock'] as num).toDouble();
      }
    }

    final existingIndex = _cart.indexWhere((c) => c.productId == productId && c.variantId == selectedVariantId);
    final stock = variantStock;

    final retailPrice = variantPrice;
    final wholesalePrice = (selected['wholesale_price'] as num?)?.toDouble() ?? retailPrice;
    
    final isWholesale = _selectedCustomerId != null && 
        _customers.any((c) => c['id'] == _selectedCustomerId && c['customer_type'] == 'Wholesale');

    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].qty += 1;
        _cart[existingIndex].updateControllers();
      } else {
        final newItem = _CartItem(
          productId: productId,
          variantId: selectedVariantId,
          name: '${selected['name']}$variantLabel',
          unitPrice: isWholesale ? wholesalePrice : retailPrice,
          retailPrice: retailPrice,
          wholesalePrice: wholesalePrice,
          purchasePrice: (selected['purchase_price'] as num).toDouble(),
          qty: 1,
          availableStock: stock,
          packing: selected['packing'] as String?,
          categoryId: selected['category_id'] as int?,
          baseUnit: selected['base_unit'] as String? ?? 'Pc',
          secondaryUnit: selected['secondary_unit'] as String?,
          conversionFactor: (selected['conversion_factor'] as num?)?.toDouble() ?? 1,
        );
        _applyPromoToItem(newItem);
        _cart.add(newItem);
      }
    });
  }

  void _applyPromoToItem(_CartItem item) {
    for (var promo in _activePromos) {
      final applicableCat = promo['applicable_category_id'] as int?;
      if (applicableCat != null && applicableCat == item.categoryId) {
        final type = promo['type'] as String;
        final val = (promo['value'] as num).toDouble();
        if (type == 'percent') {
          item.promoDiscount = item.unitPrice * (val / 100);
          item.unitPrice -= item.promoDiscount;
          item.promoLabel = '${promo['name']} (-${val.toStringAsFixed(0)}%)';
        } else if (type == 'flat') {
          item.promoDiscount = val;
          item.unitPrice -= val;
          item.promoLabel = '${promo['name']} (-Rs.${val.toStringAsFixed(0)})';
        }
        item.updateControllers();
        break; // Apply only one promo for now
      }
    }
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

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart khali hai')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final allowNegativeStock = prefs.getBool('allow_negative_stock') ?? false;

    if (_saleType == 'due' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due sale ke liye customer select karna zaroori hai')),
      );
      return;
    }

    setState(() => _saving = true);

    final paidAmount = _saleType == 'cash'
        ? _grandTotal
        : (double.tryParse(_paidCtrl.text.trim()) ?? 0);
    final dueAmount = (_grandTotal - paidAmount).clamp(0, double.infinity);

    final invoiceNumber =
        await DBHelper.instance.generateInvoiceNumber(widget.companyId);

    String? customerName;
    if (_selectedCustomerId != null) {
      final c = _customers.firstWhere((c) => c['id'] == _selectedCustomerId);
      customerName = c['name'] as String;
    }

    final saleData = {
      'company_id': widget.companyId,
      'invoice_number': invoiceNumber,
      'customer_id': _selectedCustomerId,
      'customer_name': customerName,
      'sale_type': _saleType,
      'subtotal': _subtotal,
      'discount_amount': _discount,
      'tax_amount': _taxAmount,
      'total_amount': _grandTotal,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'redeemed_points': _redeemedPoints,
      'payment_method': _saleType == 'cash' ? 'Cash' : 'Due',
      'sale_date': _saleDate.toIso8601String(),
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = _cart
        .map((c) => {
              'product_id': c.productId,
              'variant_id': c.variantId,
              'product_name': c.name,
              'quantity': c.baseQty,
              'unit_price': c.unitPrice,
              'purchase_price': c.purchasePrice,
              'packing': c.isSecondary ? c.secondaryUnit : c.baseUnit,
              'total': c.total,
            })
        .toList();

    int saleId;
    try {
      saleId = await sl<SalesService>().createSaleWithItems(
        sale: saleData,
        items: itemsData,
        allowNegativeStock: allowNegativeStock,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale save nahi ho saki: $error')),
      );
      return;
    }

    try {
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Sale',
        action: AuditLogger.create,
        description: 'Sale banayi: $invoiceNumber (Rs. ${_grandTotal.toStringAsFixed(0)})',
      );
    } catch (_) {
      // The sale is already committed; audit logging must not block checkout.
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (!mounted) return;

    final company = await DBHelper.instance.getCompanyById(widget.companyId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Save Ho Gayi'),
        content: Text('Invoice # $invoiceNumber'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Back to Home'),
          ),
          if (company != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InvoicePreviewScreen(
                      company: company,
                      sale: {...saleData, 'id': saleId},
                      items: itemsData,
                    ),
                  ),
                ).then((_) => Navigator.pop(context, true));
              },
              icon: const Icon(Icons.print),
              label: const Text('Preview / Print'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final item in _cart) {
      item.dispose();
    }
    _discountCtrl.dispose();
    _taxPercentCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurant = _templateFamily == 'foodService';

    return Scaffold(
      appBar: AppBar(
        title: Text(isRestaurant ? 'Order / Billing (${_selectedTable ?? "Takeaway"})' : 'New Sale'),
        actions: [
          if (isRestaurant) ...[
            IconButton(
              icon: const Icon(Icons.table_restaurant),
              tooltip: 'Select Table',
              onPressed: _selectTable,
            ),
            IconButton(
              icon: const Icon(Icons.soup_kitchen),
              tooltip: 'Send to Kitchen (KOT)',
              onPressed: _openKOTDialog,
            ),
          ],
        ],
      ),
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
                                    child: Text(item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  if (item.packing != null && item.packing!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Text('(${item.packing})', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                    ),
                                  if (item.promoLabel != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                      child: Text(item.promoLabel!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(item.baseUnit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
              color: Theme.of(context).colorScheme.surface,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.06),
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
                                  initialDate: _saleDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _saleDate = picked);
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_saleDate.toIso8601String().substring(0, 10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'Customer (optional)', isDense: true),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Walk-in Customer')),
                          ..._customers.map((c) => DropdownMenuItem<int?>(
                                value: c['id'] as int,
                                child: Text(c['name'] as String),
                              )),
                        ],
                        onChanged: (v) async {
                          setState(() {
                            _selectedCustomerId = v;
                            if (v != null) {
                              final customer = _customers.firstWhere((c) => c['id'] == v);
                              _customerPoints = (customer['loyalty_points'] as num?)?.toDouble() ?? 0;
                            } else {
                              _customerPoints = 0;
                              _redeemPointsCtrl.text = '0';
                            }
                          });
                          
                          if (v != null && _cart.isNotEmpty) {
                            final customer = _customers.firstWhere((c) => c['id'] == v);
                            final isWholesale = customer['customer_type'] == 'Wholesale';
                            
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Prices Update Karein?'),
                                content: Text('Aapne ${isWholesale ? "Wholesale" : "Retail"} customer select kiya hai. Kya cart mein mojood products ki prices is ke mutabiq set kar di jayain?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan')),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                              setState(() {
                                for (var item in _cart) {
                                  item.unitPrice = isWholesale ? item.wholesalePrice : item.retailPrice;
                                  item.updateControllers();
                                }
                              });
                            }
                          }
                        },
                      ),
                      if (_selectedCustomerId != null && _customerPoints > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text('Points: ${_customerPoints.toStringAsFixed(1)} (Value: $_currency ${(_customerPoints * _pointValue).toStringAsFixed(0)})',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() => _redeemPointsCtrl.text = _customerPoints.toStringAsFixed(0));
                                },
                                child: const Text('Redeem All', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cash', style: TextStyle(fontSize: 13)),
                              value: 'cash',
                              groupValue: _saleType,
                              onChanged: (v) => setState(() => _saleType = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Due', style: TextStyle(fontSize: 13)),
                              value: 'due',
                              groupValue: _saleType,
                              onChanged: (v) => setState(() => _saleType = v!),
                            ),
                          ),
                        ],
                      ),
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
                          if (_selectedCustomerId != null && _customerPoints > 0) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _redeemPointsCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Redeem Pts', isDense: true),
                                onChanged: (v) {
                                  final val = double.tryParse(v) ?? 0;
                                  if (val > _customerPoints) {
                                    _redeemPointsCtrl.text = _customerPoints.toStringAsFixed(0);
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                          if (_saleType == 'due') ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _paidCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Paid', isDense: true),
                                onChanged: (_) => setState(() {}),
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
                            '$_currency ${_grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _saveSale,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sale Complete Karein'),
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
                            final stock = (p['current_stock'] as num);
                            final expiryStr = p['expiry_date'] as String?;
                            DateTime? expiry;
                            bool isExpiringSoon = false;
                            if (expiryStr != null) {
                              expiry = DateTime.tryParse(expiryStr);
                              if (expiry != null && expiry.difference(DateTime.now()).inDays <= 30) {
                                isExpiringSoon = true;
                              }
                            }

                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(p['name'] as String)),
                                  if (isExpiringSoon)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Expiring Soon!', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                  'Stock: $stock  •  Rs. ${p['retail_price']}${expiry != null ? "  •  Exp: ${expiry.toIso8601String().substring(0, 10)}" : ""}'),
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
