import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'new_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrdersListScreen extends StatefulWidget {
  final int companyId;
  const PurchaseOrdersListScreen({super.key, required this.companyId});

  @override
  State<PurchaseOrdersListScreen> createState() => _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getPurchaseOrders(widget.companyId);
    setState(() {
      _orders = rows;
      _loading = false;
    });
  }

  Future<void> _openNew() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewPurchaseOrderScreen(companyId: widget.companyId),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PO Delete Karein?'),
        content: Text('"${po['po_number']}" delete ho jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deletePurchaseOrder(po['id'] as int);
      _load();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Abhi koi PO nahi bana'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _orders.length,
                    itemBuilder: (ctx, i) {
                      final po = _orders[i];
                      final status = po['status'] as String;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(status).withOpacity(0.15),
                            child: Icon(Icons.description_outlined,
                                color: _statusColor(status), size: 18),
                          ),
                          title: Text(po['po_number'] as String),
                          subtitle: Text(po['supplier_name'] as String? ?? 'Not Selected'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rs. ${(po['total_amount'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(status[0].toUpperCase() + status.substring(1),
                                  style: TextStyle(color: _statusColor(status), fontSize: 11)),
                            ],
                          ),
                          onLongPress: () => _confirmDelete(po),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PurchaseOrderDetailScreen(po: po),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.description_outlined),
        label: const Text('New PO'),
      ),
    );
  }
}
