class ReconciliationMatchResult {
  final Map<String, dynamic> statementLine;
  final Map<String, dynamic>? matchedLedgerLine;
  final bool isMatched;

  ReconciliationMatchResult({
    required this.statementLine,
    this.matchedLedgerLine,
    required this.isMatched,
  });
}

class AutoBankReconciler {
  /// Matches bank statement lines with system ledger lines:
  /// Rule: 1:1 exact matching by amount and date window (+/- 3 days).
  static List<ReconciliationMatchResult> match({
    required List<Map<String, dynamic>> statementLines,
    required List<Map<String, dynamic>> ledgerLines,
  }) {
    final List<ReconciliationMatchResult> results = [];
    final Set<dynamic> matchedLedgerIds = {};

    for (final sLine in statementLines) {
      final double sDebit = (sLine['debit'] as num?)?.toDouble() ?? 0.0;
      final double sCredit = (sLine['credit'] as num?)?.toDouble() ?? 0.0;
      final String sDateStr =
          (sLine['date'] as String? ?? '').split('T').first;
      final DateTime? sDate = DateTime.tryParse(sDateStr);

      Map<String, dynamic>? matchFound;

      for (final lLine in ledgerLines) {
        final lId =
            lLine['id'] ?? lLine['line_id'] ?? lLine['journal_entry_id'];
        if (matchedLedgerIds.contains(lId)) continue;

        final double lDebit = (lLine['debit'] as num?)?.toDouble() ?? 0.0;
        final double lCredit = (lLine['credit'] as num?)?.toDouble() ?? 0.0;
        final String lDateStr = (lLine['date'] as String? ??
                lLine['entry_date'] as String? ??
                '')
            .split('T')
            .first;
        final DateTime? lDate = DateTime.tryParse(lDateStr);

        // Check exact amount match
        final bool amountMatched =
            ((sDebit - lDebit).abs() < 0.01 && sDebit > 0) ||
                ((sCredit - lCredit).abs() < 0.01 && sCredit > 0) ||
                ((sDebit - lCredit).abs() < 0.01 && sDebit > 0) ||
                ((sCredit - lDebit).abs() < 0.01 && sCredit > 0);

        if (!amountMatched) continue;

        // Check date window (+/- 3 days)
        if (sDate != null && lDate != null) {
          final diffDays = sDate.difference(lDate).inDays.abs();
          if (diffDays <= 3) {
            matchFound = lLine;
            matchedLedgerIds.add(lId);
            break;
          }
        } else if (amountMatched) {
          matchFound = lLine;
          matchedLedgerIds.add(lId);
          break;
        }
      }

      results.add(ReconciliationMatchResult(
        statementLine: sLine,
        matchedLedgerLine: matchFound,
        isMatched: matchFound != null,
      ));
    }

    return results;
  }
}
