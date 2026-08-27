import 'base_repository.dart';
import '../events/domain_event_bus.dart';
import '../di/service_locator.dart';
import 'accounting_repository.dart';

/// Fixed Assets Register & Straight-Line Depreciation Engine.
class FixedAssetsRepository extends BaseRepository {
  FixedAssetsRepository();

  /// Create a new fixed asset.
  Future<int> createAsset(Map<String, dynamic> asset) async {
    final cost = (asset['purchase_cost'] as num).toDouble();
    final salvage = (asset['salvage_value'] as num?)?.toDouble() ?? 0.0;
    asset['accumulated_depreciation'] = 0.0;
    asset['book_value'] = cost - salvage;
    asset['created_at'] = DateTime.now().toIso8601String();

    return await db.insert('fixed_assets', asset);
  }

  /// List all active fixed assets for a company.
  Future<List<Map<String, dynamic>>> listAssets(int companyId) async {
    return await db.query(
      'fixed_assets',
      where: 'company_id = ? AND status != "disposed"',
      whereArgs: [companyId],
      orderBy: 'purchase_date DESC',
    );
  }

  /// Runs monthly straight-line depreciation for all active fixed assets in a company.
  /// Formula: Annual = (Cost - Salvage) / LifeYears; Monthly = Annual / 12
  /// Posts automatic Depreciation Expense & Accumulated Depreciation Journal Entry to GL.
  Future<Map<String, dynamic>> calculateAndRunMonthlyDepreciation({
    required int companyId,
    required String periodDate, // e.g. "2026-08-31"
  }) async {
    final assets = await listAssets(companyId);
    int processedCount = 0;
    double totalDepreciationForMonth = 0.0;

    await runInTransaction((txn) async {
      for (final asset in assets) {
        final assetId = asset['id'] as int;
        final cost = (asset['purchase_cost'] as num).toDouble();
        final salvage = (asset['salvage_value'] as num?)?.toDouble() ?? 0.0;
        final lifeYears = (asset['useful_life_years'] as num?)?.toInt() ?? 5;
        final currentAccum = (asset['accumulated_depreciation'] as num?)?.toDouble() ?? 0.0;
        final currentBook = (asset['book_value'] as num?)?.toDouble() ?? cost;

        if (currentBook <= salvage || lifeYears <= 0) continue;

        // Straight-line monthly depreciation
        final annualDep = (cost - salvage) / lifeYears;
        double monthlyDep = annualDep / 12.0;

        // Ensure we don't depreciate below salvage value
        if (currentBook - monthlyDep < salvage) {
          monthlyDep = currentBook - salvage;
        }

        if (monthlyDep <= 0) continue;

        final newAccum = currentAccum + monthlyDep;
        final newBook = cost - newAccum;
        final newStatus = newBook <= salvage ? 'fully_depreciated' : 'active';

        // Update Fixed Asset record
        await txn.update(
          'fixed_assets',
          {
            'accumulated_depreciation': newAccum,
            'book_value': newBook,
            'status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [assetId],
        );

        // Record Depreciation Log
        await txn.insert('asset_depreciations', {
          'asset_id': assetId,
          'period_date': periodDate,
          'depreciation_amount': monthlyDep,
          'accumulated_depreciation_after': newAccum,
          'book_value_after': newBook,
          'posted_to_gl': 1,
          'created_at': DateTime.now().toIso8601String(),
        });

        totalDepreciationForMonth += monthlyDep;
        processedCount++;
      }
    });

    // Auto-post GL Journal Entry for total depreciation if > 0
    if (totalDepreciationForMonth > 0 && sl.isRegistered<AccountingRepository>()) {
      try {
        final accounts = await sl<AccountingRepository>().getAccounts(companyId);
        int? depExpenseAccountId;
        int? accumDepAccountId;

        for (final acc in accounts) {
          final name = (acc['name'] as String).toLowerCase();
          if (name.contains('depreciation') && name.contains('expense')) {
            depExpenseAccountId = acc['id'] as int;
          } else if (name.contains('accumulated') || name.contains('depreciation')) {
            accumDepAccountId = acc['id'] as int;
          }
        }

        if (depExpenseAccountId != null && accumDepAccountId != null) {
          await sl<AccountingRepository>().createJournalEntry(
            companyId: companyId,
            date: periodDate,
            reference: 'DEP-$periodDate',
            description: 'Auto-posted monthly straight-line fixed asset depreciation',
            lines: [
              {'account_id': depExpenseAccountId, 'debit': totalDepreciationForMonth, 'credit': 0.0},
              {'account_id': accumDepAccountId, 'debit': 0.0, 'credit': totalDepreciationForMonth},
            ],
          );
        }
      } catch (_) {}
    }

    return {
      'processedCount': processedCount,
      'totalDepreciation': totalDepreciationForMonth,
    };
  }
}
