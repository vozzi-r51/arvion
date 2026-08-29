import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/database/db_helper.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/utils/currency_formatter.dart';

class NewDeliveryChallanScreen extends StatefulWidget {
  final int companyId;
  const NewDeliveryChallanScreen({super.key, required this.companyId});

  @override
  State<NewDeliveryChallanScreen> createState() =>
      _NewDeliveryChallanScreenState();
}

class _NewDeliveryChallanScreenState extends State<NewDeliveryChallanScreen> {
  Map<String, dynamic>? _selectedSale;
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;
  bool _saving = false;
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _signatureController = SignaturePadController();

  Future<void> _pickSale() async {
    final sale = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SalePickerSheet(companyId: widget.companyId),
    );
    if (sale == null) return;

    setState(() {
      _selectedSale = sale;
      _loadingItems = true;
    });

    final items = await DBHelper.instance.getSaleItems(sale['id'] as int);
    setState(() {
      _items = items;
      _loadingItems = false;
    });
  }

  Future<void> _save() async {
    if (_selectedSale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle sale select karein')));
      return;
    }

    setState(() => _saving = true);

    String? signaturePath;
    final signatureBytes = await _signatureController.exportPng();
    if (signatureBytes != null) {
      final docsDir = await getApplicationDocumentsDirectory();
      final sigDir = Directory(p.join(docsDir.path, 'signatures'));
      if (!await sigDir.exists()) await sigDir.create(recursive: true);
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(sigDir.path, fileName));
      await file.writeAsBytes(signatureBytes);
      signaturePath = file.path;
    }

    final challanNumber =
        await DBHelper.instance.generateChallanNumber(widget.companyId);

    final challanData = {
      'company_id': widget.companyId,
      'challan_number': challanNumber,
      'sale_id': _selectedSale!['id'],
      'customer_id': _selectedSale!['customer_id'],
      'customer_name': _selectedSale!['customer_name'],
      'challan_date': DateTime.now().toIso8601String(),
      'delivery_address': _addressCtrl.text.trim(),
      'delivery_status': signaturePath != null ? 'delivered' : 'pending',
      'signature_path': signaturePath,
      'notes': _notesCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final itemsData = _items
        .map((it) => {
              'product_id': it['product_id'],
              'product_name': it['product_name'],
              'quantity': it['quantity'],
            })
        .toList();

    await DBHelper.instance
        .insertChallanWithItems(challan: challanData, items: itemsData);

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Challan save ho gaya ($challanNumber)')));
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Delivery Challan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickSale,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(_selectedSale == null
                ? 'Sale Select Karein'
                : '${_selectedSale!['invoice_number']} — ${_selectedSale!['customer_name'] ?? 'Walk-in Customer'}'),
          ),
          if (_loadingItems)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loadingItems && _items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._items.map((it) => Card(
                  child: ListTile(
                    title: Text(it['product_name'] as String),
                    trailing: Text('Qty: ${it['quantity']}'),
                  ),
                )),
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Delivery Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            Text('Customer Signature (optional)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SignaturePad(controller: _signatureController),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _signatureController.clear()),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Karein'),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Challan Save Karein'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalePickerSheet extends StatefulWidget {
  final int companyId;
  const _SalePickerSheet({required this.companyId});

  @override
  State<_SalePickerSheet> createState() => _SalePickerSheetState();
}

class _SalePickerSheetState extends State<_SalePickerSheet> {
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.instance.getSales(widget.companyId);
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (!mounted) return;
    setState(() {
      _sales = rows;
      _filtered = rows;
      _company = company;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _filtered = _sales.where((s) {
        final invoice = (s['invoice_number'] as String).toLowerCase();
        final customer = (s['customer_name'] as String? ?? '').toLowerCase();
        final q = query.toLowerCase();
        return invoice.contains(q) || customer.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Sale Select Karein',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Invoice number ya customer se search karein',
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('Koi sale nahi mili'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            return ListTile(
                              title: Text(s['invoice_number'] as String),
                              subtitle: Text(
                                  '${s['customer_name'] ?? 'Walk-in Customer'}  •  ${CurrencyFormatter.formatFromCompany((s['total_amount'] as num?) ?? 0, _company, decimalPlaces: 0)}'),
                              onTap: () => Navigator.of(context).pop(s),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
