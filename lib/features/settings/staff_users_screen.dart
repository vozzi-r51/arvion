import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/rbac_service.dart';
import '../../core/database/db_helper.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_skeleton.dart';

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

  void _showStaffFormDialog([Map<String, dynamic>? staffToEdit]) {
    final isEditing = staffToEdit != null;
    final nameCtrl = TextEditingController(
        text: isEditing ? staffToEdit['name'] as String : '');
    final pinCtrl = TextEditingController();

    String selectedRole =
        isEditing ? (staffToEdit['role'] as String? ?? 'Cashier') : 'Cashier';
    Set<String> selectedPermissions = {};

    if (isEditing && staffToEdit['permissions'] != null) {
      try {
        final List list = jsonDecode(staffToEdit['permissions'] as String);
        selectedPermissions = list.map((e) => e.toString()).toSet();
      } catch (_) {}
    } else {
      selectedPermissions = DefaultRoles.getPermissionsForRole(selectedRole);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing
              ? 'Staff User Edit Karein'
              : 'Naya Staff User Add Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Staff Member Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: isEditing
                        ? 'Naya PIN (Khali chhodein agar purana rakhna ho)'
                        : 'Login PIN (4-6 Digits) *',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Role Template Choose Karein:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(
                        value: 'Manager',
                        child: Text(
                            'Manager (Full Access except Settings/Delete)')),
                    DropdownMenuItem(
                        value: 'Accountant',
                        child: Text('Accountant (Reports & Finance)')),
                    DropdownMenuItem(
                        value: 'Cashier',
                        child: Text('Cashier (Sales & Customers)')),
                    DropdownMenuItem(
                        value: 'Custom',
                        child: Text('Custom Role (Select Toggles)')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      selectedRole = val;
                      if (val != 'Custom') {
                        selectedPermissions =
                            DefaultRoles.getPermissionsForRole(val);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Permission Matrix (Granular Control):',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: AppPermissions.allPermissions.map((perm) {
                      final isGranted = selectedPermissions.contains(perm);
                      return CheckboxListTile(
                        dense: true,
                        activeColor: Theme.of(context).colorScheme.primary,
                        title: Text(AppPermissions.labels[perm] ?? perm,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(AppPermissions.descriptions[perm] ?? '',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                        value: isGranted,
                        onChanged: (bool? checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedPermissions.add(perm);
                            } else {
                              selectedPermissions.remove(perm);
                            }
                            selectedRole = 'Custom';
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty) return;
                if (!isEditing && pin.length < 4) return;

                final Map<String, dynamic> data = {
                  'company_id': widget.companyId,
                  'name': name,
                  'role': selectedRole,
                  'permissions': jsonEncode(selectedPermissions.toList()),
                  'created_at': DateTime.now().toIso8601String(),
                };

                if (pin.isNotEmpty) {
                  final hashed = AuthService.instance.hashNewPin(pin);
                  data['pin_hash'] = hashed.hash;
                  data['pin_salt'] = hashed.salt;
                }

                if (isEditing) {
                  final oldData = Map<String, dynamic>.from(staffToEdit);
                  await DBHelper.instance
                      .updateStaffUser(staffToEdit['id'] as int, data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Staff',
                    action: AuditLogger.update,
                    description:
                        'Staff member "$name" ka role/permissions update kiya',
                    beforeValue: {
                      'name': oldData['name'],
                      'role': oldData['role'],
                      'permissions': oldData['permissions']
                    },
                    afterValue: {
                      'name': name,
                      'role': selectedRole,
                      'permissions': jsonEncode(selectedPermissions.toList())
                    },
                  );
                } else {
                  await DBHelper.instance.insertStaffUser(data);
                  await AuditLogger.log(
                    companyId: widget.companyId,
                    module: 'Staff',
                    action: AuditLogger.create,
                    description:
                        'Naya staff member "$name" ($selectedRole) add kiya',
                    afterValue: {
                      'name': name,
                      'role': selectedRole,
                      'permissions': jsonEncode(selectedPermissions.toList())
                    },
                  );
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: Text(isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Staff Member Hatayein?'),
        content: Text('"${s['name']}" ka access aur PIN delete ho jayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.instance.deleteStaffUser(s['id'] as int);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Staff',
        action: AuditLogger.delete,
        description: 'Staff member "${s['name']}" ko delete kiya',
        beforeValue: {'name': s['name'], 'role': s['role']},
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Users & Role Matrix'),
      ),
      body: _loading
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            )
          : _staff.isEmpty
              ? AppEmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Koi Staff Member Add Nahi Hua',
                  message:
                      'Apne staff (Manager, Accountant, Cashier) ke liye alag PINs aur permissions set karein.',
                  actionLabel: 'Staff Add Karein',
                  onAction: () => _showStaffFormDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _staff.length,
                  itemBuilder: (ctx, i) {
                    final s = _staff[i];
                    final role = (s['role'] as String?) ?? 'Cashier';
                    Set<String> perms = {};
                    if (s['permissions'] != null) {
                      try {
                        final List l = jsonDecode(s['permissions'] as String);
                        perms = l.map((e) => e.toString()).toSet();
                      } catch (_) {}
                    }
                    if (perms.isEmpty) {
                      perms = DefaultRoles.getPermissionsForRole(role);
                    }

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                        side: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.15)),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          child: Text(s['name'][0].toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                        ),
                        title: Text(s['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Role: $role (${perms.length} Permissions Active)'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showStaffFormDialog(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => _confirmDelete(s),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: AppPermissions.allPermissions.map((p) {
                                final hasPerm = perms.contains(p);
                                return Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: hasPerm
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                                  avatar: Icon(
                                      hasPerm
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 14,
                                      color:
                                          hasPerm ? Colors.green : Colors.grey),
                                  label: Text(
                                    AppPermissions.labels[p] ?? p,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: hasPerm
                                            ? Colors.green.shade900
                                            : Colors.grey.shade600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Staff User'),
      ),
    );
  }
}
