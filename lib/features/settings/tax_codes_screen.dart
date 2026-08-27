import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class TaxCodesScreen extends StatefulWidget {
  final int companyId;
  const TaxCodesScreen({super.key, required this.companyId});

  @override
  State<TaxCodesScreen> createState() => _TaxCodesScreenState();
}

class _TaxCodesScreenState extends State<TaxCodesScreen> {
  List<Map<String, dynamic>> _taxCodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getTaxCodes(widget.companyId);
    setState(() {
      _taxCodes = rows;
      _loading = false;
    });
  }

  void _showForm() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '17');
    bool isDefault = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Tax Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tax Name (e.g. GST 17%, VAT 5%)'),
              ),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
              ),
              CheckboxListTile(
                title: const Text('Is Default Tax?'),
                value: isDefault,
                onChanged: (v) => setState(() => isDefault = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DBHelper.instance.insertTaxCode({
                  'company_id': widget.companyId,
                  'name': nameCtrl.text.trim(),
                  'rate': double.tryParse(rateCtrl.text) ?? 0.0,
                  'is_default': isDefault ? 1 : 0,
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
      appBar: AppBar(title: const Text('Tax Codes Manager')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _taxCodes.isEmpty
              ? const Center(child: Text('No tax codes created yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _taxCodes.length,
                  itemBuilder: (ctx, i) {
                    final t = _taxCodes[i];
                    return Card(
                      child: ListTile(
                        title: Text(t['name'] as String),
                        subtitle: Text('Rate: ${t['rate']}%'),
                        trailing: t['is_default'] == 1
                            ? const Chip(label: Text('Default', style: TextStyle(fontSize: 10)))
                            : null,
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
