import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class RegionalSettingsScreen extends StatefulWidget {
  final int companyId;
  const RegionalSettingsScreen({super.key, required this.companyId});

  @override
  State<RegionalSettingsScreen> createState() => _RegionalSettingsScreenState();
}

class _RegionalSettingsScreenState extends State<RegionalSettingsScreen> {
  String _currency = 'Rs.';
  int _decimals = 2;
  String _dateFormat = 'dd/MM/yyyy';
  String _numberStyle = 'standard';
  String _invoicePrefix = 'INV';
  String _invoiceFormat = '{PREFIX}-{NUMBER}';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company != null) {
      setState(() {
        _currency = company['currency_symbol'] as String? ?? 'Rs.';
        _decimals = company['decimal_places'] as int? ?? 2;
        _dateFormat = company['date_format'] as String? ?? 'dd/MM/yyyy';
        _numberStyle = company['number_format'] as String? ?? 'standard';
        _invoicePrefix = company['invoice_prefix'] as String? ?? 'INV';
        _invoiceFormat = company['invoice_number_format'] as String? ?? '{PREFIX}-{NUMBER}';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await DBHelper.instance.updateCompany(widget.companyId, {
      'currency_symbol': _currency,
      'decimal_places': _decimals,
      'date_format': _dateFormat,
      'number_format': _numberStyle,
      'invoice_prefix': _invoicePrefix,
      'invoice_number_format': _invoiceFormat,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regional & Numbering settings saved.')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regional, Tax & Document Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Currency & Decimals', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(labelText: 'Currency Symbol'),
                        items: ['Rs.', 'USD \$', 'EUR €', 'GBP £', 'AED', 'SAR']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _currency = v ?? 'Rs.'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _decimals,
                        decoration: const InputDecoration(labelText: 'Decimal Places'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0 (Round e.g. 1000)')),
                          DropdownMenuItem(value: 2, child: Text('2 (Standard e.g. 1000.00)')),
                        ],
                        onChanged: (v) => setState(() => _decimals = v ?? 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Date & Number Style', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dateFormat,
                        decoration: const InputDecoration(labelText: 'Date Format'),
                        items: const [
                          DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')),
                          DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')),
                          DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')),
                        ],
                        onChanged: (v) => setState(() => _dateFormat = v ?? 'dd/MM/yyyy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _numberStyle,
                        decoration: const InputDecoration(labelText: 'Number Style'),
                        items: const [
                          DropdownMenuItem(value: 'standard', child: Text('Standard (1,000.00)')),
                          DropdownMenuItem(value: 'european', child: Text('European (1.000,00)')),
                        ],
                        onChanged: (v) => setState(() => _numberStyle = v ?? 'standard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Invoice Numbering Format', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Prefix'),
                        controller: TextEditingController(text: _invoicePrefix)..selection = TextSelection.collapsed(offset: _invoicePrefix.length),
                        onChanged: (v) => _invoicePrefix = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _invoiceFormat,
                        decoration: const InputDecoration(labelText: 'Pattern'),
                        items: const [
                          DropdownMenuItem(value: '{PREFIX}-{NUMBER}', child: Text('{PREFIX}-{NUMBER}')),
                          DropdownMenuItem(value: '{PREFIX}-{YEAR}-{NUMBER}', child: Text('{PREFIX}-{YEAR}-{NUMBER}')),
                        ],
                        onChanged: (v) => setState(() => _invoiceFormat = v ?? '{PREFIX}-{NUMBER}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Settings'),
                ),
              ],
            ),
    );
  }
}
