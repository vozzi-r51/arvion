import 'package:flutter/material.dart';
import '../../core/services/recurring_sales_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/design_tokens.dart';

class RecurringInvoicesDueDialog extends StatefulWidget {
  final int companyId;
  final List<Map<String, dynamic>> dueTemplates;
  final String currencyCode;
  final String currencySymbol;

  const RecurringInvoicesDueDialog({
    super.key,
    required this.companyId,
    required this.dueTemplates,
    required this.currencyCode,
    required this.currencySymbol,
  });

  static Future<void> checkAndShow(
    BuildContext context, {
    required int companyId,
    required String currencyCode,
    required String currencySymbol,
  }) async {
    final due = await RecurringSalesService.getDueRecurringSaleTemplates(companyId);
    if (due.isEmpty || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecurringInvoicesDueDialog(
        companyId: companyId,
        dueTemplates: due,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      ),
    );
  }

  @override
  State<RecurringInvoicesDueDialog> createState() => _RecurringInvoicesDueDialogState();
}

class _RecurringInvoicesDueDialogState extends State<RecurringInvoicesDueDialog> {
  bool _generating = false;
  String? _errorMessage;

  Future<void> _generateAll() async {
    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    int successCount = 0;
    int failCount = 0;

    for (final template in widget.dueTemplates) {
      try {
        await RecurringSalesService.generateSaleFromTemplate(template);
        successCount++;
      } catch (e) {
        failCount++;
        _errorMessage = 'Error on template "${template['category']}": $e';
      }
    }

    setState(() => _generating = false);

    if (!mounted) return;

    if (failCount == 0) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount Recurring Invoices successfully generated!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount generated, $failCount failed: $_errorMessage'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalAmount = 0;
    for (final t in widget.dueTemplates) {
      totalAmount += (t['amount'] as num).toDouble();
    }

    final formattedTotal = CurrencyFormatter.format(
      totalAmount,
      currencyCode: widget.currencyCode,
      symbol: widget.currencySymbol,
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event_repeat, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Recurring Invoices Due'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.dueTemplates.length} recurring invoices are ready to generate:'),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.dueTemplates.length,
                itemBuilder: (ctx, i) {
                  final t = widget.dueTemplates[i];
                  final amt = CurrencyFormatter.format(
                    (t['amount'] as num).toDouble(),
                    currencyCode: widget.currencyCode,
                    symbol: widget.currencySymbol,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t['category'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Due Date: ${t['next_due_date']}'),
                    trailing: Text(amt, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Due Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(formattedTotal, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _generating ? null : () => Navigator.pop(context),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: _generating ? null : _generateAll,
          child: _generating
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Generate Invoices'),
        ),
      ],
    );
  }
}
