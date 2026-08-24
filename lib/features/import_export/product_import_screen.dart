import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/database/db_helper.dart';
import '../../core/export/csv_export_service.dart';

class ProductImportScreen extends StatefulWidget {
  final int companyId;
  const ProductImportScreen({super.key, required this.companyId});

  @override
  State<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends State<ProductImportScreen> {
  bool _busy = false;
  String? _resultMessage;

  static const _headers = [
    'name', 'product_code', 'barcode', 'category', 'brand',
    'purchase_price', 'retail_price', 'wholesale_price',
    'current_stock', 'low_stock_level',
  ];

  Future<void> _downloadTemplate() async {
    await CsvExportService.exportAndShare(
      fileName: 'DukanEdge_Product_Import_Template',
      headers: _headers,
      rows: [
        ['Sample Plate Set', 'P001', '1234567890', 'Melamine', 'ABC Brand', '200', '350', '300', '50', '10'],
      ],
    );
  }

  List<String> _splitCsvLine(String line) {
    // Simple CSV split that respects double-quoted fields (matches how
    // CsvExportService escapes them on export).
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _resultMessage = null;
    });

    try {
      final content = await File(path).readAsString();
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) {
        setState(() {
          _busy = false;
          _resultMessage = 'File khali hai ya sirf header hai';
        });
        return;
      }

      final header = _splitCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
      int colIndex(String name) => header.indexOf(name);

      final categories = await DBHelper.instance.getCategories(widget.companyId);
      final brands = await DBHelper.instance.getBrands(widget.companyId);
      final categoryMap = {for (final c in categories) (c['name'] as String).toLowerCase(): c['id'] as int};
      final brandMap = {for (final b in brands) (b['name'] as String).toLowerCase(): b['id'] as int};

      int imported = 0;
      int skipped = 0;

      for (final line in lines.skip(1)) {
        final cols = _splitCsvLine(line);
        String val(String key) {
          final idx = colIndex(key);
          if (idx == -1 || idx >= cols.length) return '';
          return cols[idx].trim();
        }

        final name = val('name');
        if (name.isEmpty) {
          skipped++;
          continue;
        }

        int? categoryId;
        final categoryName = val('category');
        if (categoryName.isNotEmpty) {
          categoryId = categoryMap[categoryName.toLowerCase()];
          if (categoryId == null) {
            categoryId = await DBHelper.instance.insertCategory({
              'company_id': widget.companyId,
              'name': categoryName,
              'status': 'active',
              'created_at': DateTime.now().toIso8601String(),
            });
            categoryMap[categoryName.toLowerCase()] = categoryId;
          }
        }

        int? brandId;
        final brandName = val('brand');
        if (brandName.isNotEmpty) {
          brandId = brandMap[brandName.toLowerCase()];
          if (brandId == null) {
            brandId = await DBHelper.instance.insertBrand({
              'company_id': widget.companyId,
              'name': brandName,
              'featured': 0,
              'display_order': 0,
              'status': 'active',
              'created_at': DateTime.now().toIso8601String(),
            });
            brandMap[brandName.toLowerCase()] = brandId;
          }
        }

        await DBHelper.instance.insertProduct({
          'company_id': widget.companyId,
          'name': name,
          'product_code': val('product_code'),
          'barcode': val('barcode'),
          'category_id': categoryId,
          'brand_id': brandId,
          'purchase_price': double.tryParse(val('purchase_price')) ?? 0,
          'retail_price': double.tryParse(val('retail_price')) ?? 0,
          'wholesale_price': double.tryParse(val('wholesale_price')) ?? 0,
          'current_stock': double.tryParse(val('current_stock')) ?? 0,
          'low_stock_level': double.tryParse(val('low_stock_level')) ?? 0,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        });
        imported++;
      }

      setState(() {
        _busy = false;
        _resultMessage = '$imported products import hue' +
            (skipped > 0 ? ', $skipped rows skip hui (naam khali tha)' : '');
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _resultMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Product Import')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CSV file se ek sath bohat saare products add karein. Pehle template download karein, Excel mein fill karein, phir wapis import karein.',
            ),
            const SizedBox(height: 8),
            Text(
              'Columns: ${_headers.join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Template Download Karein'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickAndImport,
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_outlined),
              label: const Text('CSV File Import Karein'),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 16),
              Text(_resultMessage!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
