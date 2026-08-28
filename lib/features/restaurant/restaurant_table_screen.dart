import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/theme/design_tokens.dart';

class RestaurantTableScreen extends StatefulWidget {
  final int companyId;
  final Function(Map<String, dynamic> selectedTable)? onTableSelected;

  const RestaurantTableScreen({
    super.key,
    required this.companyId,
    this.onTableSelected,
  });

  @override
  State<RestaurantTableScreen> createState() => _RestaurantTableScreenState();
}

class _RestaurantTableScreenState extends State<RestaurantTableScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final db = await DBHelper.instance.database;
    final rows = await db.query(
      'restaurant_tables',
      where: 'company_id = ?',
      whereArgs: [widget.companyId],
      orderBy: 'table_number ASC, table_name ASC',
    );

    setState(() {
      _tables = rows;
      _loading = false;
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['table_name'] ?? '');
    final numCtrl =
        TextEditingController(text: existing?['table_number'] ?? '');
    final capCtrl =
        TextEditingController(text: existing?['capacity']?.toString() ?? '4');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            existing == null ? 'Nayi Table Add Karein' : 'Table Edit Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Table Name (e.g. Table 01 / Family Hall)')),
            TextField(
                controller: numCtrl,
                decoration: const InputDecoration(
                    labelText: 'Table Number (e.g. T-01)')),
            TextField(
                controller: capCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Seating Capacity')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final db = await DBHelper.instance.database;
              final data = {
                'company_id': widget.companyId,
                'table_name': name,
                'table_number': numCtrl.text.trim(),
                'capacity': int.tryParse(capCtrl.text) ?? 4,
                'status': existing?['status'] ?? 'available',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              };

              if (existing != null) {
                await db.update('restaurant_tables', data,
                    where: 'id = ?', whereArgs: [existing['id']]);
              } else {
                await db.insert('restaurant_tables', data);
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadTables();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> table) async {
    final newStatus = table['status'] == 'occupied' ? 'available' : 'occupied';
    final db = await DBHelper.instance.database;
    await db.update(
      'restaurant_tables',
      {'status': newStatus, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [table['id']],
    );
    _loadTables();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Table Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Koi Restaurant Table nahi mila.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Table Add Karein'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _tables.length,
                  itemBuilder: (ctx, i) {
                    final t = _tables[i];
                    final isOccupied = t['status'] == 'occupied';

                    return InkWell(
                      onTap: () {
                        if (widget.onTableSelected != null) {
                          widget.onTableSelected!(t);
                          Navigator.pop(context);
                        } else {
                          _toggleStatus(t);
                        }
                      },
                      child: Card(
                        color: isOccupied
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: isOccupied ? Colors.orange : Colors.green,
                              width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.table_restaurant,
                                size: 36,
                                color: isOccupied
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                              ),
                              const SizedBox(height: 8),
                              Text(t['table_name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('Capacity: ${t['capacity']} persons',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      isOccupied ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOccupied ? 'OCCUPIED' : 'AVAILABLE',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
