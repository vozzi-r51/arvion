import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Sync Changelog Transaction Delta Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Changelog Test Company ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('insertSaleWithItems writes valid JSON payload to sync_changelog', () async {
      final saleData = {
        'company_id': companyId,
        'invoice_number': 'INV-TEST-001',
        'sale_type': 'cash',
        'subtotal': 1000.0,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'total_amount': 1000.0,
        'paid_amount': 1000.0,
        'due_amount': 0.0,
        'sale_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {
          'product_name': 'Test Item 1',
          'quantity': 2.0,
          'unit_price': 500.0,
          'total': 1000.0,
        }
      ];

      final saleId = await db.insertSaleWithItems(
        sale: saleData,
        items: itemsData,
        allowNegativeStock: true,
      );

      expect(saleId, isPositive);

      final changelogs = await db.getPendingSyncChangelogs();
      final saleLogs = changelogs.where((c) => c['table_name'] == 'sales').toList();

      expect(saleLogs.isNotEmpty, isTrue);
      final log = saleLogs.last;
      expect(log['row_id'], saleId.toString());
      expect(log['operation_type'], 'INSERT');

      final payload = jsonDecode(log['columns_payload'] as String);
      expect(payload['invoice_number'], 'INV-TEST-001');
      expect((payload['total_amount'] as num).toDouble(), 1000.0);
    });

    test('insertPurchaseWithItems writes valid JSON payload to sync_changelog', () async {
      final purchaseData = {
        'company_id': companyId,
        'invoice_number': 'PUR-TEST-001',
        'subtotal': 2000.0,
        'tax_amount': 0.0,
        'total_amount': 2000.0,
        'paid_amount': 2000.0,
        'due_amount': 0.0,
        'purchase_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {
          'product_name': 'Raw Material A',
          'quantity': 4.0,
          'unit_cost': 500.0,
          'total': 2000.0,
        }
      ];

      final purchaseId = await db.insertPurchaseWithItems(
        purchase: purchaseData,
        items: itemsData,
      );

      expect(purchaseId, isPositive);

      final changelogs = await db.getPendingSyncChangelogs();
      final purLogs = changelogs.where((c) => c['table_name'] == 'purchases').toList();

      expect(purLogs.isNotEmpty, isTrue);
      final log = purLogs.last;
      expect(log['row_id'], purchaseId.toString());
      expect(log['operation_type'], 'INSERT');

      final payload = jsonDecode(log['columns_payload'] as String);
      expect(payload['invoice_number'], 'PUR-TEST-001');
    });

    test('insertJournalEntryWithLines writes valid JSON payload to sync_changelog', () async {
      final accounts = await db.getChartOfAccounts(companyId);
      final cashId = accounts.firstWhere((a) => a['name'] == 'Cash')['id'] as int;
      final revenueId = accounts.firstWhere((a) => a['name'] == 'Sales Revenue')['id'] as int;

      final entryId = await db.insertJournalEntryWithLines(
        entry: {
          'company_id': companyId,
          'entry_date': DateTime.now().toIso8601String(),
          'description': 'Test Manual Journal JV-101',
          'source_type': 'manual',
          'created_at': DateTime.now().toIso8601String(),
        },
        lines: [
          {'account_id': cashId, 'debit': 5000.0, 'credit': 0.0},
          {'account_id': revenueId, 'debit': 0.0, 'credit': 5000.0},
        ],
      );

      expect(entryId, isPositive);

      final changelogs = await db.getPendingSyncChangelogs();
      final jvLogs = changelogs.where((c) => c['table_name'] == 'journal_entries').toList();

      expect(jvLogs.isNotEmpty, isTrue);
      final log = jvLogs.last;
      expect(log['row_id'], entryId.toString());
      expect(log['operation_type'], 'INSERT');

      final payload = jsonDecode(log['columns_payload'] as String);
      expect(payload['description'], 'Test Manual Journal JV-101');
    });
  });
}
