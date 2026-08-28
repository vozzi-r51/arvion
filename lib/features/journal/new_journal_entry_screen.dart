import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class _JournalLine {
  int? accountId;
  final debitCtrl = TextEditingController(text: '0');
  final creditCtrl = TextEditingController(text: '0');
}

class NewJournalEntryScreen extends StatefulWidget {
  final int companyId;
  const NewJournalEntryScreen({super.key, required this.companyId});

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  List<Map<String, dynamic>> _accounts = [];
  final List<_JournalLine> _lines = [_JournalLine(), _JournalLine()];
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  double get _totalDebit => _lines.fold(
      0.0, (sum, l) => sum + (double.tryParse(l.debitCtrl.text.trim()) ?? 0));
  double get _totalCredit => _lines.fold(
      0.0, (sum, l) => sum + (double.tryParse(l.creditCtrl.text.trim()) ?? 0));
  bool get _isBalanced =>
      _totalDebit > 0 && (_totalDebit - _totalCredit).abs() < 0.01;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DBHelper.instance.ensureChartOfAccounts(widget.companyId);
    final accounts =
        await DBHelper.instance.getChartOfAccounts(widget.companyId);
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description zaroori hai')));
      return;
    }
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Total Debit aur Total Credit barabar hone chahiye')),
      );
      return;
    }
    final validLines = _lines.where((l) =>
        l.accountId != null &&
        ((double.tryParse(l.debitCtrl.text.trim()) ?? 0) > 0 ||
            (double.tryParse(l.creditCtrl.text.trim()) ?? 0) > 0));
    if (validLines.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kam se kam 2 lines chahiye')));
      return;
    }

    setState(() => _saving = true);

    final entryData = {
      'company_id': widget.companyId,
      'entry_date': _date.toIso8601String(),
      'description': _descCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final linesData = validLines
        .map((l) => {
              'account_id': l.accountId,
              'debit': double.tryParse(l.debitCtrl.text.trim()) ?? 0,
              'credit': double.tryParse(l.creditCtrl.text.trim()) ?? 0,
            })
        .toList();

    await DBHelper.instance
        .insertJournalEntryWithLines(entry: entryData, lines: linesData);

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final line in _lines) {
      line.debitCtrl.dispose();
      line.creditCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Journal Entry')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description *'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Date: ${_date.toIso8601String().substring(0, 10)}'),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  const Divider(),
                  for (int i = 0; i < _lines.length; i++) _lineCard(i),
                  TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_JournalLine())),
                    icon: const Icon(Icons.add),
                    label: const Text('Line Add Karein'),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: Text(
                              'Total Debit: ${_totalDebit.toStringAsFixed(0)}')),
                      Flexible(
                          child: Text(
                              'Total Credit: ${_totalCredit.toStringAsFixed(0)}')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBalanced ? 'Balanced ✓' : 'Balanced nahi hai',
                    style: TextStyle(
                        color: _isBalanced ? Colors.green : Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Entry Save Karein'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _lineCard(int index) {
    final line = _lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: line.accountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Account', isDense: true),
                    items: _accounts
                        .map((a) => DropdownMenuItem<int>(
                            value: a['id'] as int,
                            child: Text(a['name'] as String)))
                        .toList(),
                    onChanged: (v) => setState(() => line.accountId = v),
                  ),
                ),
                if (_lines.length > 2)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _lines.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.debitCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Debit', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: line.creditCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Credit', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
