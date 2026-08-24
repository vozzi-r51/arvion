import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukanedge/core/database/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('journal posting is atomic and balanced', () async {
    final db = DBHelper.instance;
    final companyId = await db.insertCompany({
      'name': 'Accounting Test Company',
      'created_at': DateTime.now().toIso8601String(),
    });
    final accounts = await db.getChartOfAccounts(companyId);
    final cashId = accounts.firstWhere((a) => a['name'] == 'Cash')['id'] as int;
    final revenueId =
        accounts.firstWhere((a) => a['name'] == 'Sales Revenue')['id'] as int;
    final productId = await (await db.database).insert('products', {
      'company_id': companyId,
      'name': 'Test Product',
      'purchase_price': 50.0,
      'current_stock': 10.0,
      'created_at': DateTime.now().toIso8601String(),
    });
    final customerId = await (await db.database).insert('customers', {
      'company_id': companyId,
      'name': 'Test Customer',
      'created_at': DateTime.now().toIso8601String(),
    });
    final bankId = await (await db.database).insert('bank_accounts', {
      'company_id': companyId,
      'bank_name': 'Test Bank',
      'created_at': DateTime.now().toIso8601String(),
    });
    final entry = {
      'company_id': companyId,
      'entry_date': '2026-08-24T00:00:00.000',
      'description': 'Test sale',
      'created_at': DateTime.now().toIso8601String(),
    };

    expect(
      () => db.insertJournalEntryWithLines(
        entry: entry,
        lines: [
          {'account_id': cashId, 'debit': 100.0, 'credit': 0.0},
          {'account_id': revenueId, 'debit': 0.0, 'credit': 90.0},
        ],
      ),
      throwsArgumentError,
    );
    expect(await db.getJournalEntries(companyId), isEmpty);

    await db.insertStockAdjustment({
      'company_id': companyId,
      'product_id': productId,
      'product_name': 'Test Product',
      'type': 'damage',
      'quantity': 2.0,
      'reason': 'Damaged in test',
      'adjustment_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    });
    final adjustedProduct = (await db.getProducts(companyId)).first;
    expect(adjustedProduct['current_stock'], 8.0);
    expect(await db.getStockAdjustments(companyId), hasLength(1));

    expect(
      () => db.insertSaleWithItems(
        sale: {
          'company_id': companyId,
          'invoice_number': 'TEST-001',
          'sale_date': '2026-08-24T00:00:00.000',
          'created_at': DateTime.now().toIso8601String(),
        },
        items: [
          {
            'product_id': productId,
            'product_name': 'Test Product',
            'quantity': -1.0,
            'unit_price': 100.0,
            'purchase_price': 50.0,
            'total': -100.0,
          },
        ],
      ),
      throwsArgumentError,
    );
    expect(await db.getSales(companyId), isEmpty);

    expect(
      () => db.insertCustomerPayment({
        'company_id': companyId,
        'customer_id': customerId,
        'amount': -25.0,
        'payment_date': '2026-08-24T00:00:00.000',
        'payment_method': 'Cash',
      }),
      throwsArgumentError,
    );
    expect(await db.getCustomerPayments(customerId), isEmpty);

    expect(
      () => db.insertExpense({
        'company_id': companyId,
        'category': 'Rent',
        'amount': 0.0,
        'expense_date': '2026-08-24T00:00:00.000',
        'payment_method': 'Cash',
        'created_at': DateTime.now().toIso8601String(),
      }),
      throwsArgumentError,
    );

    final incomeId = await db.insertIncome({
      'company_id': companyId,
      'category': 'Other Income',
      'amount': 75.0,
      'income_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    });
    expect(await db.getIncome(companyId), hasLength(1));
    final incomeJournals = (await db.getJournalEntries(companyId))
        .where((journal) => journal['description'] == 'Auto: Income #$incomeId - Other Income')
        .toList();
    expect(incomeJournals, hasLength(1));
    final incomeLines = await db.getJournalEntryLines(incomeJournals.first['id'] as int);
    expect(
      incomeLines.fold<double>(0, (sum, line) => sum + (line['debit'] as num)),
      75,
    );
    expect(
      incomeLines.fold<double>(0, (sum, line) => sum + (line['credit'] as num)),
      75,
    );
    await db.updateIncome(incomeId, {'amount': 100.0});
    expect(
      (await db.getJournalEntries(companyId))
          .where((journal) => journal['description'] == 'REVERSAL: Income #$incomeId')
          .length,
      1,
    );
    await db.deleteIncome(incomeId);
    expect(await db.getIncome(companyId), isEmpty);
    expect(
      (await db.getJournalEntries(companyId))
          .where((journal) => journal['description'] == 'REVERSAL: Income #$incomeId')
          .length,
      2,
    );

    expect(
      () => db.insertCashTransaction({
        'company_id': companyId,
        'type': 'in',
        'amount': 0.0,
        'transaction_date': '2026-08-24T00:00:00.000',
        'created_at': DateTime.now().toIso8601String(),
      }),
      throwsArgumentError,
    );

    await db.insertBankTransaction({
      'company_id': companyId,
      'bank_account_id': bankId,
      'type': 'deposit',
      'amount': 250.0,
      'transaction_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    });
    var bank = (await db.getBankAccounts(companyId)).first;
    expect(bank['current_balance'], 250.0);
    final transactionId = (await db.getBankTransactions(bankId)).first['id'] as int;
    await db.deleteBankTransaction(transactionId);
    bank = (await db.getBankAccounts(companyId)).first;
    expect(bank['current_balance'], 0.0);

    final employeeId = await (await db.database).insert('employees', {
      'company_id': companyId,
      'name': 'Test Employee',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insertAdvance({
      'company_id': companyId,
      'employee_id': employeeId,
      'amount': 100.0,
      'recovered_amount': 0.0,
      'advance_date': '2026-08-24T00:00:00.000',
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    final advanceId = (await db.getAdvances(employeeId)).first['id'] as int;
    expect(() => db.recoverAdvance(advanceId, 101.0), throwsArgumentError);

    final committeeId = await (await db.database).insert('committees', {
      'company_id': companyId,
      'name': 'Test Committee',
      'start_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    });
    final memberId = await (await db.database).insert('committee_members', {
      'company_id': companyId,
      'committee_id': committeeId,
      'member_name': 'Test Member',
      'join_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    });
    final draw = {
      'company_id': companyId,
      'committee_id': committeeId,
      'member_id': memberId,
      'amount': 100.0,
      'draw_date': '2026-08-24T00:00:00.000',
      'created_at': DateTime.now().toIso8601String(),
    };
    await db.insertCommitteeDraw(draw);
    expect(() => db.insertCommitteeDraw(draw), throwsStateError);

    final entryId = await db.insertJournalEntryWithLines(
      entry: entry,
      lines: [
        {'account_id': cashId, 'debit': 100.0, 'credit': 0.0},
        {'account_id': revenueId, 'debit': 0.0, 'credit': 100.0},
      ],
    );
    final lines = await db.getJournalEntryLines(entryId);
    expect(lines, hasLength(2));
    expect(
      lines.fold<double>(0, (sum, line) => sum + (line['debit'] as num)),
      100,
    );
    expect(
      lines.fold<double>(0, (sum, line) => sum + (line['credit'] as num)),
      100,
    );

    await db.deleteCompanyPermanently(companyId);
  });
}
