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
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController(text: '0');
  final _openingBalanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _customerType = 'Retail';
  String _selectedCountryCode = '+92 (PK)';
  String _paymentTerms = 'Immediate / Cash';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const _types = ['Retail', 'Wholesale', 'VIP'];
  static const _countryCodes = [
    '+92 (PK)',
    '+1 (US/CA)',
    '+971 (UAE)',
    '+966 (KSA)',
    '+44 (UK)',
    '+91 (IN)',
    '+61 (AU)',
  ];
  static const _paymentTermsOptions = [
    'Immediate / Cash',
    '1 Month (30 Days)',
    '2 Months (60 Days)',
    '3 Months (90 Days)',
    '4 Months (120 Days)',
    'Custom Terms',
  ];

  int get _maxPhoneDigits {
    if (_selectedCountryCode.contains('+92')) return 11;
    if (_selectedCountryCode.contains('+1')) return 10;
    if (_selectedCountryCode.contains('+971')) return 9;
    if (_selectedCountryCode.contains('+966')) return 9;
    if (_selectedCountryCode.contains('+44')) return 10;
    if (_selectedCountryCode.contains('+91')) return 10;
    return 12;
  }

  String get _idLabel {
    return _selectedCountryCode.contains('+92')
        ? 'CNIC (13 Digits)'
        : 'National ID / Tax ID (NTR / SSN / VAT)';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _urduCtrl.text = e['urdu_name'] as String? ?? '';
      _emailCtrl.text = e['email'] as String? ?? '';
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer naam zaroori hai')));
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      final emailValid =
          RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
      if (!emailValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Valid email address enter karein (e.g. example@gmail.com)')),
        );
        return;
      }
    }

    // --- DUPLICATE DETECTION ---
    final duplicate = await DBHelper.instance.findDuplicateCustomer(
      widget.companyId,
      _nameCtrl.text.trim(),
      _mobileCtrl.text.trim(),
      excludeId: widget.existing?['id'],
    );

    if (duplicate != null && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Customer?'),
          content:
              Text('Is naam ya mobile se aik customer pehle hi mojood hai:\n\n'
                  '${duplicate['name']} - ${duplicate['mobile']}\n\n'
                  'Kya aap phir bhi naya customer banana chahte hain?'),
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

    final openingBalance = _num(_openingBalanceCtrl.text);
    final data = {
      'company_id': widget.companyId,
      'name': _nameCtrl.text.trim(),
      'urdu_name': _urduCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
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
        await DBHelper.instance
            .updateCustomer(widget.existing!['id'] as int, data);
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
    _emailCtrl.dispose();
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
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'example@gmail.com',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCountryCode,
              decoration: const InputDecoration(labelText: 'Country Code'),
              items: _countryCodes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCountryCode = v ?? '+92 (PK)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: _maxPhoneDigits,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _whatsappCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: _maxPhoneDigits,
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
              decoration: InputDecoration(labelText: _idLabel),
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
            DropdownButtonFormField<String>(
              value: _paymentTerms,
              decoration: const InputDecoration(labelText: 'Payment Terms'),
              items: _paymentTermsOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _paymentTerms = v ?? 'Immediate / Cash'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _creditLimitCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Credit Limit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _openingBalanceCtrl,
                    enabled: !_isEditing,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance',
                      helperText: _isEditing
                          ? 'Sirf naye customer mein set hoti hai'
                          : null,
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Customer Save Karein'),
            ),
          ],
        ),
      ),
    );
  }
}
