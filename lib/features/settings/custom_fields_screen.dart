import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class CustomFieldsScreen extends StatefulWidget {
  final int companyId;
  const CustomFieldsScreen({super.key, required this.companyId});

  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  final List<String> _modules = ['product', 'customer', 'supplier', 'sale'];
  String _selectedModule = 'product';
  List<Map<String, dynamic>> _fields = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance
        .getCustomFieldDefinitions(widget.companyId, _selectedModule);
    setState(() {
      _fields = rows;
      _loading = false;
    });
  }

  void _showForm() {
    final nameCtrl = TextEditingController();
    String type = 'text';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Custom Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Field Name (e.g. Spice Level)'),
              ),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Field Type'),
                items: ['text', 'number', 'date', 'dropdown']
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? 'text'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DBHelper.instance.insertCustomFieldDefinition({
                  'company_id': widget.companyId,
                  'module': _selectedModule,
                  'field_name': nameCtrl.text.trim(),
                  'field_type': type,
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
      appBar: AppBar(title: const Text('Custom Fields Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedModule,
              decoration: const InputDecoration(labelText: 'Select Module'),
              items: _modules
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m.toUpperCase())))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedModule = v);
                  _load();
                }
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _fields.isEmpty
                    ? const Center(
                        child:
                            Text('No custom fields defined for this module.'))
                    : ListView.builder(
                        itemCount: _fields.length,
                        itemBuilder: (ctx, i) {
                          final f = _fields[i];
                          return ListTile(
                            title: Text(f['field_name'] as String),
                            subtitle: Text('Type: ${f['field_type']}'),
                            leading: const Icon(Icons.label_outline),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
