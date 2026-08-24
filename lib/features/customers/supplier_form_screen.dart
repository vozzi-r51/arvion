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
    }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (_companyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Company naam zaroori hai')));
      return;
    }
    setState(() => _saving = true);

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
      'payment_terms': _paymentTermsCtrl.text.trim(),
      'status': 'active',
    };

    if (_isEditing) {
      await DBHelper.instance.updateSupplier(widget.existing!['id'] as int, data);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Supplier Edit Karein' : 'Naya Supplier')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _companyNameCtrl,
              decoration: const InputDecoration(labelText: 'Company Naam *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactCtrl,
              decoration: const InputDecoration(labelText: 'Contact Person'),
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
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ntnCtrl,
              decoration: const InputDecoration(labelText: 'NTN'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _openingBalanceCtrl,
                    enabled: !_isEditing,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance',
                      helperText: _isEditing ? 'Sirf naye supplier mein set hoti hai' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _paymentTermsCtrl,
                    decoration: const InputDecoration(labelText: 'Payment Terms'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Supplier Save Karein'),
            ),
          ],
        ),
      ),
    );
  }
}
