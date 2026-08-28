import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class CommitteeDrawsTab extends StatefulWidget {
  final int companyId;
  final int committeeId;
  final double defaultAmount;
  const CommitteeDrawsTab({
    super.key,
    required this.companyId,
    required this.committeeId,
    required this.defaultAmount,
  });

  @override
  State<CommitteeDrawsTab> createState() => _CommitteeDrawsTabState();
}

class _CommitteeDrawsTabState extends State<CommitteeDrawsTab> {
  List<Map<String, dynamic>> _draws = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final draws = await DBHelper.instance.getCommitteeDraws(widget.committeeId);
    final members =
        await DBHelper.instance.getCommitteeMembers(widget.committeeId);
    setState(() {
      _draws = draws;
      _members = members;
      _loading = false;
    });
  }

  void _showRecordDialog() {
    final undrawnMembers =
        _members.where((m) => (m['has_drawn'] as int) == 0).toList();
    if (undrawnMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Sab members already draw kar chuke hain (ya koi member nahi hai)')),
      );
      return;
    }

    int selectedMemberId = undrawnMembers.first['id'] as int;
    final amountCtrl =
        TextEditingController(text: widget.defaultAmount.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    DateTime drawDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Draw Record Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedMemberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: undrawnMembers
                      .map((m) => DropdownMenuItem<int>(
                            value: m['id'] as int,
                            child: Text(m['member_name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMemberId = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Amount (Rs.) *'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Date: ${drawDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: drawDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => drawDate = picked);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                await DBHelper.instance.insertCommitteeDraw({
                  'company_id': widget.companyId,
                  'committee_id': widget.committeeId,
                  'member_id': selectedMemberId,
                  'amount': amount,
                  'draw_date': drawDate.toIso8601String(),
                  'notes': notesCtrl.text.trim(),
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

  String _memberName(int memberId) {
    final match = _members.where((m) => m['id'] == memberId);
    return match.isNotEmpty ? match.first['member_name'] as String : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _draws.isEmpty
          ? const Center(child: Text('Abhi koi draw nahi hua'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _draws.length,
              itemBuilder: (ctx, i) {
                final d = _draws[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.emoji_events,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(_memberName(d['member_id'] as int)),
                    subtitle: Text(
                        '${(d['draw_date'] as String).substring(0, 10)}  •  ${d['notes'] ?? ''}'),
                    trailing: Text(
                      'Rs. ${(d['amount'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecordDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
