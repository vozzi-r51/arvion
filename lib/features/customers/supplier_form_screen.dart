import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';

class SupplierFormScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? existing;
  const SupplierFormScreen({super.key, required this.companyId, this.existing});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _companyNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ntnCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController(text: '0');
  final _paymentTermsCtrl = TextEditingController();
  final _paymentTermsCustomCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Dropdown choice: 0 = due-on-receipt, 1/2/3/4 = months, 5 = custom.
  int _paymentTermsChoice = 0;
  static const List<String> _paymentTermsPresets = [
    'Due on Receipt',
    'Net 1 Month (30 days)',
    'Net 2 Months (60 days)',
    'Net 3 Months (90 days)',
    'Net 4 Months (120 days)',
    'Custom',
  ];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _companyNameCtrl.text = e['company_name'] as String? ?? '';
      _contactCtrl.text = e['contact_person'] as String? ?? '';
      _phoneCtrl.text = e['phone'] as String? ?? '';
      _whatsappCtrl.text = e['whatsapp'] as String? ?? '';
      _addressCtrl.text = e['address'] as String? ?? '';
      _emailCtrl.text = e['email'] as String? ?? '';
      _ntnCtrl.text = e['ntn'] as String? ?? '';
      _openingBalanceCtrl.text = '${e['opening_balance'] ?? 0}';
      _paymentTermsCtrl.text = e['payment_terms'] as String? ?? '';
      // Map existing free-text to the closest preset, else Custom.
      final pt = _paymentTermsCtrl.text;
      final idx = _paymentTermsPresets.indexOf(pt);
      _paymentTermsChoice = idx >= 0 ? idx : 5;
      if (idx < 0) _paymentTermsCustomCtrl.text = pt;
    }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_companyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company naam zaroori hai')));
      return;
    }

    // --- DUPLICATE DETECTION ---
    final duplicate = await DBHelper.instance.findDuplicateSupplier(
      widget.companyId,
      _companyNameCtrl.text.trim(),
      _phoneCtrl.text.trim(),
      excludeId: widget.existing?['id'],
    );

    if (duplicate != null && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Supplier?'),
          content:
              Text('Is naam ya mobile se aik supplier pehle hi mojood hai:\n\n'
                  '${duplicate['company_name']} - ${duplicate['phone']}\n\n'
                  'Kya aap phir bhi naya supplier banana chahte hain?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nahi, Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Haan, Save Karein')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);

    // Resolve payment terms: either a preset label or the custom text.
    final String paymentTerms = _paymentTermsChoice == 5
        ? _paymentTermsCustomCtrl.text.trim()
        : _paymentTermsPresets[_paymentTermsChoice];

    final openingBalance = _num(_openingBalanceCtrl.text);
    final data = {
      'company_id': widget.companyId,
      'company_name': _companyNameCtrl.text.trim(),
      'contact_person': _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'ntn': _ntnCtrl.text.trim(),
      'opening_balance': openingBalance,
      'payment_terms': paymentTerms,
      'status': 'active',
    };

    if (_isEditing) {
      await DBHelper.instance
          .updateSupplier(widget.existing!['id'] as int, data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Supplier',
        action: AuditLogger.update,
        description: 'Supplier update kiya: ${data['company_name']}',
      );
    } else {
      data['current_balance'] = openingBalance;
      data['created_at'] = DateTime.now().toIso8601String();
      await DBHelper.instance.insertSupplier(data);
      await AuditLogger.log(
        companyId: widget.companyId,
        module: 'Supplier',
        action: AuditLogger.create,
        description: 'Naya supplier banaya: ${data['company_name']}',
      );
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _ntnCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _paymentTermsCustomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Supplier Edit Karein' : 'Naya Supplier')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _companyNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Company Naam *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Naam zaroori hai' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration:
                    const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  // Simple but conservative email regex.
                  final ok = RegExp(
                          r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$")
                      .hasMatch(v.trim());
                  return ok ? null : 'Sahi email address likhein (e.g. abc@example.com)';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ntnCtrl,
                decoration: const InputDecoration(labelText: 'NTN'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _openingBalanceCtrl,
                      enabled: !_isEditing,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Opening Balance',
                        helperText: _isEditing
                            ? 'Sirf naye supplier mein set hoti hai'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _paymentTermsChoice,
                      decoration: const InputDecoration(
                          labelText: 'Payment Terms'),
                      items: List.generate(_paymentTermsPresets.length,
                          (i) => DropdownMenuItem(
                                value: i,
                                child: Text(_paymentTermsPresets[i]),
                              )),
                      onChanged: (v) => setState(
                          () => _paymentTermsChoice = v ?? 0),
                    ),
                  ),
                ],
              ),
              if (_paymentTermsChoice == 5) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paymentTermsCustomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Payment Terms',
                    hintText: 'e.g. 50% advance, 50% on delivery',
                  ),
                  validator: (v) {
                    if (_paymentTermsChoice != 5) return null;
                    if (v == null || v.trim().isEmpty) {
                      return 'Custom terms likhein ya dropdown se koi preset chunein';
                    }
                    return null;
                  },
                ),
              ],
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
                    : const Text('Supplier Save Karein'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
