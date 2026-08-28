import 'package:flutter/material.dart';

/// Prominent Multi-UOM Selector Component for Hardware & Sanitary businesses.
class ProminentUomSelector extends StatelessWidget {
  final String productName;
  final String selectedUom;
  final List<String>
      availableUoms; // ['Piece', 'Meter', 'Box', 'Dozen', 'Feet']
  final double quantity;
  final double unitPrice;
  final Function(String newUom) onUomChanged;
  final Function(double newQty) onQuantityChanged;

  const ProminentUomSelector({
    super.key,
    required this.productName,
    required this.selectedUom,
    required this.availableUoms,
    required this.quantity,
    required this.unitPrice,
    required this.onUomChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(productName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'Quantity', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: quantity.toStringAsFixed(0)),
                    onChanged: (v) =>
                        onQuantityChanged(double.tryParse(v) ?? 1.0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: availableUoms.contains(selectedUom)
                        ? selectedUom
                        : availableUoms.first,
                    decoration: const InputDecoration(
                        labelText: 'Unit of Measure (UOM)',
                        border: OutlineInputBorder()),
                    items: availableUoms
                        .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onUomChanged(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Price: Rs. ${unitPrice.toStringAsFixed(0)} / $selectedUom • Total: Rs. ${(quantity * unitPrice).toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
