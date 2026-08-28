import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/auth/session.dart';
import '../../core/utils/error_handler.dart';
import '../../core/providers/terminology_provider.dart';
import 'new_sale_screen.dart';
import 'sale_detail_screen.dart';
import '../shell/main_shell.dart';

class SalesHomeScreen extends StatefulWidget {
  final int companyId;
  const SalesHomeScreen({super.key, required this.companyId});

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  List<Map<String, dynamic>> _sales = [];
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
    await ErrorHandler.run(context, () async {
      final rows = await DBHelper.instance
          .getSales(widget.companyId, limit: _pageSize, offset: 0);
      if (mounted) {
        setState(() {
          _sales = rows;
          _hasMore = rows.length == _pageSize;
        });
      }
    }, onFinish: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _loadMore() async {
    final rows = await DBHelper.instance
        .getSales(widget.companyId, limit: _pageSize, offset: _sales.length);
    setState(() {
      _sales = [..._sales, ...rows];
      _hasMore = rows.length == _pageSize;
    });
  }

  Future<void> _openNewSale() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSaleScreen(companyId: widget.companyId),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmVoid(Map<String, dynamic> sale) async {
    if (sale['status'] == 'voided') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Void (Cancel) Karein?'),
        content: Text(
            '"${sale['invoice_number']}" cancel ho jayegi. Stock wapis barh jayega aur accounting entries reverse ho jayengi.'),
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
      await DBHelper.instance.voidSale(sale['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Sale',
        action: 'VOID',
        description: 'Sale void ki: ${sale['invoice_number']}',
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = context.watch<TerminologyProvider>();
    final saleLabel = term.get('sale');

    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: Text(saleLabel + 's'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(child: Text('Abhi koi $saleLabel nahi hui'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sales.length,
                    itemBuilder: (ctx, i) {
                      final sale = _sales[i];
                      final isVoided = sale['status'] == 'voided';
                      final isDue = (sale['sale_type'] as String) == 'due';
                      final due = (sale['due_amount'] as num).toDouble();
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
                          title: Text(sale['invoice_number'] as String,
                              style: TextStyle(
                                  decoration: isVoided
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isVoided ? Colors.grey : null)),
                          subtitle: Text(sale['customer_name'] as String? ??
                              'Walk-in Customer'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${(sale['total_amount'] as num).toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isVoided
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isVoided ? Colors.grey : null),
                              ),
                              if (!isVoided && Session.isOwner)
                                IconButton(
                                  icon: const Icon(Icons.block,
                                      size: 18, color: Colors.orange),
                                  onPressed: () => _confirmVoid(sale),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Void (Cancel)',
                                )
                              else if (isVoided)
                                const Text('VOIDED',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SaleDetailScreen(sale: sale),
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
        onPressed: _openNewSale,
        icon: const Icon(Icons.point_of_sale),
        label: Text('New $saleLabel'),
      ),
    );
  }
}
