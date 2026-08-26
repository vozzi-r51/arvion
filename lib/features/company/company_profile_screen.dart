import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/database/db_helper.dart';
import '../../core/utils/image_generator.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'company_selection_screen.dart';

class CompanyProfileScreen extends StatefulWidget {
  final int companyId;
  const CompanyProfileScreen({super.key, required this.companyId});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ntnCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');

  String _businessType = 'Mixed';
  String _currency = 'Rs.';
  Color _brandingColor = AppTheme.primaryBlue;
  
  final Map<String, bool> _modules = {
    'Quotations': true,
    'Promotions': true,
    'HR': true,
    'Committee': true,
    'Cheque': true,
    'Expenses': true,
    'Accounting': true,
  };

  String? _logoPath;
  String? _stampPath;
  String? _signaturePath;

  bool _loading = true;
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final c = await DBHelper.instance.getCompanyById(widget.companyId);
    if (c != null) {
      _nameCtrl.text = c['name'] as String? ?? '';
      _ownerCtrl.text = c['owner_name'] as String? ?? '';
      _addressCtrl.text = c['address'] as String? ?? '';
      _phoneCtrl.text = c['phone'] as String? ?? '';
      _whatsappCtrl.text = c['whatsapp'] as String? ?? '';
      _emailCtrl.text = c['email'] as String? ?? '';
      _ntnCtrl.text = c['ntn_gst'] as String? ?? '';
      _footerCtrl.text = c['invoice_footer'] as String? ?? '';
      _detailsCtrl.text = c['company_details'] as String? ?? '';
      _taxCtrl.text = '${c['default_tax_percent'] ?? 0}';
      _businessType = c['business_type'] as String? ?? 'Mixed';
      _currency = c['currency_symbol'] as String? ?? 'Rs.';
      
      if (c['branding_color'] != null) {
        _brandingColor = Color(c['branding_color'] as int);
      }
      
      final modulesStr = c['enabled_modules'] as String?;
      if (modulesStr != null) {
        try {
          final List<dynamic> enabled = jsonDecode(modulesStr);
          for (var m in _modules.keys) {
            _modules[m] = enabled.contains(m);
          }
        } catch (_) {}
      }

      _logoPath = c['logo_path'] as String?;
      _stampPath = c['shop_stamp_path'] as String?;
      _signaturePath = c['signature_path'] as String?;
    }
    setState(() => _loading = false);
  }

  Future<String> _persistImage(XFile file, String prefix) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final assetsDir = Directory(p.join(docsDir.path, 'company_assets'));
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    final ext = p.extension(file.path);
    final fileName =
        '${prefix}_${widget.companyId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final savedPath = p.join(assetsDir.path, fileName);
    await File(file.path).copy(savedPath);
    return savedPath;
  }

  Future<void> _pickImage(String kind) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final savedPath = await _persistImage(picked, kind);
    setState(() {
      if (kind == 'logo') _logoPath = savedPath;
      if (kind == 'stamp') _stampPath = savedPath;
      if (kind == 'signature') _signaturePath = savedPath;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);

    final enabledModules = _modules.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    await DBHelper.instance.updateCompany(widget.companyId, {
      'name': _nameCtrl.text.trim(),
      'owner_name': _ownerCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'ntn_gst': _ntnCtrl.text.trim(),
      'invoice_footer': _footerCtrl.text.trim(),
      'company_details': _detailsCtrl.text.trim(),
      'default_tax_percent': double.tryParse(_taxCtrl.text.trim()) ?? 0,
      'business_type': _businessType,
      'currency_symbol': _currency,
      'branding_color': _brandingColor.value,
      'enabled_modules': jsonEncode(enabledModules),
      'logo_path': _logoPath,
      'shop_stamp_path': _stampPath,
      'signature_path': _signaturePath,
    });

    setState(() => _saving = false);
    if (!mounted) return;

    context.read<ThemeProvider>().setPrimaryColor(_brandingColor);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Company profile save ho gayi')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteCompany() async {
    final pinCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shop Delete Karein?', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kya aap waqai is shop ko mukammal tor par delete karna chahte hain? Tamam sales, products aur reports khatam ho jayengi.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Apna PIN likhein'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await AuthService.instance.verifyPin(pinCtrl.text.trim());
              if (ok) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              } else {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ghalat PIN')));
              }
            },
            child: const Text('Hamesha ke liye Delete karein'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DBHelper.instance.deleteCompanyPermanently(widget.companyId);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CompanySelectionScreen()),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete nahi ho saki: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _imagePickerTile(String label, String? path, String kind) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(kind),
          child: Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: path != null && File(path).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  )
                : const Icon(Icons.add_photo_alternate_outlined,
                    color: Colors.grey, size: 32),
          ),
        ),
        if (kind != 'signature') ...[
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: () async {
              final path = await showDialog<String>(
                context: context,
                builder: (ctx) => GeneratorDialog(
                  initialText: _nameCtrl.text.isEmpty ? "My Shop" : _nameCtrl.text,
                  isStamp: kind == 'stamp',
                ),
              );
              if (path != null) {
                setState(() {
                  if (kind == 'logo') _logoPath = path;
                  if (kind == 'stamp') _stampPath = path;
                });
              }
            },
            child: Text('Generate', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _ntnCtrl.dispose();
    _footerCtrl.dispose();
    _detailsCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _imagePickerTile('Logo', _logoPath, 'logo'),
                    _imagePickerTile('Shop Stamp', _stampPath, 'stamp'),
                    _imagePickerTile('Signature', _signaturePath, 'signature'),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Shop Naam *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ownerCtrl,
                  decoration: const InputDecoration(labelText: 'Owner Naam'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _whatsappCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'WhatsApp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _ntnCtrl,
                        decoration: const InputDecoration(labelText: 'NTN / GST'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _taxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Default Tax %'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footerCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Invoice Footer Text (jaise: Shukriya!)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Company Details (extra notes)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _businessType,
                        decoration: const InputDecoration(labelText: 'Business Type'),
                        items: ['Retail', 'Wholesale', 'Mixed'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _businessType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        items: ['Rs.', '\$', '€', '£', 'AED'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('App Branding Color', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _colorOption(const Color(0xFF2563EB)), // Default Blue
                      _colorOption(const Color(0xFF0D9488)), // Teal
                      _colorOption(const Color(0xFF7C3AED)), // Purple
                      _colorOption(const Color(0xFFDB2777)), // Pink
                      _colorOption(const Color(0xFFEA580C)), // Orange
                      _colorOption(const Color(0xFF16A34A)), // Green
                      _colorOption(const Color(0xFF1E293B)), // Charcoal
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Enabled Modules', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _modules.keys.map((key) => CheckboxListTile(
                      title: Text(key, style: const TextStyle(fontSize: 14)),
                      value: _modules[key],
                      onChanged: (v) => setState(() => _modules[key] = v!),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Profile Save Karein'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _deleteCompany,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete This Shop'),
                ),
              ],
            ),
    );
  }

  Widget _colorOption(Color color) {
    final isSelected = _brandingColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _brandingColor = color),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
