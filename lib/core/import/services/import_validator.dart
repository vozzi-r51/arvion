import '../models/import_models.dart';

/// Per-Row Field Validator for Universal Data Import.
class ImportValidator {
  ImportValidator._();

  /// Validates a parsed row based on active column mappings and entity requirements.
  static ParsedRow validateAndExtractRow({
    required ParsedRow row,
    required List<ColumnMapping> mappings,
    required ImportEntityType entityType,
  }) {
    final Map<String, dynamic> extracted = {};
    final List<String> errors = [];

    // Map source values to target fields
    for (final mapping in mappings) {
      if (mapping.targetField == null || mapping.targetField!.isEmpty) continue;
      final rawVal = row.rawData[mapping.sourceHeader]?.trim() ?? '';
      extracted[mapping.targetField!] = rawVal;
    }

    // Entity-Specific Validation Rules
    switch (entityType) {
      case ImportEntityType.products:
        final name = extracted['name']?.toString() ?? '';
        if (name.isEmpty) {
          errors.add('Product Name is required');
        }

        final retailPriceStr = extracted['retail_price']?.toString() ?? '0';
        if (retailPriceStr.isNotEmpty &&
            double.tryParse(retailPriceStr) == null) {
          errors.add('Selling Price must be a valid number ($retailPriceStr)');
        }

        final purchasePriceStr = extracted['purchase_price']?.toString() ?? '0';
        if (purchasePriceStr.isNotEmpty &&
            double.tryParse(purchasePriceStr) == null) {
          errors
              .add('Purchase Price must be a valid number ($purchasePriceStr)');
        }

        final stockStr = extracted['current_stock']?.toString() ?? '0';
        if (stockStr.isNotEmpty && double.tryParse(stockStr) == null) {
          errors.add('Stock Quantity must be a valid number ($stockStr)');
        }
        break;

      case ImportEntityType.customers:
        final name = extracted['name']?.toString() ?? '';
        if (name.isEmpty) {
          errors.add('Customer Name is required');
        }

        final balanceStr = extracted['current_balance']?.toString() ?? '0';
        if (balanceStr.isNotEmpty && double.tryParse(balanceStr) == null) {
          errors.add('Opening Balance must be a valid number ($balanceStr)');
        }
        break;

      case ImportEntityType.suppliers:
        final name = extracted['company_name']?.toString() ?? '';
        if (name.isEmpty) {
          errors.add('Supplier / Company Name is required');
        }

        final balanceStr = extracted['current_balance']?.toString() ?? '0';
        if (balanceStr.isNotEmpty && double.tryParse(balanceStr) == null) {
          errors.add('Opening Balance must be a valid number ($balanceStr)');
        }
        break;

      case ImportEntityType.openingBalances:
        final name = extracted['account_or_name']?.toString() ?? '';
        final amountStr = extracted['amount']?.toString() ?? '';

        if (name.isEmpty) {
          errors.add('Account / Party Name is required');
        }
        if (amountStr.isEmpty || double.tryParse(amountStr) == null) {
          errors.add('Amount must be a valid number ($amountStr)');
        }
        break;
    }

    row.mappedData = extracted;
    row.validationErrors = errors;
    return row;
  }
}
