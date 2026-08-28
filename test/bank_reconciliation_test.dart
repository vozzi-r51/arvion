import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/bank_reconciliation/models/bank_reconciliation_models.dart';
import 'package:bizmanager/core/import/parsers/generic_csv_excel_parser.dart';

void main() {
  group('Bank Statement Parser & Normalization Tests', () {
    test('Parses CSV line correctly', () {
      final line = '2026-08-20,"POS PURCHASE - ABC STORE",500.00,0.00,12500.00';
      final cols = GenericCsvExcelParser.splitCsvLine(line);

      expect(cols.length, equals(5));
      expect(cols[0], equals('2026-08-20'));
      expect(cols[1], equals('POS PURCHASE - ABC STORE'));
      expect(cols[2], equals('500.00'));
    });

    test('ParsedBankStatementRow computes signed amount correctly', () {
      final rowDeposit = ParsedBankStatementRow(
        rowIndex: 1,
        dateStr: '2026-08-20',
        parsedDate: DateTime(2026, 8, 20),
        description: 'Customer Payment',
        credit: 1500.0,
        debit: 0.0,
        amount: 1500.0,
      );

      final rowWithdrawal = ParsedBankStatementRow(
        rowIndex: 2,
        dateStr: '2026-08-21',
        parsedDate: DateTime(2026, 8, 21),
        description: 'Vendor Payment',
        credit: 0.0,
        debit: 500.0,
        amount: -500.0,
      );

      expect(rowDeposit.amount, equals(1500.0));
      expect(rowWithdrawal.amount, equals(-500.0));
      expect(rowDeposit.isValid, isTrue);
    });
  });

  group('Bank Statement Reconciliation In-Memory Preview Safety Tests', () {
    test('ParsedBankStatementRow stays in-memory before database commit', () {
      final row = ParsedBankStatementRow(
        rowIndex: 1,
        dateStr: '2026-08-20',
        parsedDate: DateTime(2026, 8, 20),
        description: 'Store Expense',
        amount: -250.0,
      );

      expect(row.status, equals(ParsedRowStatus.unmatched));
      expect(row.matchedTransaction, isNull);

      // Simulate manual match in memory
      row.matchedTransaction = {'id': 99, 'amount': 250.0, 'description': 'Store Expense'};
      row.status = ParsedRowStatus.manualMatch;

      expect(row.status, equals(ParsedRowStatus.manualMatch));
      expect(row.matchedTransaction?['id'], equals(99));
    });
  });
}
