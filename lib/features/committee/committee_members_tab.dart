import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class CommitteeMembersTab extends StatefulWidget {
  final int companyId;
  final int committeeId;
  const CommitteeMembersTab(
      {super.key, required this.companyId, required this.committeeId});

  @override
  State<CommitteeMembersTab> createState() => _CommitteeMembersTabState();
}

class _CommitteeMembersTabState extends State<CommitteeMembersTab> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows =
        await DBHelper.instance.getCommitteeMembers(widget.committeeId);
    setState(() {
      _members = rows;
      _loading = false;
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    DateTime joinDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Member Add Karein'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Naam *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Join Date: ${joinDate.toIso8601String().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: joinDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => joinDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DBHelper.instance.insertCommitteeMember({
                  'company_id': widget.companyId,
                  'committee_id': widget.committeeId,
                  'member_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'join_date': joinDate.toIso8601String(),
                  'has_drawn': 0,
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

  Future<void> _confirmDelete(Map<String, dynamic> m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Member Nikalein?'),
        content:
            Text('"${m['member_name']}" is committee se nikal diya jayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nikal Dein',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteCommitteeMember(m['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _members.isEmpty
          ? const Center(child: Text('Abhi koi member nahi hai'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _members.length,
              itemBuilder: (ctx, i) {
                final m = _members[i];
                final hasDrawn = (m['has_drawn'] as int) == 1;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: hasDrawn
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Text(
                        (m['member_name'] as String).isNotEmpty
                            ? (m['member_name'] as String)[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(m['member_name'] as String),
                    subtitle: Text(m['phone'] as String? ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDrawn)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text('Draw Ho Gaya',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 11)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(m),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
