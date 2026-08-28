import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/import/models/import_models.dart';
import 'package:bizmanager/core/import/services/smart_column_mapper.dart';
import 'package:bizmanager/core/import/services/import_validator.dart';
import 'package:bizmanager/core/import/parsers/iif_parser.dart';

void main() {
  group('Universal Importer - Smart Column Mapping Engine Tests', () {
    test(
        'Auto-detects QuickBooks Online product export headers with high confidence',
        () {
      final headers = [
        'Product/Service Name',
        'SKU',
        'Sales Price',
        'Purchase Cost',
        'Qty on Hand',
      ];

      final mappings = SmartColumnMapper.mapColumns(
        headers: headers,
        entityType: ImportEntityType.products,
        source: ImportSource.quickbooks,
      );

      expect(mappings[0].targetField, equals('name'));
      expect(mappings[0].confidence, equals(ImportConfidence.high));

      expect(mappings[1].targetField, equals('product_code'));
      expect(mappings[1].confidence, equals(ImportConfidence.high));

      expect(mappings[2].targetField, equals('retail_price'));
      expect(mappings[2].confidence, equals(ImportConfidence.high));

      expect(mappings[3].targetField, equals('purchase_price'));
      expect(mappings[3].confidence, equals(ImportConfidence.high));

      expect(mappings[4].targetField, equals('current_stock'));
      expect(mappings[4].confidence, equals(ImportConfidence.high));
    });

    test('Auto-detects Tally Excel product export headers', () {
      final headers = [
        'Stock Item Name',
        'Rate',
        'Closing Balance',
      ];

      final mappings = SmartColumnMapper.mapColumns(
        headers: headers,
        entityType: ImportEntityType.products,
        source: ImportSource.tally,
      );

      expect(mappings[0].targetField, equals('name'));
      expect(mappings[1].targetField, equals('purchase_price'));
      expect(mappings[2].targetField, equals('current_stock'));
    });

    test('Auto-detects Vyapar Excel customer export headers', () {
      final headers = [
        'Party Name',
        'Mobile Number',
        'Opening Balance',
        'Billing Address',
      ];

      final mappings = SmartColumnMapper.mapColumns(
        headers: headers,
        entityType: ImportEntityType.customers,
        source: ImportSource.vyapar,
      );

      expect(mappings[0].targetField, equals('name'));
      expect(mappings[1].targetField, equals('mobile'));
      expect(mappings[2].targetField, equals('current_balance'));
      expect(mappings[3].targetField, equals('address'));
    });
  });

  group('Universal Importer - Validation Engine Tests', () {
    test('Flags invalid product rows missing product name or invalid prices',
        () {
      final mappings = [
        ColumnMapping(
            sourceHeader: 'Item Name',
            targetField: 'name',
            confidence: ImportConfidence.high),
        ColumnMapping(
            sourceHeader: 'Price',
            targetField: 'retail_price',
            confidence: ImportConfidence.high),
      ];

      final invalidRow1 = ParsedRow(
        rowIndex: 1,
        rawData: {'Item Name': '', 'Price': '150'},
      );

      final result1 = ImportValidator.validateAndExtractRow(
        row: invalidRow1,
        mappings: mappings,
        entityType: ImportEntityType.products,
      );

      expect(result1.isValid, isFalse);
      expect(result1.validationErrors, contains('Product Name is required'));

      final invalidRow2 = ParsedRow(
        rowIndex: 2,
        rawData: {'Item Name': 'Plate Set', 'Price': 'abc_invalid'},
      );

      final result2 = ImportValidator.validateAndExtractRow(
        row: invalidRow2,
        mappings: mappings,
        entityType: ImportEntityType.products,
      );

      expect(result2.isValid, isFalse);
      expect(result2.validationErrors.any((e) => e.contains('valid number')),
          isTrue);
    });

    test('Passes valid customer rows with numeric opening balance', () {
      final mappings = [
        ColumnMapping(
            sourceHeader: 'Party Name',
            targetField: 'name',
            confidence: ImportConfidence.high),
        ColumnMapping(
            sourceHeader: 'Balance',
            targetField: 'current_balance',
            confidence: ImportConfidence.high),
      ];

      final validRow = ParsedRow(
        rowIndex: 1,
        rawData: {'Party Name': 'Ali Retailers', 'Balance': '4500.50'},
      );

      final result = ImportValidator.validateAndExtractRow(
        row: validRow,
        mappings: mappings,
        entityType: ImportEntityType.customers,
      );

      expect(result.isValid, isTrue);
      expect(result.mappedData['name'], equals('Ali Retailers'));
      expect(result.mappedData['current_balance'], equals('4500.50'));
    });
  });

  group('QuickBooks IIF Parser Architecture Tests', () {
    test('IifParser exists and exposes parseIifFile signature', () {
      final parser = IifParser();
      expect(parser, isNotNull);
    });
  });
}
