import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/database/db_helper.dart';
import '../../core/scanner/barcode_scanner_screen.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/providers/terminology_provider.dart';
import 'product_form_screen.dart';
import 'barcode_qr_screen.dart';
import '../../core/utils/barcode_pdf_service.dart';

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

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ErrorHandler.run(context, () async {
      final rows = await DBHelper.instance.getProducts(widget.companyId,
          searchQuery: _query, limit: _pageSize, offset: 0);
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
    final term = context.watch<TerminologyProvider>();
    final productLabel = term.get('product');

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              ),
              title: Text('${_selectedIds.length} Selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () async {
                          final selectedProds = _products
                              .where((p) => _selectedIds.contains(p['id']))
                              .toList();
                          final company =
                              await DBHelper.instance.getCompanyById(widget.companyId);
                          if (!context.mounted) return;
                          BarcodePdfService.printBarcodeLabels(
                              products: selectedProds, company: company);
                        },
                  tooltip: 'Print Labels',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search $productLabel...',
                  border: OutlineInputBorder(borderRadius: AppRadius.medium),
                  filled: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan Karke Search Karein',
                        onPressed: _scanToSearch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.checklist),
                        tooltip: 'Select Mode',
                        onPressed: () =>
                            setState(() => _isSelectionMode = true),
                      ),
                    ],
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
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => AppSkeleton.listTile(),
                  )
                : _products.isEmpty
                    ? AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Abhi koi $productLabel nahi bana',
                        message: _query.isEmpty
                            ? 'Apni shop mein naya maal add karne ke liye niche wala button dabayein.'
                            : 'Aapki search ke mutabiq koi $productLabel nahi mila.',
                        actionLabel:
                            _query.isEmpty ? 'Naya $productLabel' : null,
                        onAction: _query.isEmpty ? () => _openForm() : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final prod = _products[i];
                          final id = prod['id'] as int;
                          final isSelected = _selectedIds.contains(id);
                          final imagePath = prod['image_path'] as String?;
                          final lowStock = (prod['current_stock'] as num) <=
                              (prod['low_stock_level'] as num);

                          return Card(
                            elevation: isSelected ? 2 : 0,
                            margin: const EdgeInsets.only(bottom: AppSpacing.m),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.medium,
                              side: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedIds.add(id);
                                          } else {
                                            _selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: AppRadius.small,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: imagePath != null &&
                                              File(imagePath).existsSync()
                                          ? Image.file(File(imagePath),
                                              fit: BoxFit.cover)
                                          : Icon(Icons.inventory_2_outlined,
                                              color: lowStock
                                                  ? Colors.orange
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                    ),
                              title: Text(
                                prod['name'] as String,
                                style: AppTypography.titleMedium(context)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Stock: ${prod['current_stock']}  •  Rs. ${prod['retail_price']}',
                                style:
                                    AppTypography.bodySmall(context).copyWith(
                                  color: lowStock ? Colors.red : null,
                                ),
                              ),
                              trailing: _isSelectionMode
                                  ? null
                                  : PopupMenuButton<String>(
                                      icon:
                                          const Icon(Icons.more_vert, size: 20),
                                      onSelected: (val) {
                                        if (val == 'qr') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => BarcodeQrScreen(
                                                    product: prod)),
                                          );
                                        } else if (val == 'edit') {
                                          _openForm(existing: prod);
                                        } else if (val == 'delete') {
                                          _confirmDelete(prod);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                            value: 'qr',
                                            child: Text('QR / Barcode')),
                                        const PopupMenuItem(
                                            value: 'edit', child: Text('Edit')),
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                              onTap: _isSelectionMode
                                  ? () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedIds.remove(id);
                                        } else {
                                          _selectedIds.add(id);
                                        }
                                      });
                                    }
                                  : () => _openForm(existing: prod),
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedIds.add(id);
                                  });
                                }
                              },
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
                child: Text('Aur ${productLabel}s Load Karein'),
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
