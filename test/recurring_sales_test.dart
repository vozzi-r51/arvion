import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/services/recurring_sales_service.dart';

void main() {
  group('Recurring Sales Service - Recurrence Date Calculation Tests', () {
    test('Calculates next due date for daily frequency', () {
      final next = RecurringSalesService.calculateNextDueDate('2026-08-28', 'daily');
      expect(next, equals('2026-08-29'));
    });

    test('Calculates next due date for weekly frequency', () {
      final next = RecurringSalesService.calculateNextDueDate('2026-08-28', 'weekly');
      expect(next, equals('2026-09-04'));
    });

    test('Calculates next due date for monthly frequency', () {
      final next = RecurringSalesService.calculateNextDueDate('2026-08-28', 'monthly');
      expect(next, equals('2026-09-28'));
    });

    test('Calculates next due date for yearly frequency', () {
      final next = RecurringSalesService.calculateNextDueDate('2026-08-28', 'yearly');
      expect(next, equals('2027-08-28'));
    });
  });

  group('Recurring Sales Service - Template Duplication Tests', () {
    test('Duplicates recurring template configuration without runtime state or transaction generation', () {
      final original = {
        'company_id': 1,
        'type': 'sale',
        'category': 'Retainer Client X',
        'amount': 25000.0,
        'frequency': 'monthly',
        'next_due_date': '2026-08-28',
        'customer_id': 101,
        'line_items': '[{"product_id": 1, "quantity": 2, "unit_price": 12500.0}]',
        'last_generated_at': '2026-07-28T10:00:00.000',
      };

      final duplicate = RecurringSalesService.prepareDuplicateTemplate(original);

      expect(duplicate['category'], equals('Retainer Client X (Copy)'));
      expect(duplicate['customer_id'], equals(101));
      expect(duplicate['line_items'], equals(original['line_items']));
      expect(duplicate['amount'], equals(25000.0));
      expect(duplicate['last_generated_at'], isNull); // Runtime state cleared
      expect(duplicate['next_due_date'], equals(DateTime.now().toIso8601String().substring(0, 10)));
    });
  });
}
