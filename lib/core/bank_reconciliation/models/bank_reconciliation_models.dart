enum MatchConfidence {
  exact,
  high,
  medium,
  low,
  unmatched;

  String get displayName {
    switch (this) {
      case MatchConfidence.exact:
        return 'Exact Match';
      case MatchConfidence.high:
        return 'High Confidence';
      case MatchConfidence.medium:
        return 'Needs Review';
      case MatchConfidence.low:
        return 'Low Confidence';
      case MatchConfidence.unmatched:
        return 'Unmatched';
    }
  }
}

enum ParsedRowStatus {
  autoMatched,
  manualMatch,
  newTransaction,
  unmatched,
  invalid,
  alreadyReconciled;

  String get displayName {
    switch (this) {
      case ParsedRowStatus.autoMatched:
        return 'Auto Matched';
      case ParsedRowStatus.manualMatch:
        return 'Manual Match';
      case ParsedRowStatus.newTransaction:
        return 'New Transaction';
      case ParsedRowStatus.unmatched:
        return 'Unmatched / Skip';
      case ParsedRowStatus.invalid:
        return 'Invalid Row';
      case ParsedRowStatus.alreadyReconciled:
        return 'Already Reconciled';
    }
  }
}

class ParsedBankStatementRow {
  final int rowIndex;
  final String dateStr;
  final DateTime? parsedDate;
  final String description;
  final double debit;
  final double credit;
  final double amount; // Signed: + for deposit/credit, - for withdrawal/debit
  final double? balance;
  final String? reference;

  List<String> validationErrors = [];
  ParsedRowStatus status = ParsedRowStatus.unmatched;
  MatchConfidence confidence = MatchConfidence.unmatched;
  double matchScore = 0.0;
  Map<String, dynamic>? matchedTransaction;

  ParsedBankStatementRow({
    required this.rowIndex,
    required this.dateStr,
    this.parsedDate,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    required this.amount,
    this.balance,
    this.reference,
  });

  bool get isValid => validationErrors.isEmpty;
}

class ReconciliationSummary {
  final int totalRows;
  final int validRows;
  final int autoMatchedCount;
  final int manualMatchedCount;
  final int newTransactionsCount;
  final int unmatchedCount;
  final int invalidCount;

  ReconciliationSummary({
    required this.totalRows,
    required this.validRows,
    required this.autoMatchedCount,
    required this.manualMatchedCount,
    required this.newTransactionsCount,
    required this.unmatchedCount,
    required this.invalidCount,
  });
}
