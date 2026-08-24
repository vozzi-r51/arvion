import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class ChallanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> challan;
  const ChallanDetailScreen({super.key, required this.challan});

  @override
  State<ChallanDetailScreen> createState() => _ChallanDetailScreenState();
}

class _ChallanDetailScreenState extends State<ChallanDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  late String _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _status = widget.challan['delivery_status'] as String;
    _load();
  }

  Future<void> _load() async {
    final items = await DBHelper.instance.getChallanItems(widget.challan['id'] as int);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markDelivered() async {
    await DBHelper.instance.updateChallanStatus(widget.challan['id'] as int, 'delivered');
    setState(() => _status = 'delivered');
  }

  @override
  Widget build(BuildContext context) {
    final challan = widget.challan;
    final signaturePath = challan['signature_path'] as String?;
    final isDelivered = _status == 'delivered';

    return Scaffold(
      appBar: AppBar(title: Text(challan['challan_number'] as String)),
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
                        Text('Customer: ${challan['customer_name'] ?? 'Walk-in Customer'}'),
                        Text('Date: ${(challan['challan_date'] as String).substring(0, 10)}'),
                        if ((challan['delivery_address'] as String?)?.isNotEmpty == true)
                          Text('Address: ${challan['delivery_address']}'),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(isDelivered ? 'Delivered' : 'Pending'),
                          backgroundColor:
                              (isDelivered ? Colors.green : Colors.orange).withOpacity(0.15),
                          labelStyle: TextStyle(color: isDelivered ? Colors.green : Colors.orange),
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
                        trailing: Text('Qty: ${it['quantity']}'),
                      ),
                    )),
                if (signaturePath != null && File(signaturePath).existsSync()) ...[
                  const SizedBox(height: 16),
                  Text('Customer Signature', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.file(File(signaturePath)),
                  ),
                ],
                if (!isDelivered) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _markDelivered,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Delivered Mark Karein'),
                  ),
                ],
              ],
            ),
    );
  }
}
