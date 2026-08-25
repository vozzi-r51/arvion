import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/database/db_helper.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/utils/error_handler.dart';
import 'product_form_screen.dart';
import 'barcode_qr_screen.dart';

class ProductListScreen extends StatefulWidget {
  final int companyId;
  const ProductListScreen({super.key, required this.companyId});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();
  static const _pageSize = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ErrorHandler.run(context, () async {
      final rows = await DBHelper.instance
          .getProducts(widget.companyId, searchQuery: _query, limit: _pageSize, offset: 0);
      if (mounted) {
        setState(() {
          _products = rows;
          _hasMore = rows.length == _pageSize;
        });
      }
    }, onFinish: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _loadMore() async {
    final rows = await DBHelper.instance.getProducts(
      widget.companyId,
      searchQuery: _query,
      limit: _pageSize,
      offset: _products.length,
    );
    setState(() {
      _products = [..._products, ...rows];
      _hasMore = rows.length == _pageSize;
    });
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormScreen(companyId: widget.companyId, existing: existing),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _scanToSearch() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null) return;
    setState(() => _query = code);
    _searchCtrl.text = code;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Delete Karein?'),
        content: Text('"${p['name']}" delete ho jayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteProduct(p['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Product',
        action: AuditLogger.delete,
        description: 'Product delete kiya: ${p['name']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Naam, code ya barcode se search karein',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan Karke Search Karein',
                  onPressed: _scanToSearch,
                ),
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('Abhi koi product nahi bana'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final prod = _products[i];
                          final imagePath = prod['image_path'] as String?;
                          final lowStock = (prod['current_stock'] as num) <=
                              (prod['low_stock_level'] as num);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: imagePath != null &&
                                        File(imagePath).existsSync()
                                    ? FileImage(File(imagePath))
                                    : null,
                                child: imagePath == null
                                    ? const Icon(Icons.inventory_2_outlined,
                                        color: Colors.grey)
                                    : null,
                              ),
                              title: Text(prod['name'] as String),
                              subtitle: Text(
                                'Stock: ${prod['current_stock']}  •  Rs. ${prod['retail_price']}',
                                style: lowStock
                                    ? const TextStyle(color: Colors.red)
                                    : null,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (lowStock)
                                    const Icon(Icons.warning_amber,
                                        color: Colors.red, size: 18),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_2, size: 18),
                                    tooltip: 'Barcode / QR',
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BarcodeQrScreen(product: prod),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _openForm(existing: prod),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () => _confirmDelete(prod),
                                  ),
                                ],
                              ),
                              onTap: () => _openForm(existing: prod),
                            ),
                          );
                        },
                      ),
          ),
          if (!_loading && _hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Aur Products Load Karein'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'product_add_fab',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
