import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/fixed_assets_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_skeleton.dart';

class FixedAssetsScreen extends StatefulWidget {
  final int companyId;
  const FixedAssetsScreen({super.key, required this.companyId});

  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = sl<FixedAssetsRepository>();
    final list = await repo.listAssets(widget.companyId);
    setState(() {
      _assets = list;
      _loading = false;
    });
  }

  void _showAddAssetDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'AST-00${_assets.length + 1}');
    final costCtrl = TextEditingController();
    final salvageCtrl = TextEditingController(text: '0');
    final lifeYearsCtrl = TextEditingController(text: '5');
    String category = 'equipment';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Fixed Asset Register Karein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Asset Name (e.g. Delivery Van) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Asset Tag Code (e.g. AST-001) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'equipment', child: Text('Machinery & Equipment')),
                    DropdownMenuItem(value: 'furniture', child: Text('Furniture & Fixtures')),
                    DropdownMenuItem(value: 'vehicle', child: Text('Vehicles')),
                    DropdownMenuItem(value: 'computers', child: Text('Computers & Electronics')),
                    DropdownMenuItem(value: 'building', child: Text('Building & Premises')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Purchase Cost (Rs.) *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: salvageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimated Salvage Value (Rs.)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lifeYearsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Useful Life Span (Years) *'),
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
                final cost = double.tryParse(costCtrl.text.trim());
                final salvage = double.tryParse(salvageCtrl.text.trim()) ?? 0.0;
                final years = int.tryParse(lifeYearsCtrl.text.trim()) ?? 5;

                if (name.isEmpty || code.isEmpty || cost == null || cost <= 0) return;

                await sl<FixedAssetsRepository>().createAsset({
                  'company_id': widget.companyId,
                  'asset_code': code,
                  'asset_name': name,
                  'category': category,
                  'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
                  'purchase_cost': cost,
                  'salvage_value': salvage,
                  'useful_life_years': years,
                  'depreciation_method': 'straight_line',
                  'status': 'active',
                });

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMonthlyDepreciation() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await sl<FixedAssetsRepository>().calculateAndRunMonthlyDepreciation(
      companyId: widget.companyId,
      periodDate: today,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${res['processedCount']} assets ki monthly depreciation (Rs. ${(res['totalDepreciation'] as double).toStringAsFixed(0)}) calculate aur GL mein auto-post ho gayi!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixed Assets & Depreciation'),
        actions: [
          TextButton.icon(
            onPressed: _assets.isEmpty ? null : _runMonthlyDepreciation,
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            label: const Text('Run Depreciation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (_, __) => AppSkeleton.listTile(),
            )
          : _assets.isEmpty
              ? AppEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'Koi Fixed Asset Register Nahi Hua',
                  message: 'Furniture, Vehicles, Machinery ya Equipment ko Register karein taake straight-line depreciation automatically calculate ho.',
                  actionLabel: 'Asset Register Karein',
                  onAction: _showAddAssetDialog,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _assets.length,
                  itemBuilder: (ctx, i) {
                    final a = _assets[i];
                    final cost = (a['purchase_cost'] as num).toDouble();
                    final accum = (a['accumulated_depreciation'] as num).toDouble();
                    final book = (a['book_value'] as num).toDouble();
                    final progress = cost > 0 ? (accum / cost) : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(a['asset_name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(a['asset_code'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Category: ${a['category'].toString().toUpperCase()} • Life: ${a['useful_life_years']} Years', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Purchase Cost', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('Rs. ${cost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Accumulated Dep.', style: TextStyle(fontSize: 11, color: Colors.red)),
                                  Text('Rs. ${accum.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Book Value', style: TextStyle(fontSize: 11, color: Colors.green)),
                                  Text('Rs. ${book.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ]),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              color: progress >= 0.9 ? Colors.red : Colors.indigo,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssetDialog,
        icon: const Icon(Icons.add),
        label: const Text('Register Asset'),
      ),
    );
  }
}
