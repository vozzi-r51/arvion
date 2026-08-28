import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/database/db_helper.dart';
import '../invoice/invoice_pdf_service.dart';
import '../returns/new_sales_return_screen.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/bluetooth/bluetooth_printer_service.dart';

class SaleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DBHelper.instance.getSaleItems(widget.sale['id'] as int);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _printOrShare(InvoicePaperSize size) async {
    setState(() => _generating = true);
    try {
      final company = await DBHelper.instance
          .getCompanyById(widget.sale['company_id'] as int);
      if (company == null) return;

      final bytes = await InvoicePdfService.generateSaleInvoice(
        company: company,
        sale: widget.sale,
        items: _items,
        paperSize: size,
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.sale['invoice_number']}.pdf',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showPaperSizeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('A4 (Full Page)'),
              onTap: () {
                Navigator.pop(ctx);
                _printOrShare(InvoicePaperSize.a4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Thermal (80mm Receipt) - PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _printOrShare(InvoicePaperSize.thermal80mm);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Bluetooth Thermal Printer (Direct)'),
              onTap: () {
                Navigator.pop(ctx);
                _printViaBluetooth();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printViaBluetooth() async {
    setState(() => _generating = true);
    final devices = await BluetoothPrinterService.getPairedDevices();
    
    if (!mounted) return;
    setState(() => _generating = false);

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koi paired Bluetooth printer nahi mila. Bluetooth on karein aur phone settings se printer pair karein.')),
      );
      return;
    }

    final selected = await showDialog<BluetoothDevice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Printer Select Karein'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: devices
                .map((d) => ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(d.name ?? 'Unknown'),
                      onTap: () => Navigator.pop(ctx, d),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null) return;

    setState(() => _generating = true);
    final connected = await BluetoothPrinterService.connect(selected);
    if (!connected) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Printer se connect nahi ho saka')));
      }
      return;
    }

    final sale = widget.sale;
    final items = _items
        .map((it) => (
              name: it['product_name'] as String,
              qty: '${it['quantity']}',
              total: 'Rs.${(it['total'] as num).toStringAsFixed(0)}',
            ))
        .toList();

    final printed = await BluetoothPrinterService.printReceipt(
      shopName: 'BizManager',
      invoiceNumber: sale['invoice_number'] as String,
      dateText: (sale['sale_date'] as String).substring(0, 16).replaceFirst('T', ' '),
      customerName: sale['customer_name'] as String? ?? 'Walk-in Customer',
      items: items,
      subtotal: (sale['subtotal'] as num).toStringAsFixed(0),
      discount: (sale['discount_amount'] as num).toStringAsFixed(0),
      total: (sale['total_amount'] as num).toStringAsFixed(0),
      paid: (sale['paid_amount'] as num).toStringAsFixed(0),
      due: (sale['due_amount'] as num).toStringAsFixed(0),
    );

    setState(() => _generating = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(printed ? 'Print ho gaya' : 'Print fail ho gaya')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return Scaffold(
      appBar: AppBar(
        title: Text(sale['invoice_number'] as String),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Print / Share Invoice',
            onPressed: _loading || _generating ? null : _showPaperSizeSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${sale['customer_name'] ?? 'Walk-in Customer'}'),
                        Text('Date: ${(sale['sale_date'] as String).substring(0, 16).replaceFirst('T', ' ')}'),
                        Text('Payment: ${sale['payment_method']}'),
                        if ((sale['sale_type'] as String) == 'due')
                          Text(
                            'Due Amount: Rs. ${(sale['due_amount'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._items.map((item) => Card(
                      child: ListTile(
                        title: Text(item['product_name'] as String),
                        subtitle: Text(
                            '${item['quantity']} x Rs. ${item['unit_price']}'),
                        trailing: Text('Rs. ${(item['total'] as num).toStringAsFixed(0)}'),
                      ),
                    )),
                const Divider(height: 32),
                _summaryRow('Subtotal', sale['subtotal'] as num),
                _summaryRow('Discount', sale['discount_amount'] as num),
                _summaryRow('Tax', (sale['tax_amount'] as num?) ?? 0),
                _summaryRow('Total', sale['total_amount'] as num, bold: true),
                _summaryRow('Paid', sale['paid_amount'] as num),
                _summaryRow('Due', sale['due_amount'] as num),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _loading || _generating ? null : _showPaperSizeSheet,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print / Share Invoice'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewSalesReturnScreen(
                                companyId: sale['company_id'] as int,
                                initialSale: sale,
                              ),
                            ),
                          );
                          if (result == true && mounted) _load();
                        },
                  icon: const Icon(Icons.keyboard_return, color: Colors.red),
                  label: const Text('Return Items', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ],
            ),
    );
  }

  Widget _summaryRow(String label, num value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs. ${value.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
