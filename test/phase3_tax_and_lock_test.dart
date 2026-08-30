import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/auth/permission_service.dart';
import 'package:bizmanager/core/accounting/fiscal_period_guard.dart';
import 'package:bizmanager/core/accounting/tax_calculator.dart';
import 'package:bizmanager/core/utils/uuid_v7.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 3 Dynamic Tax Engine & Fiscal Period Hard-Locking Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Phase 3 Governance Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Attempting to write a sale into a locked fiscal period throws FiscalPeriodLockedException', () async {
      final dbConn = await db.database;

      final yearId = UUIDv7.generate();
      await dbConn.insert('fiscal_years', {
        'fiscal_year_id': yearId,
        'company_id': companyId.toString(),
        'name': 'FY 2026',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'is_closed': 0,
      });

      // Lock August 2026
      final periodId = UUIDv7.generate();
      await dbConn.insert('fiscal_periods', {
        'period_id': periodId,
        'fiscal_year_id': yearId,
        'company_id': companyId.toString(),
        'period_name': 'August 2026',
        'start_date': '2026-08-01',
        'end_date': '2026-08-31',
        'is_locked': 1,
        'locked_at': DateTime.now().toIso8601String(),
        'locked_by': 'AUDITOR_001',
        'lock_reason': 'Audited Close',
      });

      final saleData = {
        'company_id': companyId,
        'invoice_number': 'INV-LOCKED-001',
        'sale_type': 'cash',
        'subtotal': 1000.0,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'total_amount': 1000.0,
        'paid_amount': 1000.0,
        'due_amount': 0.0,
        'sale_date': '2026-08-15T12:00:00.000', // Falls inside locked August 2026
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {
          'product_name': 'Locked Period Item',
          'quantity': 1.0,
          'unit_price': 1000.0,
          'total': 1000.0,
        }
      ];

      expect(
        () async => await db.insertSaleWithItems(
          sale: saleData,
          items: itemsData,
          allowNegativeStock: true,
        ),
        throwsA(isA<FiscalPeriodLockedException>()),
      );
    });

    test('b) TaxCalculator computes multi-tier taxes (18% GST + 2% Extra Levy - 4% WHT) correctly', () {
      final double baseAmount = 10000.0;
      final appliedTaxes = [
        {
          'tax_rate_id': 'RATE_GST_18',
          'account_id': '101',
          'name': 'Standard Sales Tax 18%',
          'rate': 18.0,
          'calculation_type': 'PERCENTAGE',
          'tax_type': 'OUTPUT_TAX',
        },
        {
          'tax_rate_id': 'RATE_EXTRA_2',
          'account_id': '102',
          'name': 'Extra Levy 2%',
          'rate': 2.0,
          'calculation_type': 'PERCENTAGE',
          'tax_type': 'OUTPUT_TAX',
        },
        {
          'tax_rate_id': 'RATE_WHT_4',
          'account_id': '103',
          'name': 'Withholding Tax 4%',
          'rate': 4.0,
          'calculation_type': 'PERCENTAGE',
          'tax_type': 'WITHHOLDING',
        },
      ];

      final result = TaxCalculator.computeTaxes(
        baseAmount: baseAmount,
        appliedTaxRates: appliedTaxes,
      );

      expect(result.grossAmount, 10000.0);
      expect(result.totalOutputTax, 2000.0); // 1800 + 200
      expect(result.totalWithholdingTax, 400.0); // 400
      expect(result.netReceivableOrPayable, 11600.0); // 10000 + 2000 - 400
      expect(result.taxLines.length, 3);
    });

    test('c) Unlocking a period permits posting, while re-locking blocks subsequent mutations', () async {
      final dbConn = await db.database;

      final yearId = UUIDv7.generate();
      await dbConn.insert('fiscal_years', {
        'fiscal_year_id': yearId,
        'company_id': companyId.toString(),
        'name': 'FY 2026',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'is_closed': 0,
      });

      final periodId = UUIDv7.generate();
      await dbConn.insert('fiscal_periods', {
        'period_id': periodId,
        'fiscal_year_id': yearId,
        'company_id': companyId.toString(),
        'period_name': 'September 2026',
        'start_date': '2026-09-01',
        'end_date': '2026-09-30',
        'is_locked': 1,
      });

      // Assert locked initially
      expect(
        () async => await FiscalPeriodGuard.assertDateNotLocked(
          dbConn,
          companyId: companyId,
          transactionDate: '2026-09-10',
        ),
        throwsA(isA<FiscalPeriodLockedException>()),
      );

      // Unlock period
      await dbConn.rawUpdate(
        'UPDATE fiscal_periods SET is_locked = 0 WHERE period_id = ?',
        [periodId],
      );

      // Assert writing is now permitted without exception
      await FiscalPeriodGuard.assertDateNotLocked(
        dbConn,
        companyId: companyId,
        transactionDate: '2026-09-10',
      );

      // Re-lock period
      await dbConn.rawUpdate(
        'UPDATE fiscal_periods SET is_locked = 1 WHERE period_id = ?',
        [periodId],
      );

      // Assert locked again
      expect(
        () async => await FiscalPeriodGuard.assertDateNotLocked(
          dbConn,
          companyId: companyId,
          transactionDate: '2026-09-10',
        ),
        throwsA(isA<FiscalPeriodLockedException>()),
      );
    });
  });
}
