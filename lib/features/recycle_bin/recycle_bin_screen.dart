import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class RecycleBinScreen extends StatelessWidget {
  final int companyId;
  const RecycleBinScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recycle Bin'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Customers'),
              Tab(text: 'Suppliers'),
              Tab(text: 'Employees'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecycleTab(
              companyId: companyId,
              nameKey: 'name',
              getDeleted: DBHelper.instance.getDeletedProducts,
              restore: DBHelper.instance.restoreProduct,
              permanentDelete: DBHelper.instance.permanentlyDeleteProduct,
            ),
            _RecycleTab(
              companyId: companyId,
              nameKey: 'name',
              getDeleted: DBHelper.instance.getDeletedCustomers,
              restore: DBHelper.instance.restoreCustomer,
              permanentDelete: DBHelper.instance.permanentlyDeleteCustomer,
            ),
            _RecycleTab(
              companyId: companyId,
              nameKey: 'company_name',
              getDeleted: DBHelper.instance.getDeletedSuppliers,
              restore: DBHelper.instance.restoreSupplier,
              permanentDelete: DBHelper.instance.permanentlyDeleteSupplier,
            ),
            _RecycleTab(
              companyId: companyId,
              nameKey: 'name',
              getDeleted: DBHelper.instance.getDeletedEmployees,
              restore: DBHelper.instance.restoreEmployee,
              permanentDelete: DBHelper.instance.permanentlyDeleteEmployee,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleTab extends StatefulWidget {
  final int companyId;
  final String nameKey;
  final Future<List<Map<String, dynamic>>> Function(int) getDeleted;
  final Future<void> Function(int) restore;
  final Future<void> Function(int) permanentDelete;

  const _RecycleTab({
    required this.companyId,
    required this.nameKey,
    required this.getDeleted,
    required this.restore,
    required this.permanentDelete,
  });

  @override
  State<_RecycleTab> createState() => _RecycleTabState();
}

class _RecycleTabState extends State<_RecycleTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await widget.getDeleted(widget.companyId);
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _confirmPermanentDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hamesha Ke Liye Delete Karein?'),
        content: const Text('Ye action wapis nahi ho sakta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Karein',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.permanentDelete(item['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty)
      return const Center(child: Text('Recycle bin khali hai'));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item[widget.nameKey] as String? ?? 'Unknown'),
            subtitle: Text(
                'Delete kiya: ${(item['deleted_at'] as String).substring(0, 10)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    await widget.restore(item['id'] as int);
                    _load();
                  },
                  child: const Text('Restore'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever,
                      color: Colors.red, size: 20),
                  onPressed: () => _confirmPermanentDelete(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
