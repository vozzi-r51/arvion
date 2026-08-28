import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class PriceListsScreen extends StatefulWidget {
  final int companyId;
  const PriceListsScreen({super.key, required this.companyId});

  @override
  State<PriceListsScreen> createState() => _PriceListsScreenState();
}

class _PriceListsScreenState extends State<PriceListsScreen> {
  List<Map<String, dynamic>> _priceLists = [];
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lists = await DBHelper.instance.getPriceLists(widget.companyId);
    final prods = await DBHelper.instance.getProducts(widget.companyId);
    setState(() {
      _priceLists = lists;
      _products = prods;
      _loading = false;
    });
  }

  void _showAddPriceListDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Price List'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
              labelText: 'Price List Name (e.g. Ramadan Sale, VIP)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await DBHelper.instance
                    .insertPriceList(widget.companyId, nameCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _openPriceOverrides(Map<String, dynamic> priceList) async {
    final Map<int, TextEditingController> ctrls = {};
    for (var p in _products) {
      final pid = p['id'] as int;
      final existingPrice = await DBHelper.instance
          .getProductPriceForList(priceList['id'] as int, pid);
      ctrls[pid] = TextEditingController(
          text: existingPrice != null ? existingPrice.toString() : '');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Text('Override Prices: ${priceList['name']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (c, i) {
                    final p = _products[i];
                    final pid = p['id'] as int;
                    return ListTile(
                      title: Text(p['name'] as String),
                      subtitle: Text('Base Retail: Rs. ${p['retail_price']}'),
                      trailing: SizedBox(
                        width: 100,
                        child: TextField(
                          controller: ctrls[pid],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              hintText: 'Custom Price', isDense: true),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final Map<int, double> priceMap = {};
                  ctrls.forEach((pid, ctrl) {
                    final val = double.tryParse(ctrl.text.trim());
                    if (val != null) priceMap[pid] = val;
                  });
                  await DBHelper.instance
                      .saveProductPrices(priceList['id'] as int, priceMap);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom prices saved.')));
                },
                child: const Text('Save Prices'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Lists Manager')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _priceLists.isEmpty
              ? const Center(child: Text('No custom price lists created yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _priceLists.length,
                  itemBuilder: (ctx, i) {
                    final pl = _priceLists[i];
                    return Card(
                      child: ListTile(
                        title: Text(pl['name'] as String),
                        trailing: OutlinedButton(
                          onPressed: () => _openPriceOverrides(pl),
                          child: const Text('Set Item Prices'),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPriceListDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
