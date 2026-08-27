import 'base_repository.dart';
import '../events/domain_event_bus.dart';

/// Repository for Double-Entry Bookkeeping & General Ledger.
/// Handles Chart of Accounts, Journal Entries, Trial Balance & Balance Sheet.
class AccountingRepository extends BaseRepository {
  AccountingRepository();

  /// Gets all accounts in the Chart of Accounts for a company.
  Future<List<Map<String, dynamic>>> getAccounts(int companyId) async {
    return db.query(
      'chart_of_accounts',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'code ASC',
    );
  }

  /// Creates a manual or auto-posted Journal Entry with debit/credit lines.
  Future<int> createJournalEntry({
    required int companyId,
    required String date,
    required String reference,
    required String description,
    required List<Map<String, dynamic>> lines, // [{account_id, debit, credit, memo}]
  }) async {
    return runInTransaction((txn) async {
      final entryId = await txn.insert('journal_entries', {
        'company_id': companyId,
        'entry_date': date,
        'reference': reference,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final line in lines) {
        await txn.insert('journal_entry_lines', {
          'entry_id': entryId,
          'account_id': line['account_id'],
          'debit': (line['debit'] as num?)?.toDouble() ?? 0.0,
          'credit': (line['credit'] as num?)?.toDouble() ?? 0.0,
          'memo': line['memo'] ?? description,
        });
      }
      return entryId;
    });
  }

  /// Fetches journal entries with pagination.
  Future<List<Map<String, dynamic>>> getJournalEntries(
    int companyId, {
    int? limit,
    int? offset,
  }) async {
    return db.query(
      'journal_entries',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'entry_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches lines for a specific journal entry.
  Future<List<Map<String, dynamic>>> getJournalLines(int entryId) async {
    return db.rawQuery('''
      SELECT l.*, a.name AS account_name, a.code AS account_code, a.type AS account_type
      FROM journal_entry_lines l
      JOIN chart_of_accounts a ON l.account_id = a.id
      WHERE l.entry_id = ?
    ''', [entryId]);
  }

  /// Auto-posts a double-entry journal entry when a Sale is completed.
  /// Debit: Cash / Accounts Receivable
  /// Credit: Sales Revenue
  Future<void> postSaleJournalEntry(SaleCompletedEvent event) async {
    try {
      final accounts = await getAccounts(event.companyId);
      if (accounts.isEmpty) return;

      int? cashOrArAccountId;
      int? salesRevenueAccountId;

      for (final acc in accounts) {
        final type = (acc['type'] as String).toLowerCase();
        final name = (acc['name'] as String).toLowerCase();
        if (event.customerId != null && type == 'asset' && name.contains('receivable')) {
          cashOrArAccountId = acc['id'] as int;
        } else if (cashOrArAccountId == null && type == 'asset' && (name.contains('cash') || name.contains('bank'))) {
          cashOrArAccountId = acc['id'] as int;
        }
        if (type == 'revenue' || name.contains('sale') || name.contains('income')) {
          salesRevenueAccountId = acc['id'] as int;
        }
      }

      if (cashOrArAccountId != null && salesRevenueAccountId != null) {
        await createJournalEntry(
          companyId: event.companyId,
          date: DateTime.now().toIso8601String().substring(0, 10),
          reference: 'SALE-${event.saleId}',
          description: 'Auto-posted sale revenue for Invoice #${event.saleId}',
          lines: [
            {'account_id': cashOrArAccountId, 'debit': event.total, 'credit': 0.0},
            {'account_id': salesRevenueAccountId, 'debit': 0.0, 'credit': event.total},
          ],
        );
      }
    } catch (_) {}
  }
}
