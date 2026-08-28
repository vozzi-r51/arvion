import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import 'new_purchase_screen.dart';
import 'purchase_detail_screen.dart';
import '../shell/main_shell.dart';

class PurchasesHomeScreen extends StatefulWidget {
  final int companyId;
  const PurchasesHomeScreen({super.key, required this.companyId});

  @override
  State<PurchasesHomeScreen> createState() => _PurchasesHomeScreenState();
}

class _PurchasesHomeScreenState extends State<PurchasesHomeScreen> {
  List<Map<String, dynamic>> _purchases = [];
  bool _loading = true;
  static const _pageSize = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance
        .getPurchases(widget.companyId, limit: _pageSize, offset: 0);
    setState(() {
      _purchases = rows;
      _hasMore = rows.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    final rows = await DBHelper.instance.getPurchases(widget.companyId,
        limit: _pageSize, offset: _purchases.length);
    setState(() {
      _purchases = [..._purchases, ...rows];
      _hasMore = rows.length == _pageSize;
    });
  }

  Future<void> _openNewPurchase() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewPurchaseScreen(companyId: widget.companyId),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmVoid(Map<String, dynamic> purchase) async {
    if (purchase['status'] == 'voided') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchase Void (Cancel) Karein?'),
        content: Text(
            '"${purchase['invoice_number']}" cancel ho jayegi. Stock wapis kam ho jayega aur accounting entries reverse ho jayengi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Haan, Void Karein',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.voidPurchase(purchase['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Purchase',
        action: 'VOID',
        description: 'Purchase void ki: ${purchase['invoice_number']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Purchases'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? const Center(child: Text('Abhi koi purchase nahi hui'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _purchases.length,
                    itemBuilder: (ctx, i) {
                      final purchase = _purchases[i];
                      final isVoided = purchase['status'] == 'voided';
                      final isDue =
                          (purchase['purchase_type'] as String) == 'due';
                      final due = (purchase['due_amount'] as num).toDouble();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isVoided
                                ? Colors.grey.shade200
                                : (isDue && due > 0
                                    ? Colors.red.shade100
                                    : Colors.green.shade100),
                            child: Icon(
                              isVoided
                                  ? Icons.block
                                  : (isDue
                                      ? Icons.schedule
                                      : Icons.check_circle),
                              color: isVoided
                                  ? Colors.grey
                                  : (isDue && due > 0
                                      ? Colors.red
                                      : Colors.green),
                              size: 20,
                            ),
                          ),
                          title: Text(purchase['invoice_number'] as String,
                              style: TextStyle(
                                  decoration: isVoided
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isVoided ? Colors.grey : null)),
                          subtitle: Text(purchase['supplier_name'] as String? ??
                              'Not Selected'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${(purchase['total_amount'] as num).toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isVoided ? Colors.grey : null),
                              ),
                              if (!isVoided)
                                IconButton(
                                  icon: const Icon(Icons.block,
                                      size: 18, color: Colors.orange),
                                  onPressed: () => _confirmVoid(purchase),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Void (Cancel)',
                                )
                              else
                                const Text('VOIDED',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PurchaseDetailScreen(purchase: purchase),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: (!_loading && _hasMore)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                    onPressed: _loadMore, child: const Text('Aur Load Karein')),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPurchase,
        icon: const Icon(Icons.shopping_bag_outlined),
        label: const Text('New Purchase'),
      ),
    );
  }
}
