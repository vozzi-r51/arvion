import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'production_order_form_screen.dart';

class ProductionOrderListScreen extends StatefulWidget {
  final int companyId;
  const ProductionOrderListScreen({super.key, required this.companyId});

  @override
  State<ProductionOrderListScreen> createState() => _ProductionOrderListScreenState();
}

class _ProductionOrderListScreenState extends State<ProductionOrderListScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getProductionOrders(widget.companyId);
    setState(() {
      _orders = rows;
      _loading = false;
    });
  }

  Future<void> _startOrder(int id) async {
    try {
      await DBHelper.instance.startProductionOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Production Start ho gayi. Raw material deduct ho gaya.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start fail: $e')));
    }
  }

  Future<void> _completeOrder(int id) async {
    try {
      await DBHelper.instance.completeProductionOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Production Complete! Finished item stock mein add ho gaya.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Completion fail: $e')));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planned': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Koi production order nahi hai.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) {
                    final o = _orders[i];
                    final status = o['status'] as String;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Order #${o['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Item: ${o['finished_product_name']}', style: const TextStyle(fontSize: 15)),
                            Text('Produce Qty: ${o['quantity_to_produce']}'),
                            Text('Est. Material Cost: Rs. ${o['total_raw_material_cost']}'),
                            const SizedBox(height: 8),
                            if (status == 'planned')
                              ElevatedButton.icon(
                                onPressed: () => _startOrder(o['id'] as int),
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('Start Production (Deduct Stock)'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              ),
                            if (status == 'in_progress')
                              ElevatedButton.icon(
                                onPressed: () => _completeOrder(o['id'] as int),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Complete Production (Add FG Stock)'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductionOrderFormScreen(companyId: widget.companyId)),
          );
          if (res == true) _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
