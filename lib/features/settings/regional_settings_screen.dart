import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

class RegionalSettingsScreen extends StatefulWidget {
  final int companyId;
  const RegionalSettingsScreen({super.key, required this.companyId});

  @override
  State<RegionalSettingsScreen> createState() => _RegionalSettingsScreenState();
}

class _RegionalSettingsScreenState extends State<RegionalSettingsScreen> {
  String _currencyCode = 'PKR';
  String _currencySymbol = 'Rs.';
  int _decimalPlaces = 2;
  String _thousandSeparator = ',';
  String _decimalSeparator = '.';
  String _dateFormat = 'dd/MM/yyyy';
  String _invoicePrefix = 'INV';
  String _invoiceFormat = '{PREFIX}-{NUMBER}';

  bool _loading = true;
  bool _saving = false;

  static const List<Map<String, String>> _currencyPresets = [
    {'code': 'PKR', 'symbol': 'Rs.', 'decimals': '2'},
    {'code': 'USD', 'symbol': '\$', 'decimals': '2'},
    {'code': 'EUR', 'symbol': '€', 'decimals': '2'},
    {'code': 'GBP', 'symbol': '£', 'decimals': '2'},
    {'code': 'AED', 'symbol': 'د.إ', 'decimals': '2'},
    {'code': 'SAR', 'symbol': 'ر.س', 'decimals': '2'},
    {'code': 'INR', 'symbol': '₹', 'decimals': '2'},
    {'code': 'JPY', 'symbol': '¥', 'decimals': '0'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company != null) {
      setState(() {
        _currencyCode = company['currency_code'] as String? ?? 'PKR';
        _currencySymbol = company['currency_symbol'] as String? ?? 'Rs.';
        _decimalPlaces = company['decimal_places'] as int? ?? 2;
        _thousandSeparator = company['thousand_separator'] as String? ?? ',';
        _decimalSeparator = company['decimal_separator'] as String? ?? '.';
        _dateFormat = company['date_format'] as String? ?? 'dd/MM/yyyy';
        _invoicePrefix = company['invoice_prefix'] as String? ?? 'INV';
        _invoiceFormat =
            company['invoice_number_format'] as String? ?? '{PREFIX}-{NUMBER}';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_thousandSeparator == _decimalSeparator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Thousand separator and Decimal separator cannot be the same!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    await DBHelper.instance.updateCompany(widget.companyId, {
      'currency_code': _currencyCode,
      'currency_symbol': _currencySymbol,
      'decimal_places': _decimalPlaces,
      'thousand_separator': _thousandSeparator,
      'decimal_separator': _decimalSeparator,
      'date_format': _dateFormat,
      'invoice_prefix': _invoicePrefix,
      'invoice_number_format': _invoiceFormat,
    });

    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Company Regional & Formatting settings saved successfully.')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final amountPreview = CurrencyFormatter.format(
      1234567.89,
      currencyCode: _currencyCode,
      decimalPlaces: _decimalPlaces,
      thousandSeparator: _thousandSeparator,
      decimalSeparator: _decimalSeparator,
      symbol: _currencySymbol,
    );

    final datePreview = DateFormatter.format(
      '2026-08-28',
      format: _dateFormat,
    );

    return Scaffold(
      appBar:
          AppBar(title: const Text('Company Regional & Formatting Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Live Preview Card
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined,
                                color: Colors.indigo),
                            SizedBox(width: 8),
                            Text('Live Display Preview',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Preview:'),
                            Text(amountPreview,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Date Preview:'),
                            Text(datePreview,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Currency & ISO Settings',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _currencyPresets
                                .any((p) => p['code'] == _currencyCode)
                            ? _currencyCode
                            : 'PKR',
                        decoration: const InputDecoration(
                            labelText: 'ISO Currency Code'),
                        items: _currencyPresets
                            .map((p) => DropdownMenuItem(
                                value: p['code'],
                                child: Text('${p['code']!} (${p['symbol']!})')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            final match = _currencyPresets
                                .firstWhere((p) => p['code'] == v);
                            setState(() {
                              _currencyCode = v;
                              _currencySymbol = match['symbol']!;
                              _decimalPlaces = int.parse(match['decimals']!);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration:
                            const InputDecoration(labelText: 'Currency Symbol'),
                        controller: TextEditingController(text: _currencySymbol)
                          ..selection = TextSelection.collapsed(
                              offset: _currencySymbol.length),
                        onChanged: (v) => setState(() => _currencySymbol = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text('Number & Decimal Precision',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _decimalPlaces,
                        decoration:
                            const InputDecoration(labelText: 'Decimal Places'),
                        items: const [
                          DropdownMenuItem(
                              value: 0, child: Text('0 (JPY / Round)')),
                          DropdownMenuItem(
                              value: 2, child: Text('2 (Standard e.g. 1.00)')),
                        ],
                        onChanged: (v) =>
                            setState(() => _decimalPlaces = v ?? 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _thousandSeparator,
                        decoration: const InputDecoration(
                            labelText: 'Thousands Separator'),
                        items: const [
                          DropdownMenuItem(
                              value: ',', child: Text('Comma ( , )')),
                          DropdownMenuItem(
                              value: '.', child: Text('Period ( . )')),
                          DropdownMenuItem(
                              value: ' ', child: Text('Space (   )')),
                        ],
                        onChanged: (v) =>
                            setState(() => _thousandSeparator = v ?? ','),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _decimalSeparator,
                        decoration: const InputDecoration(
                            labelText: 'Decimal Separator'),
                        items: const [
                          DropdownMenuItem(
                              value: '.', child: Text('Period ( . )')),
                          DropdownMenuItem(
                              value: ',', child: Text('Comma ( , )')),
                        ],
                        onChanged: (v) =>
                            setState(() => _decimalSeparator = v ?? '.'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dateFormat,
                        decoration:
                            const InputDecoration(labelText: 'Date Format'),
                        items: const [
                          DropdownMenuItem(
                              value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')),
                          DropdownMenuItem(
                              value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')),
                          DropdownMenuItem(
                              value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')),
                          DropdownMenuItem(
                              value: 'dd.MM.yyyy', child: Text('DD.MM.YYYY')),
                        ],
                        onChanged: (v) =>
                            setState(() => _dateFormat = v ?? 'dd/MM/yyyy'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Regional Settings'),
                ),
              ],
            ),
    );
  }
}
