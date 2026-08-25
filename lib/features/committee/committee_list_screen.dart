import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/error_handler.dart';
import 'committee_detail_screen.dart';

class CommitteeListScreen extends StatefulWidget {
  final int companyId;
  const CommitteeListScreen({super.key, required this.companyId});

  @override
  State<CommitteeListScreen> createState() => _CommitteeListScreenState();
}

class _CommitteeListScreenState extends State<CommitteeListScreen> {
  List<Map<String, dynamic>> _committees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ErrorHandler.run(context, () async {
      final rows = await DBHelper.instance.getCommittees(widget.companyId);
      if (mounted) {
        setState(() => _committees = rows);
      }
    }, onFinish: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _showForm() {
    final nameCtrl = TextEditingController();
    final installmentCtrl = TextEditingController();
    final membersCtrl = TextEditingController();
    DateTime startDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nayi Committee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Committee Naam *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: installmentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Monthly Installment (Rs.) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: membersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Members *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Start Date: ${startDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final installment = double.tryParse(installmentCtrl.text.trim());
                final members = int.tryParse(membersCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty || installment == null || members == null || members <= 0) {
                  return;
                }
                await DBHelper.instance.insertCommittee({
                  'company_id': widget.companyId,
                  'name': nameCtrl.text.trim(),
                  'monthly_installment': installment,
                  'total_members': members,
                  'start_date': startDate.toIso8601String(),
                  'duration_months': members,
                  'status': 'active',
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Committee Delete Karein?'),
        content: Text('"${c['name']}" delete ho jayegi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ErrorHandler.run(context, () async {
        await DBHelper.instance.deleteCommittee(c['id'] as int);
        _load();
      }, errorTitle: 'Delete fail ho gaya');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Committee (BC System)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _committees.isEmpty
              ? const Center(child: Text('Abhi koi committee nahi bani'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _committees.length,
                  itemBuilder: (ctx, i) {
                    final c = _committees[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Icon(Icons.groups, color: Colors.white, size: 18),
                        ),
                        title: Text(c['name'] as String),
                        subtitle: Text(
                            '${c['total_members']} members  •  Rs. ${c['monthly_installment']}/month'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(c),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommitteeDetailScreen(
                                  companyId: widget.companyId, committee: c),
                            ),
                          );
                          _load();
                        },
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
