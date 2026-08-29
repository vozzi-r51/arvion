import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';

class ProductionOrderFormScreen extends StatefulWidget {
  final int companyId;
  const ProductionOrderFormScreen({super.key, required this.companyId});

  @override
  State<ProductionOrderFormScreen> createState() =>
      _ProductionOrderFormScreenState();
}

class _ProductionOrderFormScreenState extends State<ProductionOrderFormScreen> {
  final _qtyCtrl = TextEditingController(text: '10');
  final _laborCostCtrl = TextEditingController(text: '0');
  final _overheadCostCtrl = TextEditingController(text: '0');

  List<Map<String, dynamic>> _boms = [];
  int? _selectedBomId;
  Map<String, dynamic>? _selectedBom;
  List<Map<String, dynamic>> _bomItems = [];
  Map<String, dynamic>? _company;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBoms();
  }

  Future<void> _loadBoms() async {
    final rows = await DBHelper.instance.getBoms(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _boms = rows;
      _company = company;
      _loading = false;
    });
  }

  Future<void> _onBomChanged(int? bomId) async {
    if (bomId == null) return;
    final bom = _boms.firstWhere((b) => b['id'] == bomId);
    final items = await DBHelper.instance.getBomItems(bomId);

    setState(() {
      _selectedBomId = bomId;
      _selectedBom = bom;
      _bomItems = items;
    });
  }

  double get _qtyToProduce => double.tryParse(_qtyCtrl.text) ?? 1.0;

  double get _totalMaterialCost {
    if (_selectedBom == null) return 0;
    final outputQty = (_selectedBom!['output_quantity'] as num).toDouble();
    final multiplier = _qtyToProduce / outputQty;

    double cost = 0;
    for (var item in _bomItems) {
      final reqQty = (item['quantity_required'] as num).toDouble() * multiplier;
      final unitCost = (item['unit_cost'] as num).toDouble();
      cost += reqQty * unitCost;
    }
    return cost;
  }

  Future<void> _save() async {
    if (_selectedBomId == null || _qtyToProduce <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BOM aur Valid Quantity zaroori hain')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = {
      'company_id': widget.companyId,
      'bom_id': _selectedBomId,
      'quantity_to_produce': _qtyToProduce,
      'status': 'planned',
      'labor_cost': double.tryParse(_laborCostCtrl.text) ?? 0,
      'overhead_cost': double.tryParse(_overheadCostCtrl.text) ?? 0,
      'total_raw_material_cost': _totalMaterialCost,
      'created_at': DateTime.now().toIso8601String(),
    };

    await DBHelper.instance.insertProductionOrder(data);

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Production Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedBomId,
                  decoration: const InputDecoration(
                      labelText: 'Select Bill of Materials (BOM) *'),
                  items: _boms
                      .map((b) => DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(
                                '${b['name']} (${b['finished_product_name']})'),
                          ))
                      .toList(),
                  onChanged: _onBomChanged,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Quantity to Produce *'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _laborCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Labor Cost (Estimated)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _overheadCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Overhead Cost'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_selectedBom != null) ...[
                  Card(
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Production Summary',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          const SizedBox(height: 8),
                          Text(
                              'Est. Raw Material Cost: Rs. ${_totalMaterialCost.toStringAsFixed(0)}'),
                          Text(
                              'Est. Labor + Overhead: Rs. ${((double.tryParse(_laborCostCtrl.text) ?? 0) + (double.tryParse(_overheadCostCtrl.text) ?? 0)).toStringAsFixed(0)}'),
                          const Divider(),
                          Text(
                              'Est. Total Unit Cost: Rs. ${((_totalMaterialCost + (double.tryParse(_laborCostCtrl.text) ?? 0) + (double.tryParse(_overheadCostCtrl.text) ?? 0)) / _qtyToProduce).toStringAsFixed(2)} / unit',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Estimated Raw Materials Required',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._bomItems.map((item) {
                    final outputQty =
                        (_selectedBom!['output_quantity'] as num).toDouble();
                    final multiplier = _qtyToProduce / outputQty;
                    final reqQty =
                        (item['quantity_required'] as num).toDouble() *
                            multiplier;

                    return ListTile(
                      dense: true,
                      title: Text(item['raw_material_name'] as String),
                      subtitle: Text(
                          'Required: ${reqQty.toStringAsFixed(2)} ${item['unit']}'),
                      trailing: Text(
                          CurrencyFormatter.formatFromCompany(reqQty * (item['unit_cost'] as num).toDouble(), _company, decimalPlaces: 0)),
                    );
                  }).toList(),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Planned Order'),
                ),
              ],
            ),
    );
  }
}
