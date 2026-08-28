import 'package:flutter/material.dart';

/// Size-Color Variant Quick Sale POS Grid for Clothing & Footwear businesses.
/// Displays a Size (Rows) x Color (Columns) grid with live stock counts per cell.
class SizeColorVariantGrid extends StatelessWidget {
  final String productName;
  final List<Map<String, dynamic>> variants; // [{'id': 1, 'size': 'M', 'color': 'Black', 'stock': 8, 'price': 1500}]
  final Function(Map<String, dynamic> selectedVariant) onVariantSelected;

  const SizeColorVariantGrid({
    super.key,
    required this.productName,
    required this.variants,
    required this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Extract unique sizes and colors
    final sizes = variants.map((v) => (v['size'] as String? ?? 'Std').trim()).toSet().toList()..sort();
    final colors = variants.map((v) => (v['color'] as String? ?? 'Std').trim()).toSet().toList()..sort();

    if (sizes.isEmpty) sizes.add('Standard');
    if (colors.isEmpty) colors.add('Standard');

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checkroom, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('$productName — Size/Color Quick POS Grid', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(90),
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  // Header Row (Colors)
                  TableRow(
                    decoration: BoxDecoration(color: Colors.indigo.shade50),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Size \\ Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      ...colors.map((c) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(c, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )),
                    ],
                  ),
                  // Data Rows (Sizes)
                  ...sizes.map((sz) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(sz, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...colors.map((col) {
                          final match = variants.firstWhere(
                            (v) => (v['size'] as String? ?? '').trim() == sz && (v['color'] as String? ?? '').trim() == col,
                            orElse: () => {'stock': 0, 'price': 0},
                          );

                          final stock = (match['stock'] as num?)?.toInt() ?? 0;
                          final price = (match['price'] as num?)?.toDouble() ?? 0.0;
                          final isAvailable = stock > 0;

                          return InkWell(
                            onTap: isAvailable ? () => onVariantSelected(match) : null,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: isAvailable ? Colors.green.shade50 : Colors.grey.shade200,
                              child: Column(
                                children: [
                                  Text(
                                    isAvailable ? '$stock in stock' : 'OUT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isAvailable ? Colors.green.shade800 : Colors.red,
                                    ),
                                  ),
                                  if (price > 0)
                                    Text('Rs. ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
