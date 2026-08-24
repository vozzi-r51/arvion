import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class CategoryListScreen extends StatefulWidget {
  final int companyId;
  const CategoryListScreen({super.key, required this.companyId});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getCategories(widget.companyId);
    setState(() {
      _categories = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final urduCtrl =
        TextEditingController(text: existing?['urdu_name'] as String? ?? '');
    final codeCtrl = TextEditingController(text: existing?['code'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nayi Category' : 'Category Edit Karein'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Category Naam *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urduCtrl,
                decoration: const InputDecoration(labelText: 'Urdu Naam'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final data = {
                'company_id': widget.companyId,
                'name': nameCtrl.text.trim(),
                'urdu_name': urduCtrl.text.trim(),
                'code': codeCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'status': 'active',
                'created_at': DateTime.now().toIso8601String(),
              };
              if (existing == null) {
                await DBHelper.instance.insertCategory(data);
              } else {
                await DBHelper.instance.updateCategory(existing['id'] as int, data);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Category Delete Karein?'),
        content: Text('"${c['name']}" delete ho jayegi.'),
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
      await DBHelper.instance.deleteCategory(c['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('Abhi koi category nahi bani'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final c = _categories[i];
                    return Card(
                      child: ListTile(
                        title: Text(c['name'] as String),
                        subtitle: (c['urdu_name'] as String?)?.isNotEmpty == true
                            ? Text(c['urdu_name'] as String)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showForm(existing: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(c),
                            ),
                          ],
                        ),
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
