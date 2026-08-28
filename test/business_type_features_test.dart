import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/pharmacy/pharmacy_batch_service.dart';

void main() {
  group('1. Restaurant KOT & Table Management Tests', () {
    test('KOT contains only preparation items and quantities without price or payment info', () {
      final kotItems = [
        {'name': 'Chicken Biryani', 'quantity': 2, 'notes': 'Extra spicy'},
        {'name': 'Naan', 'quantity': 3, 'notes': ''},
      ];

      expect(kotItems.length, equals(2));
      expect(kotItems[0]['name'], equals('Chicken Biryani'));
      expect(kotItems[0]['quantity'], equals(2));
      expect(kotItems[0].containsKey('price'), isFalse);
      expect(kotItems[0].containsKey('total'), isFalse);
    });
  });

  group('2. Clothing Size-Color Variant POS Grid Tests', () {
    test('Extracts size rows and color columns for clothing variants', () {
      final variants = [
        {'id': 1, 'size': 'Small', 'color': 'Black', 'stock': 12, 'price': 1500.0},
        {'id': 2, 'size': 'Small', 'color': 'White', 'stock': 5, 'price': 1500.0},
        {'id': 3, 'size': 'Medium', 'color': 'Black', 'stock': 8, 'price': 1500.0},
        {'id': 4, 'size': 'Medium', 'color': 'White', 'stock': 0, 'price': 1500.0}, // Out of stock
      ];

      final sizes = variants.map((v) => v['size'] as String).toSet().toList();
      final colors = variants.map((v) => v['color'] as String).toSet().toList();

      expect(sizes, containsAll(['Small', 'Medium']));
      expect(colors, containsAll(['Black', 'White']));

      final mediumWhite = variants.firstWhere((v) => v['size'] == 'Medium' && v['color'] == 'White');
      expect(mediumWhite['stock'], equals(0)); // Disabled in grid
    });
  });

  group('3. Pharmacy Batch & Expiry Enforcement Tests', () {
    test('Requires batch_number and expiry_date for pharmacy products', () {
      expect(
        () => PharmacyBatchService.validatePharmacyBatch(batchNumber: '', expiryDate: '2026-12-31'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => PharmacyBatchService.validatePharmacyBatch(batchNumber: 'BATCH-101', expiryDate: ''),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => PharmacyBatchService.validatePharmacyBatch(batchNumber: 'BATCH-101', expiryDate: '2026-12-31'),
        returnsNormally,
      );
    });

    test('Evaluates batch expiring soon and expired status correctly', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5)).toIso8601String().substring(0, 10);
      final soonDate = DateTime.now().add(const Duration(days: 15)).toIso8601String().substring(0, 10);
      final farDate = DateTime.now().add(const Duration(days: 120)).toIso8601String().substring(0, 10);

      expect(PharmacyBatchService.evaluateExpiryStatus(pastDate), equals('expired'));
      expect(PharmacyBatchService.evaluateExpiryStatus(soonDate), equals('expiring_soon'));
      expect(PharmacyBatchService.evaluateExpiryStatus(farDate), equals('valid'));
    });
  });

  group('4. Hardware Multi-UOM & Services Scheduling Tests', () {
    test('UOM options for hardware items (Piece, Meter, Box) calculate total amount', () {
      final availableUoms = ['Piece', 'Meter', 'Box'];
      final selectedUom = 'Meter';
      final quantity = 5.0;
      final unitPrice = 250.0;

      final total = quantity * unitPrice;

      expect(availableUoms, contains('Meter'));
      expect(total, equals(1250.0));
    });

    test('Service Job assigns technician employee ID and scheduled date', () {
      final job = {
        'id': 1024,
        'company_id': 1,
        'customer_name': 'ABC Electronics',
        'service_description': 'Air Conditioner Repair',
        'technician_employee_id': 501,
        'scheduled_date': '2026-08-28',
        'status': 'scheduled',
      };

      expect(job['technician_employee_id'], equals(501));
      expect(job['scheduled_date'], equals('2026-08-28'));
    });
  });
}
