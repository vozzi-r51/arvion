import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/auth/auth_service.dart';

class StaffUsersScreen extends StatefulWidget {
  final int companyId;
  const StaffUsersScreen({super.key, required this.companyId});

  @override
  State<StaffUsersScreen> createState() => _StaffUsersScreenState();
}

class _StaffUsersScreenState extends State<StaffUsersScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DBHelper.instance.getStaffUsers(widget.companyId);
    setState(() {
      _staff = rows;
      _loading = false;
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cashier / Staff Add Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Naam *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Cashier PIN (4-6 digit) *'),
            ),
            const Text(
              'Cashier is PIN se app kholega to seedha Dashboard + Sales tak hi access milega.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || pinCtrl.text.trim().length < 4) return;
              final hashed = AuthService.instance.hashNewPin(pinCtrl.text.trim());
              await DBHelper.instance.insertStaffUser({
                'company_id': widget.companyId,
                'name': nameCtrl.text.trim(),
                'pin_hash': hashed.hash,
                'pin_salt': hashed.salt,
                'role': 'cashier',
                'created_at': DateTime.now().toIso8601String(),
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Staff Hatayein?'),
        content: Text('"${s['name']}" ka PIN kaam karna band ho jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hatayein', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteStaffUser(s['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cashier / Staff PINs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? const Center(child: Text('Abhi koi cashier nahi bana'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _staff.length,
                  itemBuilder: (ctx, i) {
                    final s = _staff[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(s['name'] as String),
                        subtitle: const Text('Role: Cashier (Dashboard + Sales)'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDelete(s),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
