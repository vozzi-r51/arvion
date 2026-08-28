import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'new_sales_return_screen.dart';

class SalesReturnsListScreen extends StatefulWidget {
  final int companyId;
  const SalesReturnsListScreen({super.key, required this.companyId});

  @override
  State<SalesReturnsListScreen> createState() => _SalesReturnsListScreenState();
}

class _SalesReturnsListScreenState extends State<SalesReturnsListScreen> {
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getSalesReturns(widget.companyId);
    setState(() {
      _returns = rows;
      _loading = false;
    });
  }

  Future<void> _openNew() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSalesReturnScreen(companyId: widget.companyId),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _returns.isEmpty
              ? const Center(child: Text('Abhi koi sales return nahi hui'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _returns.length,
                    itemBuilder: (ctx, i) {
                      final r = _returns[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.keyboard_return,
                                color: Colors.white, size: 18),
                          ),
                          title: Text(r['return_number'] as String),
                          subtitle: Text(
                              '${r['customer_name'] ?? 'Walk-in Customer'}  •  ${(r['return_date'] as String).substring(0, 10)}'),
                          trailing: Text(
                            'Rs. ${(r['total_amount'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.keyboard_return),
        label: const Text('New Return'),
      ),
    );
  }
}
