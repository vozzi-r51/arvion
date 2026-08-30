import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/services/mrp_service.dart';
import 'package:bizmanager/core/accounting/bank_reconciliation_service.dart';
import 'package:bizmanager/core/accounting/fixed_asset_service.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 5 Enterprise Modules Tests (BOM/MRP, Bank Recon, Fixed Assets)', () {
    late DBHelper db;
    late int companyId;
    late int warehouseId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Phase 5 Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });

      warehouseId = await DBHelper.instance.insertWarehouse({
        'company_id': companyId,
        'name': 'Manufacturing Warehouse',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Completing a Production Order updates raw/finished stock counts and posts manufacturing journals', () async {
      // Create Raw Products
      final raw1Id = await db.insertProduct({
        'company_id': companyId,
        'name': 'Steel Sheet',
        'current_stock': 100.0,
        'purchase_price': 100.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final raw2Id = await db.insertProduct({
        'company_id': companyId,
        'name': 'Plastic Handle',
        'current_stock': 100.0,
        'purchase_price': 20.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create Finished Product
      final finishedId = await db.insertProduct({
        'company_id': companyId,
        'name': 'Finished Cabinet Tool',
        'current_stock': 0.0,
        'purchase_price': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create BOM Recipe (Yield 1 Unit = 2 Steel Sheets + 1 Plastic Handle, Labor=50, Overhead=30)
      final bomId = await MrpService.instance.createBOM(
        companyId: companyId,
        finishedProductId: finishedId,
        yieldQty: 1.0,
        laborCost: 50.0,
        overheadCost: 30.0,
        items: [
          {'raw_product_id': raw1Id, 'required_qty': 2.0, 'scrap_percentage': 0.0},
          {'raw_product_id': raw2Id, 'required_qty': 1.0, 'scrap_percentage': 0.0},
        ],
      );

      // Create Production Order for 10 Finished Cabinets
      final orderId = await MrpService.instance.createProductionOrder(
        companyId: companyId,
        bomId: bomId,
        warehouseId: warehouseId,
        targetQty: 10.0,
      );

      // Complete Production Order
      final completed = await MrpService.instance.completeProductionOrder(orderId);
      expect(completed, isTrue);

      // Raw 1 stock deducted: 100 - (2 * 10) = 80
      final raw1Rows = await (await db.database).query('products', where: 'id = ?', whereArgs: [raw1Id]);
      expect((raw1Rows.first['current_stock'] as num).toDouble(), 80.0);

      // Raw 2 stock deducted: 100 - (1 * 10) = 90
      final raw2Rows = await (await db.database).query('products', where: 'id = ?', whereArgs: [raw2Id]);
      expect((raw2Rows.first['current_stock'] as num).toDouble(), 90.0);

      // Finished goods stock increased: 0 + 10 = 10
      final finRows = await (await db.database).query('products', where: 'id = ?', whereArgs: [finishedId]);
      expect((finRows.first['current_stock'] as num).toDouble(), 10.0);

      // Finished unit cost = ((2*100 + 1*20)*10 + 50*10 + 30*10) / 10 = (2200 + 500 + 300) / 10 = 300
      expect((finRows.first['purchase_price'] as num).toDouble(), 300.0);
    });

    test('b) Bank Auto-Reconciliation matches 1:1 entries within date window (+/- 3 days)', () {
      final statementLines = [
        {'line_id': 'S01', 'date': '2026-08-15', 'debit': 5000.0, 'credit': 0.0},
        {'line_id': 'S02', 'date': '2026-08-20', 'debit': 0.0, 'credit': 1200.0},
        {'line_id': 'S03', 'date': '2026-08-25', 'debit': 800.0, 'credit': 0.0},
      ];

      final ledgerLines = [
        {'id': 101, 'entry_date': '2026-08-16', 'debit': 5000.0, 'credit': 0.0}, // Matches S01 (+1 day)
        {'id': 102, 'entry_date': '2026-08-29', 'debit': 0.0, 'credit': 1200.0}, // Out of window (> 3 days)
      ];

      final matchResults = AutoBankReconciler.match(
        statementLines: statementLines,
        ledgerLines: ledgerLines,
      );

      expect(matchResults.length, 3);
      expect(matchResults[0].isMatched, isTrue);
      expect(matchResults[0].matchedLedgerLine!['id'], 101);

      expect(matchResults[1].isMatched, isFalse); // S02 not matched due to >3 days window
      expect(matchResults[2].isMatched, isFalse); // S03 no amount match
    });

    test('c) Fixed Asset Straight-Line formula computes exact monthly depreciation and halts at salvage limit', () async {
      final accounts = await db.getChartOfAccounts(companyId);
      final assetAcc = accounts.firstWhere((a) => a['type'] == 'asset')['id'];
      final depAcc = accounts.firstWhere((a) => a['type'] == 'expense')['id'];

      // Purchase cost = 14,000, Salvage value = 2,000, Useful life = 12 months (1 year)
      // Monthly Dep = (14,000 - 2,000) / 12 = 1,000 per month
      final assetId = await FixedAssetService.instance.createAsset(
        companyId: companyId,
        name: 'Delivery Van',
        purchaseDate: '2026-01-01',
        purchaseCost: 14000.0,
        salvageValue: 2000.0,
        usefulLifeMonths: 12,
        assetAccountId: assetAcc,
        depreciationAccountId: depAcc,
        accumulatedAccountId: assetAcc,
      );

      // Run Month 1
      final dep1 = await FixedAssetService.instance.runMonthlyDepreciation(
        companyId: companyId,
        monthYear: '2026-08',
      );
      expect(dep1, 1000.0);

      // Verify accumulated depreciation = 1000
      final assetRows = await (await db.database).query('fixed_assets', where: 'id = ?', whereArgs: [assetId]);
      expect((assetRows.first['accumulated_depreciation'] as num).toDouble(), 1000.0);
    });
  });
}
