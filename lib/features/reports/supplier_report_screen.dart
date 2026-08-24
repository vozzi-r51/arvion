import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';

class SupplierReportScreen extends StatefulWidget {
  final int companyId;
  const SupplierReportScreen({super.key, required this.companyId});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  double get _totalPayable =>
      _suppliers.fold(0.0, (sum, s) => sum + (s['current_balance'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getPayables(widget.companyId);
    setState(() {
      _suppliers = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Report (Payables)'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _export)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: Colors.purple.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text('Total Payable (aap ne dene wale)',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            'Rs. ${_totalPayable.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _suppliers.isEmpty
                      ? const Center(child: Text('Koi supplier due nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _suppliers.length,
                          itemBuilder: (ctx, i) {
                            final s = _suppliers[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Icon(Icons.local_shipping,
                                      color: Colors.white, size: 18),
                                ),
                                title: Text(s['company_name'] as String),
                                subtitle: Text(s['phone'] as String? ?? ''),
                                trailing: Text(
                                  'Rs. ${(s['current_balance'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.purple),
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


  Future<void> _export() async {
    await CsvExportService.exportAndShare(
      fileName: 'Supplier_Payables',
      headers: ['Supplier', 'Phone', 'Balance'],
      rows: _suppliers.map((s) => [s['company_name'], s['phone'], s['current_balance']]).toList(),
    );
  }
}