import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/services/ux_mode_service.dart';
import '../../core/database/db_helper.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/business_types/business_type_catalog.dart';
import '../../core/templates/business_templates.dart';

class ProductFormScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? existing;
  const ProductFormScreen({super.key, required this.companyId, this.existing});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _urduCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _packingCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController(text: '0');
  final _retailPriceCtrl = TextEditingController(text: '0');
  final _wholesalePriceCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');
  final _lowStockCtrl = TextEditingController(text: '0');
  final _batchCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _baseUnitCtrl = TextEditingController(text: 'Pc');
  final _secondaryUnitCtrl = TextEditingController();
  final _conversionCtrl = TextEditingController(text: '1');

  // Jewelry / Custom Fields
  final _weightCtrl = TextEditingController();
  final _purityCtrl = TextEditingController();
  final _hallmarkCtrl = TextEditingController();
  String _weightUnit = 'Gram';

  // Variants
  bool _hasVariants = false;
  final List<Map<String, dynamic>> _variantAttributes = [];
  List<Map<String, dynamic>> _generatedVariants = [];

  // Item Type
  String _itemType = 'inventory';

  // Custom Fields
  List<Map<String, dynamic>> _customFieldDefs = [];
  final Map<int, TextEditingController> _customFieldCtrls = {};

  // Serial Numbers
  final List<String> _serials = [];
  final _serialInputCtrl = TextEditingController();

  DateTime? _expiryDate;

  Map<String, dynamic>? _company;
  BusinessTemplate? _template;
  UXMode _mode = UXMode.simple;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _uoms = [];
  int? _categoryId;
  int? _brandId;
  int? _uomId;
  String? _imagePath;
  bool _saving = false;
  bool _loading = true;

  final _picker = ImagePicker();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDropdownsAndExisting();
  }

  Future<void> _loadDropdownsAndExisting() async {
    _company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (_company != null) {
      final familyStr =
          _company!['template_family'] as String? ?? 'retailStandard';
      final family = TemplateFamily.values.firstWhere(
        (f) => f.toString().split('.').last == familyStr,
        orElse: () => TemplateFamily.retailStandard,
      );
      _template = BusinessTemplates.getByFamily(family);
    }

    _categories = await DBHelper.instance.getCategories(widget.companyId);
    _brands = await DBHelper.instance.getBrands(widget.companyId);
    _uoms = await DBHelper.instance.getUoms(widget.companyId);
    _mode = await UXModeService.getEffectiveMode(widget.companyId);

    _customFieldDefs = await DBHelper.instance
        .getCustomFieldDefinitions(widget.companyId, 'product');
    for (final def in _customFieldDefs) {
      _customFieldCtrls[def['id'] as int] = TextEditingController();
    }

    final e = widget.existing;
    if (e != null) {
      _itemType = e['item_type'] as String? ?? 'inventory';
      _hasVariants = (e['has_variants'] ?? 0) == 1;

      if (_hasVariants) {
        _generatedVariants =
            await DBHelper.instance.getProductVariants(e['id'] as int);
      }

      final values =
          await DBHelper.instance.getCustomFieldValues(e['id'] as int);
      values.forEach((defId, val) {
        _customFieldCtrls[defId]?.text = val;
      });

      _nameCtrl.text = e['name'] as String? ?? '';
      _urduCtrl.text = e['urdu_name'] as String? ?? '';
      _codeCtrl.text = e['product_code'] as String? ?? '';
      _barcodeCtrl.text = e['barcode'] as String? ?? '';
      _skuCtrl.text = e['sku'] as String? ?? '';
      _packingCtrl.text = e['packing'] as String? ?? '';
      _purchasePriceCtrl.text = '${e['purchase_price'] ?? 0}';
      _retailPriceCtrl.text = '${e['retail_price'] ?? 0}';
      _wholesalePriceCtrl.text = '${e['wholesale_price'] ?? 0}';
      _stockCtrl.text = '${e['current_stock'] ?? 0}';
      _lowStockCtrl.text = '${e['low_stock_level'] ?? 0}';
      _batchCtrl.text = e['batch_number'] as String? ?? '';
      _descCtrl.text = e['description'] as String? ?? '';
      _baseUnitCtrl.text = e['base_unit'] as String? ?? 'Pc';
      _secondaryUnitCtrl.text = e['secondary_unit'] as String? ?? '';
      _conversionCtrl.text = '${e['conversion_factor'] ?? 1}';

      _weightCtrl.text = '${e['weight_value'] ?? ''}';
      _weightUnit = e['weight_unit'] as String? ?? 'Gram';
      _purityCtrl.text = e['purity'] as String? ?? '';
      _hallmarkCtrl.text = e['hallmark_number'] as String? ?? '';

      final expiry = e['expiry_date'] as String?;
      if (expiry != null) _expiryDate = DateTime.tryParse(expiry);
      _categoryId = e['category_id'] as int?;
      _brandId = e['brand_id'] as int?;
      _imagePath = e['image_path'] as String?;
    }

    setState(() => _loading = false);
  }

  void _addVariantAttribute() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Attribute (e.g. Size, Color)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Attribute Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _variantAttributes
                      .add({'name': ctrl.text.trim(), 'values': <String>[]});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _addValueToAttribute(Map<String, dynamic> attr) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Value to ${attr['name']} (e.g. Red, Small)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  (attr['values'] as List<String>).add(ctrl.text.trim());
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _generateVariants() {
    if (_variantAttributes.isEmpty) return;

    List<Map<String, String>> combinations = [{}];

    for (var attr in _variantAttributes) {
      final name = attr['name'] as String;
      final values = attr['values'] as List<String>;
      if (values.isEmpty) continue;

      List<Map<String, String>> newCombos = [];
      for (var existing in combinations) {
        for (var val in values) {
          final copy = Map<String, String>.from(existing);
          copy[name] = val;
          newCombos.add(copy);
        }
      }
      combinations = newCombos;
    }

    setState(() {
      _generatedVariants = combinations.map((combo) {
        final comboStr = combo.values.join('-');
        return {
          'sku': '${_skuCtrl.text.trim()}-$comboStr',
          'barcode': '',
          'attribute_combo': combo,
          'current_stock': 0.0,
          'price_override': null,
        };
      }).toList();
    });
  }

  void _editVariant(Map<String, dynamic> variant, int index) {
    final stockCtrl =
        TextEditingController(text: '${variant['current_stock']}');
    final priceCtrl =
        TextEditingController(text: '${variant['price_override'] ?? ''}');
    final skuCtrl =
        TextEditingController(text: variant['sku'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Variant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU')),
            TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock')),
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Price Override (optional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _generatedVariants[index]['sku'] = skuCtrl.text.trim();
                _generatedVariants[index]['current_stock'] =
                    double.tryParse(stockCtrl.text) ?? 0;
                _generatedVariants[index]['price_override'] =
                    double.tryParse(priceCtrl.text);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _quickAddCategory() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nayi Category (Quick Add)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Category Naam *'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                final id = await DBHelper.instance.insertCategory({
                  'company_id': widget.companyId,
                  'name': ctrl.text.trim(),
                  'status': 'active',
                  'created_at': DateTime.now().toIso8601String(),
                });
                final rows =
                    await DBHelper.instance.getCategories(widget.companyId);
                setState(() {
                  _categories = rows;
                  _categoryId = id;
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  void _quickAddBrand() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naya Brand (Quick Add)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Brand Naam *'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                final id = await DBHelper.instance.insertBrand({
                  'company_id': widget.companyId,
                  'name': ctrl.text.trim(),
                  'status': 'active',
                  'created_at': DateTime.now().toIso8601String(),
                });
                final rows =
                    await DBHelper.instance.getBrands(widget.companyId);
                setState(() {
                  _brands = rows;
                  _brandId = id;
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  void _quickAddUom() {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nayi Unit (Quick Add)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Unit Name (e.g. Dozen, Gram)')),
            TextField(
                controller: symbolCtrl,
                decoration:
                    const InputDecoration(labelText: 'Symbol (e.g. dz, g)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final id = await DBHelper.instance.insertUom({
                  'company_id': widget.companyId,
                  'name': nameCtrl.text.trim(),
                  'symbol': symbolCtrl.text.trim(),
                  'is_base_unit': 1,
                  'conversion_factor': 1.0,
                });
                final rows = await DBHelper.instance.getUoms(widget.companyId);
                setState(() {
                  _uoms = rows;
                  _uomId = id;
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final assetsDir = Directory(p.join(docsDir.path, 'product_images'));
    if (!await assetsDir.exists()) await assetsDir.create(recursive: true);

    final ext = p.extension(picked.path);
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$ext';
    final savedPath = p.join(assetsDir.path, fileName);
    await File(picked.path).copy(savedPath);

    setState(() => _imagePath = savedPath);
  }

  double _parseNum(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product naam zaroori hai')),
      );
      return;
    }

    if (_barcodeCtrl.text.trim().isNotEmpty) {
      final taken = await DBHelper.instance.isBarcodeTaken(
        widget.companyId,
        _barcodeCtrl.text.trim(),
        excludingProductId: _isEditing ? widget.existing!['id'] as int : null,
      );
      if (taken) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Ye barcode kisi aur product par pehle se laga hai')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final data = {
      'company_id': widget.companyId,
      'name': _nameCtrl.text.trim(),
      'urdu_name': _urduCtrl.text.trim(),
      'product_code': _codeCtrl.text.trim(),
      'barcode': _barcodeCtrl.text.trim(),
      'sku': _skuCtrl.text.trim(),
      'packing': _packingCtrl.text.trim(),
      'category_id': _categoryId,
      'brand_id': _brandId,
      'purchase_price': _parseNum(_purchasePriceCtrl.text),
      'retail_price': _parseNum(_retailPriceCtrl.text),
      'wholesale_price': _parseNum(_wholesalePriceCtrl.text),
      'current_stock': _parseNum(_stockCtrl.text),
      'low_stock_level': _parseNum(_lowStockCtrl.text),
      'batch_number': _batchCtrl.text.trim(),
      'expiry_date': _expiryDate?.toIso8601String(),
      'description': _descCtrl.text.trim(),
      'base_unit': _uomId != null
          ? _uoms.firstWhere((u) => u['id'] == _uomId)['name'] as String
          : _baseUnitCtrl.text.trim(),
      'uom_id': _uomId,
      'secondary_unit': _secondaryUnitCtrl.text.trim(),
      'conversion_factor': _parseNum(_conversionCtrl.text),
      'weight_unit': _weightUnit,
      'weight_value': _parseNum(_weightCtrl.text),
      'purity': _purityCtrl.text.trim(),
      'hallmark_number': _hallmarkCtrl.text.trim(),
      'is_serialized': (_template?.hasSerialNumbers ?? false) ? 1 : 0,
      'item_type': _itemType,
      'has_variants': _hasVariants ? 1 : 0,
      'image_path': _imagePath,
      'status': 'active',
    };

    int productId;
    if (_isEditing) {
      productId = widget.existing!['id'] as int;
      final old = widget.existing!;
      await DBHelper.instance.updateProduct(productId, data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Product',
        action: AuditLogger.update,
        description: 'Product update kiya: ${data['name']}',
        beforeValue: {
          'name': old['name'],
          'cost_price': old['cost_price'],
          'sale_price': old['sale_price'],
          'stock_quantity': old['stock_quantity'],
          'min_stock_alert': old['min_stock_alert'],
        },
        afterValue: {
          'name': data['name'],
          'cost_price': data['cost_price'],
          'sale_price': data['sale_price'],
          'stock_quantity': data['stock_quantity'],
          'min_stock_alert': data['min_stock_alert'],
        },
      );
    } else {
      data['created_at'] = DateTime.now().toIso8601String();
      productId = await DBHelper.instance.insertProduct(data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Product',
        action: AuditLogger.create,
        description: 'Naya product banaya: ${data['name']}',
        afterValue: {
          'name': data['name'],
          'cost_price': data['cost_price'],
          'sale_price': data['sale_price'],
          'stock_quantity': data['stock_quantity'],
        },
      );
    }

    if (_hasVariants) {
      await DBHelper.instance
          .saveProductVariants(productId, _generatedVariants);
    }

    final cfValues = <int, String>{};
    _customFieldCtrls.forEach((id, ctrl) {
      cfValues[id] = ctrl.text.trim();
    });
    await DBHelper.instance.saveCustomFieldValues(productId, cfValues);

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showCategoryPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Select Category',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _categories.isEmpty
                  ? const Center(child: Text('Koi category nahi hai'))
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(_categories[i]['name'] as String),
                        onTap: () =>
                            Navigator.pop(ctx, _categories[i]['id'] as int),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _quickAddCategory,
                icon: const Icon(Icons.add),
                label: const Text('+ Nayi Category Banayein'),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _categoryId = selected);
    }
  }

  void _showBrandPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Select Brand',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _brands.isEmpty
                  ? const Center(child: Text('Koi brand nahi hai'))
                  : ListView.builder(
                      itemCount: _brands.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(_brands[i]['name'] as String),
                        onTap: () =>
                            Navigator.pop(ctx, _brands[i]['id'] as int),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _quickAddBrand,
                icon: const Icon(Icons.add),
                label: const Text('+ Naya Brand Banayein'),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _brandId = selected);
    }
  }

  void _showUomPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Select Unit (UOM)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _uoms.isEmpty
                  ? const Center(child: Text('Koi unit nahi hai'))
                  : ListView.builder(
                      itemCount: _uoms.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title:
                            Text('${_uoms[i]['name']} (${_uoms[i]['symbol']})'),
                        onTap: () => Navigator.pop(ctx, _uoms[i]['id'] as int),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _quickAddUom,
                icon: const Icon(Icons.add),
                label: const Text('+ Nayi Unit Banayein'),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _uomId = selected);
    }
  }

  // --- TAB BUILDERS ---

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_mode == UXMode.simple)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '💡 Advanced features? Enable Advanced Mode',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await UXModeService.setMode(
                            widget.companyId, UXMode.advanced);
                        setState(() => _mode = UXMode.advanced);
                      },
                      child:
                          const Text('Enable', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade100,
                  ),
                  child: _imagePath != null && File(_imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child:
                              Image.file(File(_imagePath!), fit: BoxFit.cover),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.grey, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _itemType,
              decoration: const InputDecoration(labelText: 'Item Type'),
              items: const [
                DropdownMenuItem(
                    value: 'inventory', child: Text('Inventory (Stock track)')),
                DropdownMenuItem(value: 'service', child: Text('Service')),
                DropdownMenuItem(
                    value: 'non_inventory', child: Text('Non-Inventory')),
              ],
              onChanged: (v) => setState(() => _itemType = v ?? 'inventory'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Product Naam *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urduCtrl,
              decoration: const InputDecoration(labelText: 'Urdu Naam'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Product Code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(labelText: 'SKU'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Barcode',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan',
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _packingCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Packing (e.g. 1x12)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Category'),
              subtitle: Text(_categoryId != null
                  ? _categories.firstWhere(
                      (c) => c['id'] == _categoryId)['name'] as String
                  : 'Select category'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showCategoryPicker,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Brand'),
              subtitle: Text(_brandId != null
                  ? _brands.firstWhere((b) => b['id'] == _brandId)['name']
                      as String
                  : 'Select brand'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showBrandPicker,
            ),
            const SizedBox(height: 24),
            Text('Pricing',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _purchasePriceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Purchase Price'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _retailPriceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Retail Price'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wholesalePriceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Wholesale Price'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Stock Levels',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Current Stock'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lowStockCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Low Stock Level'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Units',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Primary Unit (UOM)'),
              subtitle: Text(_uomId != null
                  ? '${_uoms.firstWhere((u) => u['id'] == _uomId)['name']} (${_uoms.firstWhere((u) => u['id'] == _uomId)['symbol']})'
                  : 'Default (Pc)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showUomPicker,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secondaryUnitCtrl,
              decoration:
                  const InputDecoration(labelText: 'Secondary Unit (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conversionCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Conversion Factor'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Product ke variants hain?'),
              subtitle: const Text('Size, Color, etc.'),
              value: _hasVariants,
              onChanged: (v) => setState(() => _hasVariants = v),
            ),
            if (_hasVariants) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Variants',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addVariantAttribute,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Attribute'),
                  ),
                ],
              ),
              ..._variantAttributes.map((attr) => Card(
                    color: Colors.grey.shade50,
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(attr['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.red),
                                onPressed: () => setState(
                                    () => _variantAttributes.remove(attr)),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            children: (attr['values'] as List<String>)
                                    .map<Widget>((v) => Chip(
                                          label: Text(v,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          onDeleted: () => setState(() =>
                                              (attr['values'] as List<String>)
                                                  .remove(v)),
                                        ))
                                    .toList() +
                                [
                                  ActionChip(
                                    label: const Icon(Icons.add, size: 14),
                                    onPressed: () => _addValueToAttribute(attr),
                                  )
                                ],
                          ),
                        ],
                      ),
                    ),
                  )),
              if (_variantAttributes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _generateVariants,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Variants'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                  ),
                ),
              if (_generatedVariants.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Generated (${_generatedVariants.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _generatedVariants.length,
                  itemBuilder: (ctx, i) {
                    final v = _generatedVariants[i];
                    final combo = v['attribute_combo'] as Map<String, dynamic>;
                    final label = combo.values.join(' / ');
                    return Card(
                      child: ListTile(
                        dense: true,
                        title: Text(label),
                        subtitle: Text(
                            'SKU: ${v['sku']} | Stock: ${v['current_stock']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editVariant(v, i),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildJewelryTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Jewelry Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _weightUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: ['Gram', 'Tola', 'Ratti', 'Carat']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _weightUnit = v ?? 'Gram'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _purityCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Purity (e.g. 22K)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hallmarkCtrl,
                    decoration: const InputDecoration(labelText: 'Hallmark'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_template?.hasBatchExpiry ?? true) ...[
              TextField(
                controller: _batchCtrl,
                decoration: const InputDecoration(labelText: 'Batch Number'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_expiryDate == null
                    ? 'Expiry Date'
                    : 'Expiry: ${_expiryDate!.toIso8601String().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _expiryDate = picked);
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSerialTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Serial / IMEI Management',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serialInputCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Enter Serial / IMEI'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () {
                    if (_serialInputCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _serials.add(_serialInputCtrl.text.trim());
                        _serialInputCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            if (_serials.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _serials
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _serials.remove(s)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Extra Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            ..._customFieldDefs.map((def) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: _customFieldCtrls[def['id']],
                  decoration: InputDecoration(
                    labelText: def['field_name'],
                    hintText: 'Enter ${def['field_name']}',
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _descCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Product ke baare mein likho',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Product Save Karein'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urduCtrl.dispose();
    _codeCtrl.dispose();
    _barcodeCtrl.dispose();
    _skuCtrl.dispose();
    _packingCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _retailPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _stockCtrl.dispose();
    _lowStockCtrl.dispose();
    _batchCtrl.dispose();
    _descCtrl.dispose();
    _baseUnitCtrl.dispose();
    _secondaryUnitCtrl.dispose();
    _conversionCtrl.dispose();
    _serialInputCtrl.dispose();
    _weightCtrl.dispose();
    _purityCtrl.dispose();
    _hallmarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = <Tab>[
      const Tab(text: 'Basic'),
      const Tab(text: 'Pricing'),
      const Tab(text: 'Stock'),
      if (_mode == UXMode.advanced) const Tab(text: 'Variants'),
      if (_template?.hasCustomFields ?? false) const Tab(text: 'Jewelry'),
      if (_template?.hasSerialNumbers ?? false) const Tab(text: 'Serial'),
      if (_mode == UXMode.advanced && _customFieldDefs.isNotEmpty)
        const Tab(text: 'Custom'),
      const Tab(text: 'Notes'),
    ];

    final tabViews = <Widget>[
      _buildBasicInfoTab(),
      _buildPricingTab(),
      _buildStockTab(),
      if (_mode == UXMode.advanced) _buildVariantsTab(),
      if (_template?.hasCustomFields ?? false) _buildJewelryTab(),
      if (_template?.hasSerialNumbers ?? false) _buildSerialTab(),
      if (_mode == UXMode.advanced && _customFieldDefs.isNotEmpty)
        _buildCustomFieldsTab(),
      _buildDescriptionTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Product Edit Karein' : 'Naya Product'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}
