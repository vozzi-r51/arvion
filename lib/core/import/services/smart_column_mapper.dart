import '../models/import_models.dart';

/// Smart Column Mapping Engine with Source-Specific Synonyms & Aliases.
class SmartColumnMapper {
  SmartColumnMapper._();

  static const Map<String, List<String>> _productAliases = {
    'name': [
      'product name', 'item name', 'product/service name', 'stock item name',
      'item', 'product', 'title', 'item_name', 'product_name', 'description'
    ],
    'product_code': [
      'product code', 'item code', 'code', 'sku', 'sku_code', 'item_code'
    ],
    'barcode': [
      'barcode', 'upc', 'ean', 'isbn', 'barcode_number'
    ],
    'category_name': [
      'category', 'category name', 'product category', 'item category', 'group'
    ],
    'brand_name': [
      'brand', 'brand name', 'manufacturer', 'make'
    ],
    'purchase_price': [
      'purchase price', 'purchase cost', 'buy price', 'cost price', 'cost',
      'unit cost', 'rate', 'purchase_rate'
    ],
    'retail_price': [
      'selling price', 'sales price', 'retail price', 'sell price', 'price',
      'unit price', 'mrp', 'sale_price', 'sale rate'
    ],
    'wholesale_price': [
      'wholesale price', 'trade price', 'dealer price', 'wholesale_rate'
    ],
    'current_stock': [
      'current stock', 'stock quantity', 'qty on hand', 'quantity', 'stock',
      'closing balance', 'available qty', 'on hand', 'opening stock', 'qty'
    ],
    'low_stock_level': [
      'minimum stock', 'min stock', 'reorder level', 'reorder point', 'low stock level'
    ],
  };

  static const Map<String, List<String>> _customerAliases = {
    'name': [
      'customer name', 'party name', 'customer', 'party', 'contact name',
      'name', 'full name', 'client name', 'ledger name'
    ],
    'mobile': [
      'mobile', 'phone', 'mobile number', 'phone number', 'contact', 'cell', 'mobile_no'
    ],
    'email': [
      'email', 'email address', 'e-mail'
    ],
    'address': [
      'address', 'street address', 'billing address', 'location', 'city'
    ],
    'current_balance': [
      'opening balance', 'balance', 'closing balance', 'receivable', 'amount'
    ],
    'credit_limit': [
      'credit limit', 'max credit'
    ],
  };

  static const Map<String, List<String>> _supplierAliases = {
    'company_name': [
      'company name', 'supplier name', 'vendor name', 'vendor', 'supplier',
      'party name', 'ledger name', 'party', 'name'
    ],
    'contact_person': [
      'contact person', 'contact name', 'person'
    ],
    'phone': [
      'phone', 'mobile', 'phone number', 'mobile number', 'contact'
    ],
    'email': [
      'email', 'email address'
    ],
    'address': [
      'address', 'office address', 'billing address', 'city'
    ],
    'current_balance': [
      'opening balance', 'balance', 'closing balance', 'payable', 'amount'
    ],
  };

  static const Map<String, List<String>> _openingBalanceAliases = {
    'account_or_name': [
      'party name', 'customer', 'supplier', 'account name', 'ledger name', 'name', 'account'
    ],
    'amount': [
      'opening balance', 'amount', 'balance', 'closing balance', 'value'
    ],
    'type': [
      'type', 'debit/credit', 'dr/cr', 'direction'
    ],
  };

  /// Auto-maps a list of file headers to target fields based on entity type and source.
  static List<ColumnMapping> mapColumns({
    required List<String> headers,
    required ImportEntityType entityType,
    ImportSource source = ImportSource.generic,
  }) {
    final Map<String, List<String>> aliasMap = _getAliasMap(entityType);
    final List<ColumnMapping> mappings = [];

    for (final header in headers) {
      final normalizedHeader = _normalizeString(header);
      String? matchedField;
      ImportConfidence confidence = ImportConfidence.unmapped;

      for (final entry in aliasMap.entries) {
        final targetField = entry.key;
        final aliases = entry.value;

        if (normalizedHeader == targetField.replaceAll('_', '')) {
          matchedField = targetField;
          confidence = ImportConfidence.high;
          break;
        }

        for (final alias in aliases) {
          final normalizedAlias = _normalizeString(alias);
          if (normalizedHeader == normalizedAlias) {
            matchedField = targetField;
            confidence = ImportConfidence.high;
            break;
          } else if (normalizedHeader.contains(normalizedAlias) || normalizedAlias.contains(normalizedHeader)) {
            if (confidence != ImportConfidence.high) {
              matchedField = targetField;
              confidence = ImportConfidence.medium;
            }
          }
        }

        if (confidence == ImportConfidence.high) break;
      }

      mappings.add(ColumnMapping(
        sourceHeader: header,
        targetField: matchedField,
        confidence: confidence,
      ));
    }

    return mappings;
  }

  static Map<String, List<String>> _getAliasMap(ImportEntityType entityType) {
    switch (entityType) {
      case ImportEntityType.products:
        return _productAliases;
      case ImportEntityType.customers:
        return _customerAliases;
      case ImportEntityType.suppliers:
        return _supplierAliases;
      case ImportEntityType.openingBalances:
        return _openingBalanceAliases;
    }
  }

  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}
