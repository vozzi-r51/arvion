import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';

class CustomerReportScreen extends StatefulWidget {
  final int companyId;
  const CustomerReportScreen({super.key, required this.companyId});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  double get _totalReceivable =>
      _customers.fold(0.0, (sum, c) => sum + (c['current_balance'] as num));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getReceivables(widget.companyId);
    setState(() {
      _customers = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Report (Receivables)'), actions: [IconButton(icon: const Icon(Icons.ios_share), onPressed: _export)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: Colors.red.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text('Total Receivable (aap ko milne wale)',
                              style: TextStyle(fontSize: 13)),
                          Text(
                            'Rs. ${_totalReceivable.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _customers.isEmpty
                      ? const Center(child: Text('Koi customer due nahi hai'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _customers.length,
                          itemBuilder: (ctx, i) {
                            final c = _customers[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    (c['name'] as String).isNotEmpty
                                        ? (c['name'] as String)[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(c['name'] as String),
                                subtitle: Text(c['mobile'] as String? ?? ''),
                                trailing: Text(
                                  'Rs. ${(c['current_balance'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.red),
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
      fileName: 'Customer_Receivables',
      headers: ['Customer', 'Mobile', 'Balance'],
      rows: _customers.map((c) => [c['name'], c['mobile'], c['current_balance']]).toList(),
    );
  }
}