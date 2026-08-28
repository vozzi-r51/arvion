import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/currency_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class CurrencyRatesScreen extends StatefulWidget {
  final int companyId;
  const CurrencyRatesScreen({super.key, required this.companyId});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  List<Map<String, dynamic>> _currencies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = sl<CurrencyRepository>();
    final list = await repo.listCurrencyRates(widget.companyId);
    setState(() {
      _currencies = list;
      _loading = false;
    });
  }

  void _showAddCurrencyDialog([Map<String, dynamic>? existing]) {
    final codeCtrl =
        TextEditingController(text: existing?['currency_code'] ?? 'USD');
    final symbolCtrl =
        TextEditingController(text: existing?['currency_symbol'] ?? '\$');
    final rateCtrl = TextEditingController(
        text: existing != null
            ? (existing['exchange_rate_to_base'] as num).toString()
            : '278.5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null
            ? 'Exchange Rate Edit Karein'
            : 'Nayi Currency Add Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Currency Code (e.g. USD, EUR, AED) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: symbolCtrl,
              decoration:
                  const InputDecoration(labelText: 'Symbol (e.g. \$, €, SR) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Exchange Rate to PKR (Base) *'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              final symbol = symbolCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text.trim());

              if (code.isEmpty || symbol.isEmpty || rate == null || rate <= 0)
                return;

              await sl<CurrencyRepository>().setCurrencyRate(
                companyId: widget.companyId,
                currencyCode: code,
                currencySymbol: symbol,
                exchangeRateToBase: rate,
              );

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Currency Exchange Rates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currencies.isEmpty
              ? AppEmptyState(
                  icon: Icons.currency_exchange,
                  title: 'Koi Currency Configured Nahi',
                  message:
                      'Import/Export supplier invoices ke liye USD, EUR, AED, SAR jaise foreign currencies add karein.',
                  actionLabel: 'Currency Add Karein',
                  onAction: () => _showAddCurrencyDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _currencies.length,
                  itemBuilder: (ctx, i) {
                    final c = _currencies[i];
                    final rate = (c['exchange_rate_to_base'] as num).toDouble();
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Text(c['currency_symbol'] as String,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800)),
                        ),
                        title: Text(
                            '${c['currency_code']} (${c['currency_symbol']})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:
                            Text('1 ${c['currency_code']} = Rs. $rate PKR'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showAddCurrencyDialog(c),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCurrencyDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Currency'),
      ),
    );
  }
}
