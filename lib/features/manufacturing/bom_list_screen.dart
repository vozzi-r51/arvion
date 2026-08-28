import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import 'bom_form_screen.dart';

class BomListScreen extends StatefulWidget {
  final int companyId;
  const BomListScreen({super.key, required this.companyId});

  @override
  State<BomListScreen> createState() => _BomListScreenState();
}

class _BomListScreenState extends State<BomListScreen> {
  List<Map<String, dynamic>> _boms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getBoms(widget.companyId);
    setState(() {
      _boms = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill of Materials (BOM)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boms.isEmpty
              ? const Center(child: Text('Koi BOM nahi bani.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _boms.length,
                  itemBuilder: (ctx, i) {
                    final b = _boms[i];
                    return Card(
                      child: ListTile(
                        title: Text(b['name'] as String),
                        subtitle: Text(
                            'Finished Item: ${b['finished_product_name']} (Batch Qty: ${b['output_quantity']})'),
                        trailing: const Icon(Icons.precision_manufacturing,
                            color: Colors.indigo),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BomFormScreen(companyId: widget.companyId)),
          );
          if (res == true) _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
