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

  test('manufacturing module complete lifecycle: BOM, Production Order, Stock & Accounting', () async {
    final db = DBHelper.instance;
    final companyId = await db.insertCompany({
      'name': 'Manufacturing Test Company',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 1. Create 3 Raw Material Products
    final rm1Id = await db.insertProduct({
      'company_id': companyId,
      'name': 'Cloth',
      'purchase_price': 100.0,
      'current_stock': 50.0, // 50 meters
      'created_at': DateTime.now().toIso8601String(),
    });

    final rm2Id = await db.insertProduct({
      'company_id': companyId,
      'name': 'Buttons',
      'purchase_price': 5.0,
      'current_stock': 200.0, // 200 buttons
      'created_at': DateTime.now().toIso8601String(),
    });

    final rm3Id = await db.insertProduct({
      'company_id': companyId,
      'name': 'Zipper',
      'purchase_price': 20.0,
      'current_stock': 50.0, // 50 zippers
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Create Finished Product
    final fgId = await db.insertProduct({
      'company_id': companyId,
      'name': 'Shirt',
      'purchase_price': 0.0,
      'current_stock': 0.0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 3. Create BOM (1 Shirt = 2m Cloth + 6 Buttons + 1 Zipper)
    final bomId = await db.insertBomWithItems(
      bom: {
        'company_id': companyId,
        'finished_product_id': fgId,
        'name': 'Standard Shirt BOM',
        'output_quantity': 1.0,
        'created_at': DateTime.now().toIso8601String(),
      },
      items: [
        {'raw_material_product_id': rm1Id, 'quantity_required': 2.0, 'unit': 'Meter'},
        {'raw_material_product_id': rm2Id, 'quantity_required': 6.0, 'unit': 'Piece'},
        {'raw_material_product_id': rm3Id, 'quantity_required': 1.0, 'unit': 'Piece'},
      ],
    );

    expect(await db.getBoms(companyId), hasLength(1));
    expect(await db.getBomItems(bomId), hasLength(3));

    // 4. Create Production Order to produce 10 Shirts
    // Material cost per shirt = (2*100) + (6*5) + (1*20) = 200 + 30 + 20 = 250
    // Total Material Cost for 10 shirts = 2500
    final poId = await db.insertProductionOrder({
      'company_id': companyId,
      'bom_id': bomId,
      'quantity_to_produce': 10.0,
      'status': 'planned',
      'labor_cost': 500.0, // 50 per shirt
      'overhead_cost': 200.0, // 20 per shirt
      'total_raw_material_cost': 2500.0,
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(await db.getProductionOrders(companyId), hasLength(1));

    // 5. Start Production
    await db.startProductionOrder(poId);

    // Verify Stock Reduction
    final rm1 = (await db.getProducts(companyId)).firstWhere((p) => p['id'] == rm1Id);
    final rm2 = (await db.getProducts(companyId)).firstWhere((p) => p['id'] == rm2Id);
    final rm3 = (await db.getProducts(companyId)).firstWhere((p) => p['id'] == rm3Id);

    expect(rm1['current_stock'], 30.0); // 50 - (2 * 10)
    expect(rm2['current_stock'], 140.0); // 200 - (6 * 10)
    expect(rm3['current_stock'], 40.0); // 50 - (1 * 10)

    // Verify Accounting Entry for Production Start
    final journals = await db.getJournalEntries(companyId);
    final startJournal = journals.firstWhere((j) => j['source_type'] == 'production_start' && j['source_id'] == poId);
    final startLines = await db.getJournalEntryLines(startJournal['id'] as int);

    final totalDebit = startLines.fold<double>(0, (sum, l) => sum + (l['debit'] as num));
    final totalCredit = startLines.fold<double>(0, (sum, l) => sum + (l['credit'] as num));

    expect(totalDebit, 2500.0);
    expect(totalCredit, 2500.0);

    // 6. Complete Production
    await db.completeProductionOrder(poId);

    // Verify Finished Product Stock and Average Cost
    // Total Production Cost = 2500 (material) + 500 (labor) + 200 (overhead) = 3200
    // Unit Cost = 3200 / 10 = 320
    final fg = (await db.getProducts(companyId)).firstWhere((p) => p['id'] == fgId);
    expect(fg['current_stock'], 10.0);
    expect(fg['purchase_price'], 320.0);

    // Verify Accounting Entry for Production Completion
    final updatedJournals = await db.getJournalEntries(companyId);
    final completeJournal = updatedJournals.firstWhere((j) => j['source_type'] == 'production_complete' && j['source_id'] == poId);
    final completeLines = await db.getJournalEntryLines(completeJournal['id'] as int);

    final completeDebit = completeLines.fold<double>(0, (sum, l) => sum + (l['debit'] as num));
    final completeCredit = completeLines.fold<double>(0, (sum, l) => sum + (l['credit'] as num));

    expect(completeDebit, 3200.0);
    expect(completeCredit, 3200.0);

    await db.deleteCompanyPermanently(companyId);
  });
}
