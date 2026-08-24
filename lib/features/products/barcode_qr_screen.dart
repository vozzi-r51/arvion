import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

class BarcodeQrScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  const BarcodeQrScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final barcodeData = (product['barcode'] as String?)?.trim();
    final fallbackData = (product['product_code'] as String?)?.trim();
    final data = (barcodeData != null && barcodeData.isNotEmpty)
        ? barcodeData
        : (fallbackData != null && fallbackData.isNotEmpty)
            ? fallbackData
            : 'P${product['id']}';

    return Scaffold(
      appBar: AppBar(title: Text(product['name'] as String)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product['name'] as String,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Barcode (Code128)',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: data,
                        width: 240,
                        height: 90,
                        drawText: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('QR Code',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: data,
                        width: 160,
                        height: 160,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Data: $data',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                'Ye screen printing ke liye A4/label printer se screenshot ya\n'
                'thermal printer ke through print ki ja sakti hai.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
