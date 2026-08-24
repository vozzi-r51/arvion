import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class BrandListScreen extends StatefulWidget {
  final int companyId;
  const BrandListScreen({super.key, required this.companyId});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  List<Map<String, dynamic>> _brands = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getBrands(widget.companyId);
    setState(() {
      _brands = rows;
      _loading = false;
    });
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final urduCtrl =
        TextEditingController(text: existing?['urdu_name'] as String? ?? '');
    final companyCtrl =
        TextEditingController(text: existing?['company_name'] as String? ?? '');
    final countryCtrl =
        TextEditingController(text: existing?['country'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    bool featured = (existing?['featured'] as int? ?? 0) == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Naya Brand' : 'Brand Edit Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Brand Naam *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urduCtrl,
                  decoration: const InputDecoration(labelText: 'Urdu Naam'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(labelText: 'Company Naam'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: countryCtrl,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured Brand'),
                  value: featured,
                  onChanged: (v) => setDialogState(() => featured = v ?? false),
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
                  'company_name': companyCtrl.text.trim(),
                  'country': countryCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'featured': featured ? 1 : 0,
                  'status': 'active',
                  'created_at': DateTime.now().toIso8601String(),
                };
                if (existing == null) {
                  await DBHelper.instance.insertBrand(data);
                } else {
                  await DBHelper.instance.updateBrand(existing['id'] as int, data);
                }
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

  Future<void> _confirmDelete(Map<String, dynamic> b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brand Delete Karein?'),
        content: Text('"${b['name']}" delete ho jayega.'),
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
      await DBHelper.instance.deleteBrand(b['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _brands.isEmpty
              ? const Center(child: Text('Abhi koi brand nahi bana'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _brands.length,
                  itemBuilder: (ctx, i) {
                    final b = _brands[i];
                    return Card(
                      child: ListTile(
                        title: Text(b['name'] as String),
                        subtitle: Text(b['country'] as String? ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((b['featured'] as int) == 1)
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showForm(existing: b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(b),
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
