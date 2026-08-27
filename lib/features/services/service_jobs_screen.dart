import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../sales/new_sale_screen.dart';

class ServiceJobsScreen extends StatefulWidget {
  final int companyId;
  const ServiceJobsScreen({super.key, required this.companyId});

  @override
  State<ServiceJobsScreen> createState() => _ServiceJobsScreenState();
}

class _ServiceJobsScreenState extends State<ServiceJobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getServiceJobs(widget.companyId);
    setState(() {
      _jobs = rows;
      _loading = false;
    });
  }

  void _showForm() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<Map<String, dynamic>> customers = await DBHelper.instance.getCustomers(widget.companyId);
    int? selectedCustomerId;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Service Job / Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  value: selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'Customer (Optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Walk-in Customer')),
                    ...customers.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))),
                  ],
                  onChanged: (v) => setState(() => selectedCustomerId = v),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Service Description * (e.g. Haircut, Engine Repair)'),
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimated Amount (Rs.)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) return;
                String? customerName;
                if (selectedCustomerId != null) {
                  customerName = customers.firstWhere((c) => c['id'] == selectedCustomerId)['name'] as String;
                }
                await DBHelper.instance.insertServiceJob({
                  'company_id': widget.companyId,
                  'customer_id': selectedCustomerId,
                  'customer_name': customerName,
                  'service_description': descCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0,
                  'status': 'pending',
                  'scheduled_date': DateTime.now().toIso8601String(),
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    await DBHelper.instance.updateServiceJobStatus(id, newStatus);
    _load();
  }

  Future<void> _createInvoiceForJob(Map<String, dynamic> job) async {
    // Navigate to sale screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSaleScreen(companyId: widget.companyId),
      ),
    ).then((_) => _load());
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'done': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Jobs / Appointments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(child: Text('No service jobs created yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _jobs.length,
                  itemBuilder: (ctx, i) {
                    final j = _jobs[i];
                    final status = j['status'] as String;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Job #${j['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(j['service_description'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            if (j['customer_name'] != null) Text('Customer: ${j['customer_name']}'),
                            Text('Est. Amount: Rs. ${j['amount']}'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (status == 'pending')
                                  TextButton(
                                    onPressed: () => _updateStatus(j['id'] as int, 'in_progress'),
                                    child: const Text('Start Job'),
                                  ),
                                if (status == 'in_progress')
                                  TextButton(
                                    onPressed: () => _updateStatus(j['id'] as int, 'done'),
                                    child: const Text('Mark Done'),
                                  ),
                                if (status == 'done')
                                  ElevatedButton.icon(
                                    onPressed: () => _createInvoiceForJob(j),
                                    icon: const Icon(Icons.receipt_long, size: 16),
                                    label: const Text('Create Bill / Sale'),
                                  ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
