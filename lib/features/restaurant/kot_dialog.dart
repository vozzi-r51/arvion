import 'package:flutter/material.dart';

/// Kitchen Order Ticket (KOT) Dialog.
/// Strictly presents item names, quantities, and table info for kitchen staff.
/// Excludes prices, totals, discounts, and payment information.
class KotDialog extends StatelessWidget {
  final String kotNumber;
  final String tableName;
  final List<Map<String, dynamic>> items; // [{'name': 'Chicken Biryani', 'quantity': 2, 'notes': 'Extra spicy'}]

  const KotDialog({
    super.key,
    required this.kotNumber,
    required this.tableName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final nowStr = DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ');

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restaurant, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          const Text('KITCHEN ORDER TICKET (KOT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.amber.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KOT #: $kotNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Table: $tableName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                  Text('Time: $nowStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('ORDER ITEMS FOR PREPARATION:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final name = item['name'] as String? ?? item['product_name'] as String? ?? 'Item';
                  final qty = item['quantity'] ?? 1;
                  final notes = item['notes'] as String?;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (notes != null && notes.isNotEmpty)
                                Text('Notes: $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.deepOrange)),
                            ],
                          ),
                        ),
                        Text('$qty x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Center(
              child: Text(
                'NO PAYMENT OR PRICE INFO (Kitchen Copy Only)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('KOT #$kotNumber sent to Kitchen for Table $tableName!'), backgroundColor: Colors.green),
            );
          },
          icon: const Icon(Icons.send),
          label: const Text('Send to Kitchen'),
        ),
      ],
    );
  }
}
