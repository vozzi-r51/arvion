import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class PromotionsListScreen extends StatefulWidget {
  final int companyId;
  const PromotionsListScreen({super.key, required this.companyId});

  @override
  State<PromotionsListScreen> createState() => _PromotionsListScreenState();
}

class _PromotionsListScreenState extends State<PromotionsListScreen> {
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getPromotions(widget.companyId);
    setState(() {
      _promos = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final valueCtrl = TextEditingController(text: existing?['value']?.toString() ?? '');
    String type = existing?['type'] ?? 'percent';
    int? catId = existing?['applicable_category_id'];
    DateTime start = existing != null ? DateTime.parse(existing['start_date']) : DateTime.now();
    DateTime end = existing != null ? DateTime.parse(existing['end_date']) : DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nayi Promotion' : 'Edit Promotion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Promo Name')),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'flat', child: Text('Flat Amount (Rs.)')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                TextField(controller: valueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value')),
                const SizedBox(height: 10),
                Text('Valid from: ${start.toIso8601String().substring(0, 10)} to ${end.toIso8601String().substring(0, 10)}'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) {
                      setDialogState(() {
                        start = picked.start;
                        end = picked.end;
                      });
                    }
                  },
                  child: const Text('Change Dates'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'company_id': widget.companyId,
                  'name': nameCtrl.text,
                  'type': type,
                  'value': double.tryParse(valueCtrl.text) ?? 0,
                  'applicable_category_id': catId,
                  'start_date': start.toIso8601String(),
                  'end_date': end.toIso8601String(),
                  'active': 1,
                  'created_at': DateTime.now().toIso8601String(),
                };
                if (existing == null) {
                  await DBHelper.instance.insertPromotion(data);
                } else {
                  await DBHelper.instance.updatePromotion(existing['id'], data);
                }
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
      appBar: AppBar(title: const Text('Promotions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _promos.length,
              itemBuilder: (ctx, i) {
                final p = _promos[i];
                return Card(
                  child: ListTile(
                    title: Text(p['name']),
                    subtitle: Text('${p['type'].toUpperCase()}: ${p['value']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await DBHelper.instance.deletePromotion(p['id']);
                        _load();
                      },
                    ),
                    onTap: () => _showForm(existing: p),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
