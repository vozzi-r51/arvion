import '../database/db_helper.dart';

class FixedAssetService {
  FixedAssetService._();
  static final FixedAssetService instance = FixedAssetService._();

  /// Create a new Fixed Asset record.
  Future<dynamic> createAsset({
    required dynamic companyId,
    required String name,
    required String purchaseDate,
    required double purchaseCost,
    double salvageValue = 0.0,
    required int usefulLifeMonths,
    String method = 'STRAIGHT_LINE',
    required dynamic assetAccountId,
    required dynamic depreciationAccountId,
    required dynamic accumulatedAccountId,
  }) async {
    final db = await DBHelper.instance.database;

    final usefulLifeYears = (usefulLifeMonths / 12).ceil().clamp(1, 100);

    final int assetId = await db.insert('fixed_assets', {
      'company_id': companyId,
      'asset_code': 'AST-${DateTime.now().millisecondsSinceEpoch}',
      'asset_name': name,
      'category': 'equipment',
      'purchase_date': purchaseDate,
      'purchase_cost': purchaseCost,
      'salvage_value': salvageValue,
      'useful_life_years': usefulLifeYears,
      'depreciation_method': method.toLowerCase(),
      'accumulated_depreciation': 0.0,
      'book_value': purchaseCost,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });

    return assetId;
  }

  /// Run monthly depreciation for all active fixed assets of a company:
  /// Formula (Straight Line): monthlyDep = (purchase_cost - salvage_value) / (useful_life_years * 12)
  /// Halts depreciation once accumulated_depreciation reaches (purchase_cost - salvage_value).
  /// Posts bulk journal entry: Debit Depreciation Expense, Credit Accumulated Depreciation.
  Future<double> runMonthlyDepreciation({
    required dynamic companyId,
    required String monthYear, // e.g. "2026-08"
  }) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<double>((txn) async {
      final assets = await txn.query(
        'fixed_assets',
        where: 'company_id = ? AND status = ?',
        whereArgs: [companyId, 'active'],
      );

      double totalDepreciation = 0.0;

      for (final asset in assets) {
        final assetId = asset['id'];
        final cost = (asset['purchase_cost'] as num).toDouble();
        final salvage = (asset['salvage_value'] as num).toDouble();
        final years = (asset['useful_life_years'] as num).toInt();
        final months = years * 12;
        final accumulated =
            (asset['accumulated_depreciation'] as num).toDouble();

        final maxDepreciable = cost - salvage;
        if (accumulated >= maxDepreciable || months <= 0) continue;

        double monthlyDep = maxDepreciable / months;
        if (accumulated + monthlyDep > maxDepreciable) {
          monthlyDep = maxDepreciable - accumulated;
        }

        if (monthlyDep <= 0) continue;

        final newAccumulated = accumulated + monthlyDep;
        final newBookValue = cost - newAccumulated;

        await txn.rawUpdate(
          'UPDATE fixed_assets SET accumulated_depreciation = ?, book_value = ? WHERE id = ?',
          [newAccumulated, newBookValue, assetId],
        );

        totalDepreciation += monthlyDep;

        // Post Journal Entry
        final coaRows = await txn.query('chart_of_accounts',
            where: 'company_id = ?', whereArgs: [companyId]);
        int? getAccId(String name) {
          try {
            final target = name.toLowerCase();
            return coaRows.firstWhere((r) {
              final accName = (r['name'] as String).toLowerCase();
              return accName == target || accName.contains(target);
            })['id'] as int;
          } catch (_) {
            return null;
          }
        }

        final depAcc = getAccId('depreciation') ?? getAccId('expense');
        final accAcc = getAccId('accumulated') ?? getAccId('asset');

        if (depAcc != null && accAcc != null) {
          await DBHelper.instance.postAutomatedEntry(
            txn,
            companyId: int.tryParse(companyId.toString()) ?? 1,
            date: '$monthYear-28',
            description:
                'Auto: Fixed Asset Monthly Depreciation ($monthYear) - ${asset['asset_name']}',
            sourceType: 'fixed_asset_depreciation',
            sourceId: int.tryParse(assetId.toString()) ?? 0,
            lines: [
              {'account_id': depAcc, 'debit': monthlyDep, 'credit': 0.0},
              {'account_id': accAcc, 'debit': 0.0, 'credit': monthlyDep},
            ],
          );
        }
      }

      return totalDepreciation;
    });
  }
}
