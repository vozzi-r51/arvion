import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/database/db_helper.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';

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
  DateTime? _expiryDate;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  int? _categoryId;
  int? _brandId;
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
    _categories = await DBHelper.instance.getCategories(widget.companyId);
    _brands = await DBHelper.instance.getBrands(widget.companyId);

    final e = widget.existing;
    if (e != null) {
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
      final expiry = e['expiry_date'] as String?;
      if (expiry != null) _expiryDate = DateTime.tryParse(expiry);
      _categoryId = e['category_id'] as int?;
      _brandId = e['brand_id'] as int?;
      _imagePath = e['image_path'] as String?;
    }

    setState(() => _loading = false);
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
          const SnackBar(content: Text('Ye barcode kisi aur product par pehle se laga hai')),
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
      'base_unit': _baseUnitCtrl.text.trim(),
      'secondary_unit': _secondaryUnitCtrl.text.trim(),
      'conversion_factor': _parseNum(_conversionCtrl.text),
      'image_path': _imagePath,
      'status': 'active',
    };

    if (_isEditing) {
      await DBHelper.instance.updateProduct(widget.existing!['id'] as int, data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Product',
        action: AuditLogger.update,
        description: 'Product update kiya: ${data['name']}',
      );
    } else {
      data['created_at'] = DateTime.now().toIso8601String();
      await DBHelper.instance.insertProduct(data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Product',
        action: AuditLogger.create,
        description: 'Naya product banaya: ${data['name']}',
      );
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Product Edit Karein' : 'Naya Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                              child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.grey, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                        decoration: const InputDecoration(labelText: 'Product Code'),
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
                            tooltip: 'Scan Karein',
                            onPressed: _scanBarcode,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _packingCtrl,
                        decoration: const InputDecoration(labelText: 'Packing (e.g. 1x12)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _brandId,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  items: _brands
                      .map((b) => DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(b['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _brandId = v),
                ),
                const SizedBox(height: 16),
                Text('Pricing',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                        decoration: const InputDecoration(labelText: 'Retail Price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wholesalePriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Wholesale Price'),
                ),
                const SizedBox(height: 16),
                Text('Stock',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _batchCtrl,
                  decoration: const InputDecoration(labelText: 'Batch Number'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_expiryDate == null
                      ? 'Expiry Date (optional)'
                      : 'Expiry Date: ${_expiryDate!.toIso8601String().substring(0, 10)}'),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _baseUnitCtrl,
                        decoration: const InputDecoration(labelText: 'Base Unit (e.g. Pc)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _secondaryUnitCtrl,
                        decoration: const InputDecoration(labelText: 'Secondary Unit (e.g. Box)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _conversionCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Conversion Factor',
                    helperText: 'How many base units in one secondary unit? (e.g. 1 Box = 12 Pc)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
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
              ],
            ),
    );
  }
}
