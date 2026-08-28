import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bizmanager/core/database/db_helper.dart';

import 'package:path/path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bizmanager.db');
    await databaseFactory.deleteDatabase(path);
  });

  test(
      'quotation to sale conversion preserves data and updates stock/accounting',
      () async {
    final db = DBHelper.instance;
    final companyId = await db.insertCompany({
      'name': 'Quotation Test Company',
      'created_at': DateTime.now().toIso8601String(),
    });

    final productId = await (await db.database).insert('products', {
      'company_id': companyId,
      'name': 'Test Product',
      'purchase_price': 50.0,
      'retail_price': 100.0,
      'current_stock': 10.0,
      'low_stock_level': 5.0,
      'created_at': DateTime.now().toIso8601String(),
    });

    final customerId = await (await db.database).insert('customers', {
      'company_id': companyId,
      'name': 'Test Customer',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 1. Create Quotation
    final quoteData = {
      'company_id': companyId,
      'quote_number': 'QT-000001',
      'customer_id': customerId,
      'customer_name': 'Test Customer',
      'quote_date': DateTime.now().toIso8601String(),
      'valid_until':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'subtotal': 100.0,
      'discount_amount': 0.0,
      'tax_amount': 0.0,
      'total_amount': 100.0,
      'status': 'draft',
      'created_at': DateTime.now().toIso8601String(),
    };

    final quoteItems = [
      {
        'product_id': productId,
        'product_name': 'Test Product',
        'quantity': 2.0,
        'unit_price': 100.0,
        'purchase_price': 50.0,
        'total': 200.0,
      }
    ];

    final quoteId = await db.insertQuotationWithItems(
      quotation: quoteData,
      items: quoteItems,
    );

    // Verify stock is NOT deducted yet
    var product = (await db.getProducts(companyId)).first;
    expect(product['current_stock'], 10.0);

    // 2. Convert to Sale
    final saleData = {
      'company_id': companyId,
      'invoice_number': 'INV-000001',
      'customer_id': customerId,
      'customer_name': 'Test Customer',
      'sale_type': 'cash',
      'subtotal': 200.0,
      'discount_amount': 0.0,
      'tax_amount': 0.0,
      'total_amount': 200.0,
      'paid_amount': 200.0,
      'due_amount': 0.0,
      'payment_method': 'Cash',
      'sale_date': DateTime.now().toIso8601String(),
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    };

    await db.convertQuotationToSale(
      quoteId: quoteId,
      saleData: saleData,
    );

    // Verify stock IS deducted now
    product = (await db.getProducts(companyId)).first;
    expect(product['current_stock'], 8.0);

    // Verify quotation status is 'converted'
    final quotations = await db.getQuotations(companyId);
    expect(quotations.first['status'], 'converted');

    // Verify sale exists
    final sales = await db.getSales(companyId);
    expect(sales.length, 1);
    expect(sales.first['invoice_number'], 'INV-000001');

    // Verify accounting (journal entries)
    final journals = await db.getJournalEntries(companyId);
    expect(
        journals.any(
            (j) => j['description'].contains('Converted from Quote $quoteId')),
        isTrue);

    await db.deleteCompanyPermanently(companyId);
  });
}
