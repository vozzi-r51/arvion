import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/cost_center.dart';
import '../../core/repositories/cost_center_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_skeleton.dart';

class CostCentersScreen extends StatefulWidget {
  final int companyId;
  const CostCentersScreen({super.key, required this.companyId});

  @override
  State<CostCentersScreen> createState() => _CostCentersScreenState();
}

class _CostCentersScreenState extends State<CostCentersScreen> {
  List<CostCenter> _costCenters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = sl<CostCenterRepository>();
    final list = await repo.listCostCenters(widget.companyId);
    setState(() {
      _costCenters = list;
      _loading = false;
    });
  }

  void _showFormDialog([CostCenter? existing]) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: isEditing ? existing.name : '');
    final codeCtrl = TextEditingController(text: isEditing ? existing.code : 'BR-00${_costCenters.length + 1}');
    final descCtrl = TextEditingController(text: isEditing ? existing.description : '');
    String selectedType = isEditing ? existing.type : 'branch';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Cost Center / Branch Edit Karein' : 'Naya Cost Center / Branch Add Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name (e.g. Karachi Branch) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Code (e.g. BR-001) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'branch', child: Text('Branch')),
                    DropdownMenuItem(value: 'department', child: Text('Department')),
                    DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                    DropdownMenuItem(value: 'store', child: Text('Store Outlet')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (name.isEmpty || code.isEmpty) return;

                final repo = sl<CostCenterRepository>();
                if (isEditing) {
                  await repo.updateCostCenter(
                    existing.id,
                    name: name,
                    description: descCtrl.text.trim(),
                  );
                } else {
                  await repo.createCostCenter(
                    companyId: widget.companyId,
                    code: code,
                    name: name,
                    type: selectedType,
                    description: descCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cost Centers & Branches')),
      body: _loading
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            )
          : _costCenters.isEmpty
              ? AppEmptyState(
                  icon: Icons.store_outlined,
                  title: 'Koi Branch / Cost Center Add Nahi Hua',
                  message: 'Apni shop ki branches, warehouses ya departments add karein taake har sale/expense branch-wise track ho.',
                  actionLabel: 'Branch Add Karein',
                  onAction: () => _showFormDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _costCenters.length,
                  itemBuilder: (ctx, i) {
                    final cc = _costCenters[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.location_city_outlined, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(cc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Code: ${cc.code} • Type: ${cc.type.toUpperCase()}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showFormDialog(cc),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Branch / Cost Center'),
      ),
    );
  }
}
