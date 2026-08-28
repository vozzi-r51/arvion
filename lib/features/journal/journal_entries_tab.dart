import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'new_journal_entry_screen.dart';

class JournalEntriesTab extends StatefulWidget {
  final int companyId;
  const JournalEntriesTab({super.key, required this.companyId});

  @override
  State<JournalEntriesTab> createState() => _JournalEntriesTabState();
}

class _JournalEntriesTabState extends State<JournalEntriesTab> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getJournalEntries(widget.companyId);
    setState(() {
      _entries = rows;
      _loading = false;
    });
  }

  Future<void> _openNew() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => NewJournalEntryScreen(companyId: widget.companyId)),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entry Delete Karein?'),
        content: Text(e['description'] as String),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteJournalEntry(e['id'] as int);
      _load();
    }
  }

  Future<void> _showLines(Map<String, dynamic> entry) async {
    final lines =
        await DBHelper.instance.getJournalEntryLines(entry['id'] as int);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry['description'] as String),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: lines
                .map((l) => ListTile(
                      dense: true,
                      title: Text(l['account_name'] as String),
                      trailing: Text((l['debit'] as num) > 0
                          ? 'Dr ${l['debit']}'
                          : 'Cr ${l['credit']}'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Band Karein')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('Abhi koi journal entry nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final e = _entries[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(e['description'] as String),
                        subtitle:
                            Text((e['entry_date'] as String).substring(0, 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(e),
                        ),
                        onTap: () => _showLines(e),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNew,
        child: const Icon(Icons.add),
      ),
    );
  }
}
