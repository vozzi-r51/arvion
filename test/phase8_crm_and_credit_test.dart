import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/sales/credit_guard.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 8 Enterprise CRM & Credit Enforcement Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Credit Guard Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Credit sale for customer on administrative credit_hold throws CreditLimitExceededException', () async {
      final customerId = await db.insertCustomer({
        'company_id': companyId,
        'name': 'Held Customer',
        'credit_limit': 10000.0,
        'credit_hold': 1, // Administrative Hold
        'current_balance': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final saleData = {
        'company_id': companyId,
        'customer_id': customerId,
        'invoice_number': 'INV-HOLD-001',
        'sale_type': 'credit',
        'subtotal': 1000.0,
        'total_amount': 1000.0,
        'paid_amount': 0.0,
        'due_amount': 1000.0,
        'sale_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {'product_name': 'Sample Product', 'quantity': 1.0, 'unit_price': 1000.0, 'total': 1000.0}
      ];

      expect(
        () async => await db.insertSaleWithItems(
          sale: saleData,
          items: itemsData,
          allowNegativeStock: true,
        ),
        throwsA(isA<CreditLimitExceededException>()),
      );
    });

    test('b) Credit sale exceeding credit_limit throws CreditLimitExceededException', () async {
      final customerId = await db.insertCustomer({
        'company_id': companyId,
        'name': 'Limit Customer',
        'credit_limit': 5000.0, // Limit is 5,000 PKR
        'credit_hold': 0,
        'current_balance': 4000.0, // Already owes 4,000 PKR
        'created_at': DateTime.now().toIso8601String(),
      });

      final saleData = {
        'company_id': companyId,
        'customer_id': customerId,
        'invoice_number': 'INV-OVER-001',
        'sale_type': 'credit',
        'subtotal': 2000.0,
        'total_amount': 2000.0,
        'paid_amount': 0.0,
        'due_amount': 2000.0, // 4,000 + 2,000 = 6,000 > 5,000 limit!
        'sale_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {'product_name': 'Sample Product', 'quantity': 2.0, 'unit_price': 1000.0, 'total': 2000.0}
      ];

      expect(
        () async => await db.insertSaleWithItems(
          sale: saleData,
          items: itemsData,
          allowNegativeStock: true,
        ),
        throwsA(isA<CreditLimitExceededException>()),
      );
    });

    test('c) Cash sale or credit sale within limit completes successfully', () async {
      final customerId = await db.insertCustomer({
        'company_id': companyId,
        'name': 'Good Customer',
        'credit_limit': 10000.0,
        'credit_hold': 0,
        'current_balance': 1000.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final saleData = {
        'company_id': companyId,
        'customer_id': customerId,
        'invoice_number': 'INV-GOOD-001',
        'sale_type': 'credit',
        'subtotal': 2000.0,
        'total_amount': 2000.0,
        'paid_amount': 0.0,
        'due_amount': 2000.0, // 1,000 + 2,000 = 3,000 <= 10,000 limit!
        'sale_date': DateTime.now().toIso8601String(),
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      };

      final itemsData = [
        {'product_name': 'Sample Product', 'quantity': 2.0, 'unit_price': 1000.0, 'total': 2000.0}
      ];

      final saleId = await db.insertSaleWithItems(
        sale: saleData,
        items: itemsData,
        allowNegativeStock: true,
      );

      expect(saleId, isPositive);
    });
  });
}
