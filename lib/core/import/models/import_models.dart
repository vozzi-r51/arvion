enum ImportSource {
  quickbooks,
  tally,
  vyapar,
  generic;

  String get displayName {
    switch (this) {
      case ImportSource.quickbooks:
        return 'QuickBooks (Online / Desktop CSV)';
      case ImportSource.tally:
        return 'Tally (Excel / XML)';
      case ImportSource.vyapar:
        return 'Vyapar (Excel)';
      case ImportSource.generic:
        return 'Generic CSV / Excel';
    }
  }

  String get instructions {
    switch (this) {
      case ImportSource.quickbooks:
        return 'QuickBooks Online ya Desktop se Products, Customers, ya Vendors ki CSV/Excel file export karein aur yahan select karein.';
      case ImportSource.tally:
        return 'Tally ERP/Prime se Stock Items ya Party Ledgers ki Excel/XML file export karein aur yahan upload karein.';
      case ImportSource.vyapar:
        return 'Vyapar app se Item List ya Party List ki Excel file export karke select karein.';
      case ImportSource.generic:
        return 'Kishi bhi Excel/CSV spreadsheet file ko select karein. System columns ko automatically detect aur map kar dega.';
    }
  }
}

enum ImportEntityType {
  products,
  customers,
  suppliers,
  openingBalances;

  String get displayName {
    switch (this) {
      case ImportEntityType.products:
        return 'Products / Stock Items';
      case ImportEntityType.customers:
        return 'Customers / Parties';
      case ImportEntityType.suppliers:
        return 'Suppliers / Vendors';
      case ImportEntityType.openingBalances:
        return 'Opening Balances';
    }
  }
}

enum ImportConfidence {
  high,
  medium,
  low,
  unmapped;

  String get label {
    switch (this) {
      case ImportConfidence.high:
        return 'Exact Match';
      case ImportConfidence.medium:
        return 'Auto Mapped';
      case ImportConfidence.low:
        return 'Suggested';
      case ImportConfidence.unmapped:
        return 'Unmapped';
    }
  }
}

enum DuplicatePolicy {
  skip,
  overwrite,
  importAsNew;

  String get displayName {
    switch (this) {
      case DuplicatePolicy.skip:
        return 'Skip Duplicates';
      case DuplicatePolicy.overwrite:
        return 'Overwrite Existing Records';
      case DuplicatePolicy.importAsNew:
        return 'Import as New Records';
    }
  }
}

class ColumnMapping {
  final String sourceHeader;
  String? targetField;
  ImportConfidence confidence;

  ColumnMapping({
    required this.sourceHeader,
    this.targetField,
    this.confidence = ImportConfidence.unmapped,
  });
}

class ParsedRow {
  final int rowIndex;
  final Map<String, String> rawData;
  Map<String, dynamic> mappedData = {};
  List<String> validationErrors = [];
  bool isDuplicate = false;
  Map<String, dynamic>? existingRecord;

  ParsedRow({
    required this.rowIndex,
    required this.rawData,
  });

  bool get isValid => validationErrors.isEmpty;
}

class ImportSummary {
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  int importedCount;
  int skippedCount;

  ImportSummary({
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    this.importedCount = 0,
    this.skippedCount = 0,
  });
}
