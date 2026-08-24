import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';

class StockReportScreen extends StatefulWidget {
  final int companyId;
  const StockReportScreen({super.key, required this.companyId});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  List<Map<String, dynamic>> _products = [];
  double _valuation = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await DBHelper.instance.getProducts(widget.companyId);
    final valuation = await DBHelper.instance.getStockValuation(widget.companyId);
    products.sort((a, b) =>
        (a['current_stock'] as num).compareTo(b['current_stock'] as num));
    setState(() {
      _products = products;
      _valuation = valuation;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Report'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _export)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: Colors.brown.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text('Total Stock Valuation (Purchase Price)',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            'Rs. ${_valuation.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('Abhi koi product nahi bana'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _products.length,
                          itemBuilder: (ctx, i) {
                            final p = _products[i];
                            final stock = (p['current_stock'] as num);
                            final lowStock = stock <= (p['low_stock_level'] as num);
                            final value =
                                stock * (p['purchase_price'] as num);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  lowStock ? Icons.warning_amber : Icons.inventory_2_outlined,
                                  color: lowStock ? Colors.red : Colors.grey,
                                ),
                                title: Text(p['name'] as String),
                                subtitle: Text('Stock: $stock  •  Value: Rs. ${value.toStringAsFixed(0)}'),
                                trailing: lowStock
                                    ? const Text('Low Stock',
                                        style: TextStyle(color: Colors.red, fontSize: 12))
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }


  Future<void> _export() async {
    await CsvExportService.exportAndShare(
      fileName: 'Stock_Report',
      headers: ['Product', 'Stock', 'Purchase Price', 'Value'],
      rows: _products
          .map((p) => [p['name'], p['current_stock'], p['purchase_price'],
                (p['current_stock'] as num) * (p['purchase_price'] as num)])
          .toList(),
    );
  }
}