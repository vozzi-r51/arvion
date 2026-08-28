import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class UomListScreen extends StatefulWidget {
  final int companyId;
  const UomListScreen({super.key, required this.companyId});

  @override
  State<UomListScreen> createState() => _UomListScreenState();
}

class _UomListScreenState extends State<UomListScreen> {
  List<Map<String, dynamic>> _uoms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getUoms(widget.companyId);
    setState(() {
      _uoms = rows;
      _loading = false;
    });
  }

  void _showForm() {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final factorCtrl = TextEditingController(text: '1');
    bool isBase = false;
    int? baseUnitId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Unit of Measure'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Unit Name (e.g. Dozen, Gram)'),
                ),
                TextField(
                  controller: symbolCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Symbol (e.g. dz, g)'),
                ),
                CheckboxListTile(
                  title: const Text('Is Base Unit?'),
                  value: isBase,
                  onChanged: (v) => setState(() => isBase = v ?? false),
                ),
                if (!isBase && _uoms.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    value: baseUnitId,
                    decoration:
                        const InputDecoration(labelText: 'Base Unit Reference'),
                    items: _uoms
                        .where((u) => u['is_base_unit'] == 1)
                        .map((u) => DropdownMenuItem<int?>(
                              value: u['id'] as int,
                              child: Text(u['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => baseUnitId = v),
                  ),
                  TextField(
                    controller: factorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText:
                            'Conversion Factor (How many base units in this unit?)'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DBHelper.instance.insertUom({
                  'company_id': widget.companyId,
                  'name': nameCtrl.text.trim(),
                  'symbol': symbolCtrl.text.trim(),
                  'is_base_unit': isBase ? 1 : 0,
                  'base_unit_id': baseUnitId,
                  'conversion_factor': double.tryParse(factorCtrl.text) ?? 1,
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Units of Measure (UOM)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _uoms.isEmpty
              ? const Center(child: Text('No Units of Measure added yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _uoms.length,
                  itemBuilder: (ctx, i) {
                    final u = _uoms[i];
                    return Card(
                      child: ListTile(
                        title: Text('${u['name']} (${u['symbol'] ?? ''})'),
                        subtitle: u['is_base_unit'] == 1
                            ? const Text('Base Unit',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold))
                            : Text(
                                '1 ${u['name']} = ${u['conversion_factor']} Base Unit'),
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
