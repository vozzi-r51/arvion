import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';

class CustomerFormScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? existing;
  const CustomerFormScreen({super.key, required this.companyId, this.existing});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _urduCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController(text: '0');
  final _openingBalanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _customerType = 'Retail';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const _types = ['Retail', 'Wholesale', 'VIP'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _urduCtrl.text = e['urdu_name'] as String? ?? '';
      _mobileCtrl.text = e['mobile'] as String? ?? '';
      _whatsappCtrl.text = e['whatsapp'] as String? ?? '';
      _addressCtrl.text = e['address'] as String? ?? '';
      _cnicCtrl.text = e['cnic'] as String? ?? '';
      _creditLimitCtrl.text = '${e['credit_limit'] ?? 0}';
      _openingBalanceCtrl.text = '${e['opening_balance'] ?? 0}';
      _notesCtrl.text = e['notes'] as String? ?? '';
      _customerType = (e['customer_type'] as String?) ?? 'Retail';
    }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Customer naam zaroori hai')));
      return;
    }
    setState(() => _saving = true);

    final openingBalance = _num(_openingBalanceCtrl.text);
    final data = {
      'company_id': widget.companyId,
      'name': _nameCtrl.text.trim(),
      'urdu_name': _urduCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'cnic': _cnicCtrl.text.trim(),
      'credit_limit': _num(_creditLimitCtrl.text),
      'opening_balance': openingBalance,
      'customer_type': _customerType,
      'notes': _notesCtrl.text.trim(),
      'status': 'active',
    };

    try {
      if (_isEditing) {
        await DBHelper.instance.updateCustomer(widget.existing!['id'] as int, data);
        await AuditLogger.log(
          companyId: widget.companyId,
          module: 'Customer',
          action: AuditLogger.update,
          description: 'Customer update kiya: ${data['name']}',
        );
      } else {
        data['current_balance'] = openingBalance;
        data['created_at'] = DateTime.now().toIso8601String();
        await DBHelper.instance.insertCustomer(data);
        await AuditLogger.log(
          companyId: widget.companyId,
          module: 'Customer',
          action: AuditLogger.create,
          description: 'Naya customer banaya: ${data['name']}',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer save nahi ho saka: $error')),
      );
      return;
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urduCtrl.dispose();
    _mobileCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _cnicCtrl.dispose();
    _creditLimitCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Customer Edit Karein' : 'Naya Customer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Naam *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urduCtrl,
              decoration: const InputDecoration(labelText: 'Urdu Naam'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile'),
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
              controller: _cnicCtrl,
              decoration: const InputDecoration(labelText: 'CNIC'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _customerType,
              decoration: const InputDecoration(labelText: 'Customer Type'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _customerType = v ?? 'Retail'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _creditLimitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Credit Limit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _openingBalanceCtrl,
                    enabled: !_isEditing,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance',
                      helperText: _isEditing ? 'Sirf naye customer mein set hoti hai' : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
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
                  : const Text('Customer Save Karein'),
            ),
          ],
        ),
      ),
    );
  }
}
