import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../sales/new_sale_screen.dart';

class ServiceJobsScreen extends StatefulWidget {
  final int companyId;
  const ServiceJobsScreen({super.key, required this.companyId});

  @override
  State<ServiceJobsScreen> createState() => _ServiceJobsScreenState();
}

class _ServiceJobsScreenState extends State<ServiceJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DBHelper.instance.database;
    final jobs = await DBHelper.instance.getServiceJobs(widget.companyId);
    final emps = await db.query(
      'employees',
      where: 'company_id = ?',
      whereArgs: [widget.companyId],
    );

    setState(() {
      _jobs = jobs;
      _employees = emps;
      _loading = false;
    });
  }

  void _showForm() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<Map<String, dynamic>> customers =
        await DBHelper.instance.getCustomers(widget.companyId);

    int? selectedCustomerId;
    int? selectedTechId;
    DateTime scheduledDate = DateTime.now();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Service Job / Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  value: selectedCustomerId,
                  decoration:
                      const InputDecoration(labelText: 'Customer (Optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Walk-in Customer')),
                    ...customers.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name'] as String))),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedCustomerId = v),
                ),
                DropdownButtonFormField<int?>(
                  value: selectedTechId,
                  decoration: const InputDecoration(
                      labelText: 'Assign Technician (HR Employee)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Unassigned')),
                    ..._employees.map((e) => DropdownMenuItem(
                        value: e['id'] as int,
                        child: Text(
                            '${e['name']} (${e['designation'] ?? 'Technician'})'))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedTechId = v),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText:
                          'Service Description * (e.g. Haircut, AC Repair)'),
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Estimated Amount (Rs.)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Scheduled Date: ${DateFormatter.format(scheduledDate.toIso8601String().substring(0, 10), format: "dd/MM/yyyy")}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setDialogState(() => scheduledDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) return;
                String? customerName;
                if (selectedCustomerId != null) {
                  customerName = customers.firstWhere(
                      (c) => c['id'] == selectedCustomerId)['name'] as String;
                }
                final db = await DBHelper.instance.database;
                await db.insert('service_jobs', {
                  'company_id': widget.companyId,
                  'customer_id': selectedCustomerId,
                  'customer_name': customerName,
                  'technician_employee_id': selectedTechId,
                  'service_description': descCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0,
                  'status': 'pending',
                  'scheduled_date':
                      scheduledDate.toIso8601String().substring(0, 10),
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save Job'),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Jobs & Scheduling'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Job List'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Scheduled Calendar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJobListTab(),
                _buildCalendarTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildJobListTab() {
    if (_jobs.isEmpty) {
      return const Center(child: Text('No service jobs created yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _jobs.length,
      itemBuilder: (ctx, i) {
        final j = _jobs[i];
        final status = j['status'] as String? ?? 'pending';
        final techId = j['technician_employee_id'] as int?;

        String techName = 'Unassigned';
        if (techId != null && _employees.isNotEmpty) {
          final match =
              _employees.firstWhere((e) => e['id'] == techId, orElse: () => {});
          if (match.isNotEmpty) techName = match['name'] as String;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Job #${j['id']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(j['service_description'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (j['customer_name'] != null)
                  Text('Customer: ${j['customer_name']}'),
                Text('Technician: $techName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.indigo)),
                if (j['scheduled_date'] != null)
                  Text('Scheduled: ${j['scheduled_date']}'),
                Text('Est. Amount: Rs. ${j['amount']}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (status == 'pending')
                      TextButton(
                        onPressed: () =>
                            _updateStatus(j['id'] as int, 'in_progress'),
                        child: const Text('Start Job'),
                      ),
                    if (status == 'in_progress')
                      TextButton(
                        onPressed: () => _updateStatus(j['id'] as int, 'done'),
                        child: const Text('Mark Done'),
                      ),
                    if (status == 'done')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                    builder: (_) => NewSaleScreen(
                                        companyId: widget.companyId)),
                              )
                              .then((_) => _load());
                        },
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Create Bill / Sale'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarTab() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final j in _jobs) {
      final date =
          (j['scheduled_date'] as String? ?? 'Unscheduled').substring(0, 10);
      grouped.putIfAbsent(date, () => []).add(j);
    }

    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dates.length,
      itemBuilder: (ctx, i) {
        final date = dates[i];
        final dayJobs = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 18, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Text(date,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.indigo)),
                  const SizedBox(width: 8),
                  Chip(
                      label: Text('${dayJobs.length} jobs'),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact),
                ],
              ),
            ),
            ...dayJobs.map((j) {
              return Card(
                child: ListTile(
                  title: Text(j['service_description'] as String? ?? ''),
                  subtitle: Text(
                      'Customer: ${j['customer_name'] ?? "Walk-in"} • Status: ${j['status']}'),
                  trailing: Text('Rs. ${j['amount']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
