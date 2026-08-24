import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final int companyId;
  const StockAdjustmentScreen({super.key, required this.companyId});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  List<Map<String, dynamic>> _adjustments = [];
  bool _loading = true;

  static const _types = {
    'increase': ('Stock Barhayein', Icons.add_circle_outline, Colors.green),
    'decrease': ('Stock Kam Karein', Icons.remove_circle_outline, Colors.orange),
    'damage': ('Damage Stock', Icons.broken_image_outlined, Colors.red),
    'lost': ('Lost Stock', Icons.help_outline, Colors.red),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final rows = await DBHelper.instance.getStockAdjustments(widget.companyId);
      if (!mounted) return;
      setState(() {
        _adjustments = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustments load nahi ho sake: $error')),
      );
    }
  }

  void _showForm() {
    Map<String, dynamic>? selectedProduct;
    String type = 'increase';
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime date = DateTime.now();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Stock Adjustment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _ProductPickerSheet(companyId: widget.companyId),
                    );
                    if (picked != null) setDialogState(() => selectedProduct = picked);
                  },
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(selectedProduct == null
                      ? 'Product Select Karein'
                      : '${selectedProduct!['name']} (Stock: ${selectedProduct!['current_stock']})'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _types.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? 'increase'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${date.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim());
                if (selectedProduct == null || qty == null || qty <= 0) return;
                setDialogState(() => saving = true);
                try {
                  await DBHelper.instance.insertStockAdjustment({
                    'company_id': widget.companyId,
                    'product_id': selectedProduct!['id'],
                    'product_name': selectedProduct!['name'],
                    'type': type,
                    'quantity': qty,
                    'reason': reasonCtrl.text.trim(),
                    'adjustment_date': date.toIso8601String(),
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  try {
                    await AuditLogger.log(
                      companyId: widget.companyId,
                      module: 'Product',
                      action: AuditLogger.stockChange,
                      description:
                          '${_types[type]!.$1}: ${selectedProduct!['name']} ($qty)',
                    );
                  } catch (_) {}
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _load();
                } catch (error) {
                  if (!ctx.mounted) return;
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Stock adjustment save nahi hui: $error')),
                  );
                }
              },
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Adjustment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _adjustments.isEmpty
              ? const Center(child: Text('Abhi koi adjustment nahi hua'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _adjustments.length,
                  itemBuilder: (ctx, i) {
                    final a = _adjustments[i];
                    final typeInfo = _types[a['type']] ?? ('Unknown', Icons.help, Colors.grey);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeInfo.$3.withOpacity(0.15),
                          child: Icon(typeInfo.$2, color: typeInfo.$3, size: 18),
                        ),
                        title: Text(a['product_name'] as String),
                        subtitle: Text(
                            '${typeInfo.$1}  •  ${(a['adjustment_date'] as String).substring(0, 10)}  •  ${a['reason'] ?? ''}'),
                        trailing: Text('${a['quantity']}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: typeInfo.$3)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
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
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _products.length,
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        return ListTile(
                          title: Text(p['name'] as String),
                          subtitle: Text('Stock: ${p['current_stock']}'),
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
