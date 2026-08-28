import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> po;
  const PurchaseOrderDetailScreen({super.key, required this.po});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  late String _status;
  bool _loading = true;

  static const _statusFlow = ['draft', 'approved', 'received'];

  @override
  void initState() {
    super.initState();
    _status = widget.po['status'] as String;
    _load();
  }

  Future<void> _load() async {
    final items =
        await DBHelper.instance.getPurchaseOrderItems(widget.po['id'] as int);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String status) async {
    await DBHelper.instance
        .updatePurchaseOrderStatus(widget.po['id'] as int, status);
    setState(() => _status = status);
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

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'received':
        return 'Received';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Draft';
    }
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;
    final currentIndex = _statusFlow.indexOf(_status);
    final nextStatus =
        (currentIndex >= 0 && currentIndex < _statusFlow.length - 1)
            ? _statusFlow[currentIndex + 1]
            : null;

    return Scaffold(
      appBar: AppBar(title: Text(po['po_number'] as String)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Supplier: ${po['supplier_name'] ?? 'Not Selected'}'),
                        Text(
                            'Date: ${(po['po_date'] as String).substring(0, 10)}'),
                        if ((po['notes'] as String?)?.isNotEmpty == true)
                          Text('Notes: ${po['notes']}'),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(_statusLabel(_status)),
                          backgroundColor:
                              _statusColor(_status).withOpacity(0.15),
                          labelStyle: TextStyle(color: _statusColor(_status)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._items.map((it) => Card(
                      child: ListTile(
                        title: Text(it['product_name'] as String),
                        subtitle:
                            Text('${it['quantity']} x Rs. ${it['unit_cost']}'),
                        trailing: Text(
                            'Rs. ${(it['total'] as num).toStringAsFixed(0)}'),
                      ),
                    )),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        'Rs. ${(po['total_amount'] as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                if (nextStatus != null)
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(nextStatus),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Mark as ${_statusLabel(nextStatus)}'),
                  ),
                if (_status != 'cancelled' && _status != 'received') ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus('cancelled'),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('PO Cancel Karein',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                  ),
                ],
                if (_status == 'received') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Jab maal aa jaye, isko Purchases tab mein ek normal Purchase ke tor par record karein taake stock aur supplier balance update ho.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
    );
  }
}
