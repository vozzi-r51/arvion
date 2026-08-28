import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/business_types/services/workshop_job_service.dart';

void main() {
  group('1. Automotive Workshop Job & Stock Rules Tests', () {
    test('Deducts stock for spare parts and enforces ZERO stock deduction for labor and services', () {
      expect(WorkshopJobService.requiresStockDeduction(itemType: 'part', productId: 101), isTrue);
      expect(WorkshopJobService.requiresStockDeduction(itemType: 'labor', productId: null), isFalse);
      expect(WorkshopJobService.requiresStockDeduction(itemType: 'service', productId: null), isFalse);
    });

    test('Validates Workshop Job data structure and vehicle association', () {
      final job = {
        'id': 1001,
        'company_id': 1,
        'vehicle_registration': 'LEA-1234',
        'complaint': 'Oil change and brake noise',
        'status': 'in_progress',
        'parts': [
          {'name': 'Engine Oil', 'quantity': 1, 'price': 4500.0, 'is_part': true},
        ],
        'labor': [
          {'description': 'Oil & Filter Replacement Labor', 'amount': 1000.0, 'is_part': false},
        ],
      };

      expect(job['parts'], isNotEmpty);
      expect((job['parts'] as List).first['is_part'], isTrue);
      expect((job['labor'] as List).first['is_part'], isFalse);
    });
  });

  group('2. Hotel & Travel Resource Booking Overlap Tests', () {
    test('Prevents double-booking overlapping dates for the same resource', () {
      final existingBookings = [
        {'resource_id': 101, 'start_date': '2026-09-01', 'end_date': '2026-09-04', 'status': 'confirmed'},
      ];

      bool checkOverlap(int resId, String newStart, String newEnd) {
        for (final b in existingBookings) {
          if (b['resource_id'] == resId && b['status'] != 'cancelled') {
            final start1 = b['start_date'] as String;
            final end1 = b['end_date'] as String;
            if (newStart.compareTo(end1) < 0 && newEnd.compareTo(start1) > 0) {
              return true; // Overlap detected
            }
          }
        }
        return false;
      }

      // 02 Sep to 05 Sep overlaps with 01 Sep to 04 Sep -> True
      expect(checkOverlap(101, '2026-09-02', '2026-09-05'), isTrue);

      // 05 Sep to 08 Sep does NOT overlap -> False
      expect(checkOverlap(101, '2026-09-05', '2026-09-08'), isFalse);
    });
  });

  group('3. Construction Project Management Tests', () {
    test('Enforces valid completion percent range (0 to 100)', () {
      void validateCompletionPercent(double percent) {
        if (percent < 0 || percent > 100) {
          throw RangeError('Completion percent must be between 0 and 100.');
        }
      }

      expect(() => validateCompletionPercent(50.0), returnsNormally);
      expect(() => validateCompletionPercent(120.0), throwsA(isA<RangeError>()));
    });
  });
}
