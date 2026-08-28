import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../shell/main_shell.dart';
import 'new_quotation_screen.dart';
import 'quotation_detail_screen.dart';

class QuotationListScreen extends StatefulWidget {
  final int companyId;
  const QuotationListScreen({super.key, required this.companyId});

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  List<Map<String, dynamic>> _quotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getQuotations(widget.companyId);
    setState(() {
      _quotes = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Quotations / Estimates'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quotes.isEmpty
              ? const Center(child: Text('Abhi koi quotation nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _quotes.length,
                  itemBuilder: (ctx, i) {
                    final q = _quotes[i];
                    return Card(
                      child: ListTile(
                        title: Text(q['quote_number']),
                        subtitle: Text(
                            '${q['customer_name'] ?? 'Walk-in'} • ${q['status'].toUpperCase()}'),
                        trailing: Text(
                            'Rs. ${(q['total_amount'] as num).toStringAsFixed(0)}'),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuotationDetailScreen(quotation: q),
                            ),
                          );
                          if (result == true) _load();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewQuotationScreen(companyId: widget.companyId),
            ),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quote'),
      ),
    );
  }
}
