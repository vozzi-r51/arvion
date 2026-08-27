import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/customer_repository.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_empty_state.dart';
import 'customer_form_screen.dart';
import '../ledger/customer_ledger_screen.dart';
import '../shell/main_shell.dart';

class CustomerListScreen extends StatefulWidget {
  final int companyId;
  const CustomerListScreen({super.key, required this.companyId});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasMore = true;
    });
    await ErrorHandler.run(context, () async {
      final rows = await sl<CustomerRepository>().listCustomers(
        widget.companyId,
        searchQuery: _query,
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _customers = rows;
          _hasMore = rows.length == _pageSize;
        });
      }
    }, onFinish: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    final rows = await sl<CustomerRepository>().listCustomers(
      widget.companyId,
      searchQuery: _query,
      limit: _pageSize,
      offset: _customers.length,
    );

    if (mounted) {
      setState(() {
        _customers.addAll(rows);
        _loadingMore = false;
        _hasMore = rows.length == _pageSize;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(companyId: widget.companyId, existing: existing),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openLedger(Map<String, dynamic> customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLedgerScreen(
          customer: customer,
          companyId: widget.companyId,
        ),
      ),
    );
    _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Delete Karein?'),
        content: Text('"${c['name']}" delete ho jayega. Baad mein Recycle Bin se restore ho sakta hai.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ErrorHandler.run(context, () async {
        await sl<CustomerRepository>().deleteCustomer(c['id'] as int);
        await AuditLogger.log(
          companyId: widget.companyId,
          module: 'Customer',
          action: AuditLogger.delete,
          description: 'Customer delete kiya: ${c['name']}',
          beforeValue: {'name': c['name']},
        );
        _load();
      }, errorTitle: 'Delete fail ho gaya');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Customers (Paginated)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Naam ya mobile se search karein',
                border: OutlineInputBorder(borderRadius: AppRadius.medium),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => AppSkeleton.listTile(),
                  )
                : _customers.isEmpty
                    ? AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'Abhi koi customer nahi bana',
                        message: _query.isEmpty
                            ? 'Apni shop ke customers add karein taake udhaar aur loyalty points track ho sakein.'
                            : 'Aapki search ke mutabiq koi customer nahi mila.',
                        actionLabel: _query.isEmpty ? 'Naya Customer' : null,
                        onAction: _query.isEmpty ? () => _openForm() : null,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                        itemCount: _customers.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _customers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final c = _customers[i];
                          final balance = (c['current_balance'] as num).toDouble();
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: AppSpacing.m),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.medium,
                              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                child: Text(
                                  (c['name'] as String).isNotEmpty ? (c['name'] as String)[0].toUpperCase() : '?',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${c['mobile'] ?? ''}  •  ${c['customer_type'] ?? ''}\nBalance: ${balance.toStringAsFixed(0)}',
                                style: TextStyle(color: balance > 0 ? Colors.red : Colors.green),
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => _openLedger(c),
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (_) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.history),
                                          title: const Text('Ledger Dekhein'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _openLedger(c);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.edit_outlined),
                                          title: const Text('Edit Karein'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _openForm(existing: c);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete_outline, color: Colors.red),
                                          title: const Text('Delete Karein', style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _confirmDelete(c);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
