import '../../database/db_helper.dart';
import '../models/bank_reconciliation_models.dart';

/// Central Bank Transaction Auto-Matching & Confidence Scoring Engine.
class BankTransactionMatcher {
  BankTransactionMatcher._();

  /// Automatically matches imported statement rows against existing unreconciled bank transactions in DB.
  /// Does NOT modify the database. Returns enriched statement rows with match confidence and scores.
  static Future<List<ParsedBankStatementRow>> autoMatchTransactions({
    required int companyId,
    required int bankAccountId,
    required List<ParsedBankStatementRow> rows,
  }) async {
    final db = await DBHelper.instance.database;

    // Fetch candidate unreconciled bank transactions for this company and bank account
    final candidates = await db.query(
      'bank_transactions',
      where:
          'company_id = ? AND bank_account_id = ? AND (is_reconciled = 0 OR is_reconciled IS NULL)',
      whereArgs: [companyId, bankAccountId],
    );

    final Set<int> matchedCandidateIds = {};

    for (final row in rows) {
      if (!row.isValid) continue;

      final rowAmount = row.amount;
      final rowDate = row.parsedDate;

      if (rowDate == null) continue;

      Map<String, dynamic>? bestCandidate;
      double bestScore = -1.0;
      MatchConfidence bestConfidence = MatchConfidence.unmatched;
      int matchCandidatesCount = 0;

      for (final candidate in candidates) {
        final candId = candidate['id'] as int;
        if (matchedCandidateIds.contains(candId)) continue;

        final type = (candidate['type'] as String? ?? 'deposit').toLowerCase();
        final rawCandAmount = (candidate['amount'] as num?)?.toDouble() ?? 0.0;
        final candAmount = (type == 'withdrawal' || type == 'out')
            ? -rawCandAmount.abs()
            : rawCandAmount.abs();

        // 1. Amount Match Check (Primary Signal: exact signed amount within 0.01)
        if ((candAmount - rowAmount).abs() > 0.02) continue;

        // 2. Date Window Check (+-2 calendar days)
        final candDateStr = candidate['transaction_date'] as String? ?? '';
        final candDate = DateTime.tryParse(candDateStr);
        if (candDate == null) continue;

        final dayDiff = rowDate.difference(candDate).inDays.abs();
        if (dayDiff > 2) continue;

        // 3. Description Similarity Check
        final candDesc = candidate['description'] as String? ?? '';
        final descScore = _calculateSimilarity(row.description, candDesc);

        matchCandidatesCount++;

        if (descScore > bestScore) {
          bestScore = descScore;
          bestCandidate = candidate;

          if (dayDiff == 0 && descScore >= 0.7) {
            bestConfidence = MatchConfidence.exact;
          } else if (descScore >= 0.4) {
            bestConfidence = MatchConfidence.high;
          } else {
            bestConfidence = MatchConfidence.medium;
          }
        }
      }

      // Enforce 1-to-1 matching: if ambiguous multiple candidates, flag for manual review
      if (bestCandidate != null &&
          matchCandidatesCount == 1 &&
          (bestConfidence == MatchConfidence.exact ||
              bestConfidence == MatchConfidence.high)) {
        row.matchedTransaction = bestCandidate;
        row.confidence = bestConfidence;
        row.matchScore = bestScore;
        row.status = ParsedRowStatus.autoMatched;
        matchedCandidateIds.add(bestCandidate['id'] as int);
      } else if (bestCandidate != null) {
        row.matchedTransaction = bestCandidate;
        row.confidence = MatchConfidence.medium;
        row.matchScore = bestScore;
        row.status = ParsedRowStatus.manualMatch; // Needs user review
      } else {
        row.status = ParsedRowStatus.unmatched;
        row.confidence = MatchConfidence.unmatched;
      }
    }

    return rows;
  }

  /// Calculates text similarity score (0.0 to 1.0) using normalized token overlap.
  static double _calculateSimilarity(String s1, String s2) {
    final t1 = _tokenize(s1);
    final t2 = _tokenize(s2);

    if (t1.isEmpty || t2.isEmpty) return 0.0;

    final intersection = t1.intersection(t2).length;
    final union = t1.union(t2).length;

    return union == 0 ? 0.0 : (intersection / union);
  }

  static Set<String> _tokenize(String str) {
    final stopWords = {
      'pos',
      'purchase',
      'trx',
      'txn',
      'pay',
      'payment',
      'transfer',
      'val',
      'card',
      'pkr',
      'rs'
    };
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !stopWords.contains(t))
        .toSet();
  }
}
