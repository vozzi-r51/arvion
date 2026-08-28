import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class BomFormScreen extends StatefulWidget {
  final int companyId;
  const BomFormScreen({super.key, required this.companyId});

  @override
  State<BomFormScreen> createState() => _BomFormScreenState();
}

class _BomFormScreenState extends State<BomFormScreen> {
  final _nameCtrl = TextEditingController();
  final _outputQtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  int? _selectedFinishedProductId;
  final List<Map<String, dynamic>> _bomItems =
      []; // {product_id, name, qty, unit}

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final rows = await DBHelper.instance.getProducts(widget.companyId);
    setState(() {
      _products = rows;
      _loading = false;
    });
  }

  void _addRawMaterial() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(products: _products),
    );

    if (selected == null) return;

    final qtyCtrl = TextEditingController(text: '1');
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Required Qty for ${selected['name']}'),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity Required'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
              setState(() {
                _bomItems.add({
                  'raw_material_product_id': selected['id'],
                  'name': selected['name'],
                  'quantity_required': qty,
                  'unit': selected['base_unit'] ?? 'Pc',
                });
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _selectedFinishedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name aur Finished Product zaroori hain')),
      );
      return;
    }

    if (_bomItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam se kam 1 Raw Material add karein')),
      );
      return;
    }

    setState(() => _saving = true);

    final bom = {
      'company_id': widget.companyId,
      'finished_product_id': _selectedFinishedProductId,
      'name': _nameCtrl.text.trim(),
      'output_quantity': double.tryParse(_outputQtyCtrl.text) ?? 1.0,
      'notes': _notesCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final items = _bomItems
        .map((it) => {
              'raw_material_product_id': it['raw_material_product_id'],
              'quantity_required': it['quantity_required'],
              'unit': it['unit'],
            })
        .toList();

    await DBHelper.instance.insertBomWithItems(bom: bom, items: items);

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Bill of Materials (BOM)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'BOM Name (e.g. Standard Shirt Formula) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedFinishedProductId,
                  decoration:
                      const InputDecoration(labelText: 'Finished Product *'),
                  items: _products
                      .map((p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(p['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedFinishedProductId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _outputQtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Batch Output Quantity',
                    helperText:
                        'Is formula se kitni finished units banti hain?',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Raw Materials Required',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _addRawMaterial,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Material'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_bomItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('Koi raw material add nahi hua')),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _bomItems.length,
                    itemBuilder: (ctx, i) {
                      final item = _bomItems[i];
                      return Card(
                        child: ListTile(
                          title: Text(item['name'] as String),
                          subtitle: Text(
                              'Required: ${item['quantity_required']} ${item['unit']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => _bomItems.removeAt(i)),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Notes / Instructions'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('BOM Save Karein'),
                ),
              ],
            ),
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  const _ProductPickerSheet({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
      child: Column(
        children: [
          Text('Select Raw Material',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p['name'] as String),
                  subtitle: Text('Cost: Rs. ${p['purchase_price']}'),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
