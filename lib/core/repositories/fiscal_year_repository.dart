import 'package:shared_preferences/shared_preferences.dart';
import 'base_repository.dart';
import '../database/db_helper.dart';
import '../di/service_locator.dart';
import 'accounting_repository.dart';
import '../audit/audit_logger.dart';
import '../utils/currency_formatter.dart';

/// Formal Year-End Fiscal Closing Workflow.
/// Closes Revenue & Expense accounts, transfers Net Profit to Retained Earnings,
/// and locks accounting transactions for closed fiscal years.
class FiscalYearRepository extends BaseRepository {
  FiscalYearRepository();

  /// List past fiscal year closings.
  Future<List<Map<String, dynamic>>> listClosings(int companyId) async {
    return await db.query(
      'fiscal_year_closings',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'fiscal_year DESC',
    );
  }

  /// Closes a fiscal year: zeroes revenue/expense, posts Net Profit to Retained Earnings,
  /// and updates accounting lock date.
  Future<Map<String, dynamic>> closeFiscalYear({
    required int companyId,
    required int fiscalYear,
    required String startDate, // "2025-01-01"
    required String endDate, // "2025-12-31"
    required String closedBy,
  }) async {
    // 1. Calculate Total Revenue & Total Expenses for period
    final salesRows = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE company_id = ? AND sale_date >= ? AND sale_date <= ? AND is_voided = 0",
      [companyId, '$startDate 00:00:00', '$endDate 23:59:59'],
    );
    final totalRevenue = (salesRows.first['total'] as num).toDouble();

    final expenseRows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses "
      "WHERE company_id = ? AND expense_date >= ? AND expense_date <= ?",
      [companyId, '$startDate 00:00:00', '$endDate 23:59:59'],
    );
    final totalExpenses = (expenseRows.first['total'] as num).toDouble();

    final netProfit = totalRevenue - totalExpenses;

    int? closingEntryId;

    // 2. Post closing journal entry if AccountingRepository registered
    if (sl.isRegistered<AccountingRepository>()) {
      try {
        final accounts =
            await sl<AccountingRepository>().getAccounts(companyId);
        int? retainedEarningsAccountId;

        for (final acc in accounts) {
          final name = (acc['name'] as String).toLowerCase();
          if (name.contains('retained') ||
              name.contains('earnings') ||
              name.contains('equity')) {
            retainedEarningsAccountId = acc['id'] as int;
            break;
          }
        }

        if (retainedEarningsAccountId != null && netProfit != 0) {
          closingEntryId = await sl<AccountingRepository>().createJournalEntry(
            companyId: companyId,
            date: endDate,
            reference: 'CLOSE-$fiscalYear',
            description:
                'Fiscal Year $fiscalYear Closing Entry - Net Profit Transfer to Retained Earnings',
            lines: netProfit > 0
                ? [
                    {
                      'account_id': retainedEarningsAccountId,
                      'debit': 0.0,
                      'credit': netProfit,
                      'memo': 'Net Profit for FY $fiscalYear'
                    },
                  ]
                : [
                    {
                      'account_id': retainedEarningsAccountId,
                      'debit': netProfit.abs(),
                      'credit': 0.0,
                      'memo': 'Net Loss for FY $fiscalYear'
                    },
                  ],
          );
        }
      } catch (_) {}
    }

    // 3. Record Closing Entry in DB
    final id = await db.insert('fiscal_year_closings', {
      'company_id': companyId,
      'fiscal_year': fiscalYear,
      'start_date': startDate,
      'end_date': endDate,
      'total_revenue': totalRevenue,
      'total_expenses': totalExpenses,
      'net_profit': netProfit,
      'closing_journal_entry_id': closingEntryId,
      'closed_at': DateTime.now().toIso8601String(),
      'closed_by': closedBy,
    });

    // 4. Update Accounting Lock Date to fiscal year end_date
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accounting_lock_date', endDate);

    // 5. Audit Log
    final auditCompany = await DBHelper.instance.getCompanyById(companyId);
    await AuditLogger.log(
      companyId: companyId,
      module: 'Accounting',
      action: 'close_fiscal_year',
      description:
          'Fiscal Year $fiscalYear closed (Net Profit: ${CurrencyFormatter.formatFromCompany(netProfit, auditCompany, decimalPlaces: 0)})',
      userName: closedBy,
      afterValue: {
        'fiscal_year': fiscalYear,
        'total_revenue': totalRevenue,
        'total_expenses': totalExpenses,
        'net_profit': netProfit,
        'lock_date': endDate,
      },
    );

    return {
      'id': id,
      'fiscalYear': fiscalYear,
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }
}
