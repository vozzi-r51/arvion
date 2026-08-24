import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';
import 'date_range_bar.dart';

class PurchaseReportScreen extends StatefulWidget {
  final int companyId;
  const PurchaseReportScreen({super.key, required this.companyId});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _purchases = [];
  bool _loading = true;

  double get _totalPurchases =>
      _purchases.fold(0.0, (sum, p) => sum + (p['total_amount'] as num));
  double get _totalDue =>
      _purchases.fold(0.0, (sum, p) => sum + (p['due_amount'] as num));

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance
        .getPurchasesBetween(widget.companyId, _iso(_from), _iso(_to));
    setState(() {
      _purchases = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Report'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _export)]),
      body: Column(
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            onFromChanged: (d) {
              setState(() => _from = d);
              _load();
            },
            onToChanged: (d) {
              setState(() => _to = d);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    child: _summaryCard(
                        'Total Purchase', _totalPurchases, Colors.indigo)),
                const SizedBox(width: 10),
                Expanded(
                    child: _summaryCard('Total Due', _totalDue, Colors.red)),
                const SizedBox(width: 10),
                Expanded(
                    child: _summaryCard(
                        'Invoices', _purchases.length.toDouble(), Colors.blue,
                        isCount: true)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _purchases.isEmpty
                    ? const Center(child: Text('Is range mein koi purchase nahi hui'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _purchases.length,
                        itemBuilder: (ctx, i) {
                          final p = _purchases[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p['invoice_number'] as String),
                              subtitle: Text(
                                  '${(p['purchase_date'] as String).substring(0, 10)}  •  ${p['supplier_name'] ?? 'Not Selected'}'),
                              trailing: Text(
                                'Rs. ${(p['total_amount'] as num).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double value, Color color, {bool isCount = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              isCount ? value.toStringAsFixed(0) : 'Rs. ${value.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _export() async {
    await CsvExportService.exportAndShare(
      fileName: 'Purchase_Report',
      headers: ['Invoice', 'Date', 'Supplier', 'Total', 'Due'],
      rows: _purchases
          .map((p) => [p['invoice_number'], (p['purchase_date'] as String).substring(0, 10),
                p['supplier_name'] ?? 'Not Selected', p['total_amount'], p['due_amount']])
          .toList(),
    );
  }
}