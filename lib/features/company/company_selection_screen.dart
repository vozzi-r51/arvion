import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../shell/main_shell.dart';
import 'company_profile_screen.dart';

class CompanySelectionScreen extends StatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  State<CompanySelectionScreen> createState() =>
      _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends State<CompanySelectionScreen> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final companies = await DBHelper.instance.getAllCompanies();
    setState(() {
      _companies = companies;
      _loading = false;
    });
  }

  Future<void> _selectCompany(int id) async {
    await DBHelper.instance.setActiveCompany(id);
    await AuditLogger.log(
      companyId: id,
      module: 'Login',
      action: AuditLogger.login,
      description: 'App open ki gayi',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _showAddCompanyDialog() {
    final nameController = TextEditingController();
    final ownerController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nayi Company Banayein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Company / Shop Naam'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(labelText: 'Owner Naam'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final id = await DBHelper.instance.insertCompany({
                'name': nameController.text.trim(),
                'owner_name': ownerController.text.trim(),
                'phone': phoneController.text.trim(),
                'is_active': 0,
                'created_at': DateTime.now().toIso8601String(),
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              await _loadCompanies();
              await _selectCompany(id);
            },
            child: const Text('Banayein'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCompany(Map<String, dynamic> company) async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Company Delete Karein?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '"${company['name']}" aur is company ka SAARA data (Products, Sales, Customers, sab kuch) '
                      'HAMESHA KE LIYE delete ho jayega. Ye action wapis NAHI ho sakta.'),
              const SizedBox(height: 12),
              Text('Confirm karne ke liye company ka naam type karein:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: company['name'] as String),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: nameCtrl.text.trim() == company['name']
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Hamesha Ke Liye Delete Karein',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await DBHelper.instance.deleteCompanyPermanently(company['id'] as int);
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Chunein')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Abhi koi company nahi bani.\nApni pehli company banayein.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddCompanyDialog,
                icon: const Icon(Icons.add),
                label: const Text('Company Banayein'),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _companies.length,
        itemBuilder: (ctx, i) {
          final c = _companies[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                Theme.of(context).colorScheme.primary,
                child: Text(
                  (c['name'] as String).isNotEmpty
                      ? (c['name'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(c['name'] as String),
              subtitle: Text(c['owner_name'] as String? ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompanyProfileScreen(companyId: c['id'] as int),
                      ),
                    ).then((_) => _loadCompanies());
                  } else if (value == 'delete') {
                    _confirmDeleteCompany(c);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Profile Edit Karein')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Karein', style: TextStyle(color: Colors.red))),
                ],
                child: (c['is_active'] as int) == 1
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.more_vert),
              ),
              onTap: () => _selectCompany(c['id'] as int),
            ),
          );
        },
      ),
      floatingActionButton: _companies.isEmpty
          ? null
          : FloatingActionButton(
        onPressed: _showAddCompanyDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}