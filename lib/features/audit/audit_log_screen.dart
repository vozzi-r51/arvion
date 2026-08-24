import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class AuditLogScreen extends StatefulWidget {
  final int companyId;
  const AuditLogScreen({super.key, required this.companyId});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _moduleFilter;
  String? _actionFilter;

  static const _modules = [
    'Login',
    'Product',
    'Customer',
    'Supplier',
    'Sale',
    'Purchase',
    'Expense',
    'Income',
  ];

  static const _actions = ['login', 'create', 'update', 'delete', 'stock_change'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getAuditLogs(
      widget.companyId,
      module: _moduleFilter,
      action: _actionFilter,
    );
    setState(() {
      _logs = rows;
      _loading = false;
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _logs.length,
                        itemBuilder: (ctx, i) {
                          final log = _logs[i];
                          final action = log['action'] as String;
                          final ts = (log['timestamp'] as String);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _actionColor(action).withOpacity(0.15),
                                child: Icon(_actionIcon(action), color: _actionColor(action), size: 18),
                              ),
                              title: Text(log['description'] as String),
                              subtitle: Text(
                                  '${log['module']}  •  ${ts.substring(0, 16).replaceFirst('T', ' ')}'),
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
