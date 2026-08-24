import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'new_delivery_challan_screen.dart';
import 'challan_detail_screen.dart';

class ChallansListScreen extends StatefulWidget {
  final int companyId;
  const ChallansListScreen({super.key, required this.companyId});

  @override
  State<ChallansListScreen> createState() => _ChallansListScreenState();
}

class _ChallansListScreenState extends State<ChallansListScreen> {
  List<Map<String, dynamic>> _challans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getChallans(widget.companyId);
    setState(() {
      _challans = rows;
      _loading = false;
    });
  }

  Future<void> _openNew() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewDeliveryChallanScreen(companyId: widget.companyId),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Challan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _challans.isEmpty
              ? const Center(child: Text('Abhi koi challan nahi bana'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _challans.length,
                    itemBuilder: (ctx, i) {
                      final c = _challans[i];
                      final isDelivered = c['delivery_status'] == 'delivered';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (isDelivered ? Colors.green : Colors.orange).shade100,
                            child: Icon(
                              isDelivered ? Icons.check_circle : Icons.local_shipping,
                              color: isDelivered ? Colors.green : Colors.orange,
                              size: 18,
                            ),
                          ),
                          title: Text(c['challan_number'] as String),
                          subtitle: Text(
                              '${c['customer_name'] ?? 'Walk-in Customer'}  •  ${(c['challan_date'] as String).substring(0, 10)}'),
                          trailing: Text(
                            isDelivered ? 'Delivered' : 'Pending',
                            style: TextStyle(
                                color: isDelivered ? Colors.green : Colors.orange,
                                fontSize: 12),
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChallanDetailScreen(challan: c),
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
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('New Challan'),
      ),
    );
  }
}
