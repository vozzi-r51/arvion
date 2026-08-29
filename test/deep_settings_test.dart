import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/utils/app_formatters.dart';

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
      'deep settings: formatters, custom document numbering, tax codes, and price lists',
      () async {
    final db = DBHelper.instance;

    // 1. Test AppFormatters
    final pkrFormatted =
        AppFormatters.formatCurrency(1250, symbol: 'Rs.', decimals: 0);
    expect(pkrFormatted, 'Rs. 1,250');

    final usdFormatted =
        AppFormatters.formatCurrency(1250.5, symbol: '\$', decimals: 2);
    expect(usdFormatted, '\$ 1,250.50');

    final euroStyle = AppFormatters.formatCurrency(1250.5,
        symbol: '€', decimals: 2, style: 'european');
    expect(euroStyle, '€ 1.250,50');

    final formattedDate =
        AppFormatters.formatDate(DateTime(2026, 8, 27), pattern: 'dd/MM/yyyy');
    expect(formattedDate, '27/08/2026');

    // 2. Company with Custom Numbering & Settings
    final companyId = await db.insertCompany({
      'name': 'Deep Settings Company',
      'currency_symbol': '\$',
      'decimal_places': 2,
      'date_format': 'MM/dd/yyyy',
      'invoice_prefix': 'INV-US',
      'invoice_number_format': '{PREFIX}-{YEAR}-{NUMBER}',
      'created_at': DateTime.now().toIso8601String(),
    });

    final invoiceNum = await db.generateInvoiceNumber(companyId);
    expect(invoiceNum, 'INV-US-2026-000001');

    // 3. Tax Codes
    final taxId = await db.insertTaxCode({
      'company_id': companyId,
      'name': 'GST 17%',
      'rate': 17.0,
      'is_default': 1,
    });
    expect(taxId, isPositive);

    final taxCodes = await db.getTaxCodes(companyId);
    expect(taxCodes, hasLength(1));
    expect(taxCodes.first['rate'], 17.0);

    // 4. Price Lists
    final productId = await db.insertProduct({
      'company_id': companyId,
      'name': 'Widget A',
      'purchase_price': 50.0,
      'retail_price': 100.0,
      'current_stock': 10.0,
      'created_at': DateTime.now().toIso8601String(),
    });

    final priceListId = await db.insertPriceList(companyId, 'VIP List');
    await db.saveProductPrices(priceListId, {productId: 85.0});

    final vipPrice = await db.getProductPriceForList(priceListId, productId);
    expect(vipPrice, 85.0);

    await db.deleteCompanyPermanently(companyId);
  });
}
