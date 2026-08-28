import '../../database/db_helper.dart';
import '../../audit/audit_logger.dart';
import '../models/bank_reconciliation_models.dart';

/// Atomic Database Execution Engine for Bank Statement Reconciliation.
class BankReconciliationExecutor {
  BankReconciliationExecutor._();

  /// Executes database reconciliation updates inside a single atomic SQL transaction.
  /// If any error occurs, rolls back changes completely.
  static Future<Map<String, int>> commitReconciliation({
    required int companyId,
    required int bankAccountId,
    required List<ParsedBankStatementRow> rows,
  }) async {
    int autoReconciledCount = 0;
    int manualReconciledCount = 0;
    int newCreatedCount = 0;

    final db = await DBHelper.instance.database;

    await db.transaction((txn) async {
      for (final row in rows) {
        if (row.status == ParsedRowStatus.autoMatched &&
            row.matchedTransaction != null) {
          final candId = row.matchedTransaction!['id'] as int;
          await txn.update(
            'bank_transactions',
            {'is_reconciled': 1},
            where: 'id = ? AND company_id = ?',
            whereArgs: [candId, companyId],
          );
          autoReconciledCount++;
        } else if (row.status == ParsedRowStatus.manualMatch &&
            row.matchedTransaction != null) {
          final candId = row.matchedTransaction!['id'] as int;
          await txn.update(
            'bank_transactions',
            {'is_reconciled': 1},
            where: 'id = ? AND company_id = ?',
            whereArgs: [candId, companyId],
          );
          manualReconciledCount++;
        } else if (row.status == ParsedRowStatus.newTransaction) {
          final isDeposit = row.amount > 0;
          await txn.insert('bank_transactions', {
            'company_id': companyId,
            'bank_account_id': bankAccountId,
            'type': isDeposit ? 'deposit' : 'withdrawal',
            'amount': row.amount.abs(),
            'description': row.description,
            'transaction_date':
                row.parsedDate?.toIso8601String().substring(0, 10) ??
                    row.dateStr,
            'is_reconciled': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          newCreatedCount++;
        }
      }

      await AuditLogger.log(
        companyId: companyId,
        module: 'BankReconciliation',
        action: 'reconcile_statement',
        description:
            'Bank statement reconciled: $autoReconciledCount auto-matched, $manualReconciledCount manual, $newCreatedCount new created',
        afterValue: {
          'auto_matched': autoReconciledCount,
          'manual_matched': manualReconciledCount,
          'new_created': newCreatedCount,
        },
      );
    });

    return {
      'autoMatched': autoReconciledCount,
      'manualMatched': manualReconciledCount,
      'newCreated': newCreatedCount,
    };
  }
}
