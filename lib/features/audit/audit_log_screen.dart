import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class AuditLogScreen extends StatefulWidget {
  final int companyId;
  const AuditLogScreen({super.key, required this.companyId});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _moduleFilter;
  String? _actionFilter;
  static const int _pageSize = 50;

  static const _modules = [
    'Login',
    'Product',
    'Customer',
    'Supplier',
    'Sale',
    'Purchase',
    'Expense',
    'Income',
    'Staff',
    'Stock',
    'Archive',
  ];

  static const _actions = ['login', 'create', 'update', 'delete', 'stock_change', 'archive'];

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
    final rows = await DBHelper.instance.getAuditLogs(
      widget.companyId,
      module: _moduleFilter,
      action: _actionFilter,
      limit: _pageSize,
      offset: 0,
    );
    setState(() {
      _logs = rows;
      _loading = false;
      _hasMore = rows.length == _pageSize;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    final rows = await DBHelper.instance.getAuditLogs(
      widget.companyId,
      module: _moduleFilter,
      action: _actionFilter,
      limit: _pageSize,
      offset: _logs.length,
    );

    setState(() {
      _logs.addAll(rows);
      _loadingMore = false;
      _hasMore = rows.length == _pageSize;
    });
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'stock_change':
        return Icons.inventory_2_outlined;
      case 'archive':
        return Icons.archive;
      default:
        return Icons.info_outline;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'login':
        return Colors.blue;
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      case 'stock_change':
        return Colors.brown;
      case 'archive':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showDiffDialog(Map<String, dynamic> log) {
    Map<String, dynamic> before = {};
    Map<String, dynamic> after = {};

    if (log['before_value'] != null) {
      try {
        before = Map<String, dynamic>.from(jsonDecode(log['before_value'] as String));
      } catch (_) {}
    }
    if (log['after_value'] != null) {
      try {
        after = Map<String, dynamic>.from(jsonDecode(log['after_value'] as String));
      } catch (_) {}
    }

    final allKeys = {...before.keys, ...after.keys}.toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_actionIcon(log['action'] as String), color: _actionColor(log['action'] as String)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Before & After State Diff', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log['description'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(1.4),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(padding: EdgeInsets.all(6), child: Text('Field', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Pehle (Before)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red))),
                      Padding(padding: EdgeInsets.all(6), child: Text('Abhi (After)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green))),
                    ],
                  ),
                  ...allKeys.map((key) {
                    final valBefore = before[key]?.toString() ?? '—';
                    final valAfter = after[key]?.toString() ?? '—';
                    final isChanged = valBefore != valAfter;

                    return TableRow(
                      decoration: BoxDecoration(
                        color: isChanged ? Colors.amber.shade50 : null,
                      ),
                      children: [
                        Padding(padding: const EdgeInsets.all(6), child: Text(key, style: TextStyle(fontWeight: isChanged ? FontWeight.bold : FontWeight.normal, fontSize: 11))),
                        Padding(padding: const EdgeInsets.all(6), child: Text(valBefore, style: TextStyle(fontSize: 11, color: isChanged ? Colors.red.shade800 : Colors.black87))),
                        Padding(padding: const EdgeInsets.all(6), child: Text(valAfter, style: TextStyle(fontSize: 11, color: isChanged ? Colors.green.shade800 : Colors.black87))),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log (Paginated)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _moduleFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Module', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Sab')),
                      ..._modules.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m))),
                    ],
                    onChanged: (v) {
                      setState(() => _moduleFilter = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _actionFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Action', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Sab')),
                      ..._actions.map((a) => DropdownMenuItem<String?>(value: a, child: Text(a))),
                    ],
                    onChanged: (v) {
                      setState(() => _actionFilter = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('Abhi koi log entry nahi hai'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _logs.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _logs.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final log = _logs[i];
                          final action = log['action'] as String;
                          final ts = (log['timestamp'] as String);
                          final userName = (log['user_name'] as String?) ?? 'Owner';
                          final hasDiff = log['before_value'] != null || log['after_value'] != null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _actionColor(action).withValues(alpha: 0.15),
                                child: Icon(_actionIcon(action), color: _actionColor(action), size: 18),
                              ),
                              title: Text(log['description'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                '${log['module']} • User: $userName • ${ts.length >= 16 ? ts.substring(0, 16).replaceFirst('T', ' ') : ts}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              trailing: hasDiff
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.difference, size: 14),
                                      label: const Text('Diff', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _showDiffDialog(log),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
