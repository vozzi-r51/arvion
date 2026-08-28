import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:bizmanager/core/database/db_helper.dart';

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
      'industry specific features: Restaurant Tables, Service Jobs, Pharmacy Expiry',
      () async {
    final db = DBHelper.instance;
    final companyId = await db.insertCompany({
      'name': 'Industry Test Company',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 1. Restaurant Tables
    await db.insertRestaurantTable(companyId, 'Table 1');
    await db.insertRestaurantTable(companyId, 'Table 2');
    final tables = await db.getRestaurantTables(companyId);
    expect(tables, hasLength(2));
    expect(tables.first['table_number'], 'Table 1');

    await db.updateTableStatus(tables.first['id'] as int, 'occupied');
    final updatedTables = await db.getRestaurantTables(companyId);
    expect(updatedTables.first['status'], 'occupied');

    // 2. Service Jobs
    final jobId = await db.insertServiceJob({
      'company_id': companyId,
      'service_description': 'Oil Change & Tuneup',
      'amount': 2500.0,
      'status': 'pending',
      'scheduled_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    var jobs = await db.getServiceJobs(companyId);
    expect(jobs, hasLength(1));
    expect(jobs.first['status'], 'pending');

    await db.updateServiceJobStatus(jobId, 'in_progress');
    jobs = await db.getServiceJobs(companyId);
    expect(jobs.first['status'], 'in_progress');

    await db.updateServiceJobStatus(jobId, 'done');
    jobs = await db.getServiceJobs(companyId);
    expect(jobs.first['status'], 'done');

    // 3. Pharmacy Expiry Tracking Check
    final expDate =
        DateTime.now().add(const Duration(days: 15)).toIso8601String();
    final medId = await db.insertProduct({
      'company_id': companyId,
      'name': 'Panadol 500mg',
      'batch_number': 'BATCH-99',
      'expiry_date': expDate,
      'purchase_price': 10.0,
      'retail_price': 15.0,
      'current_stock': 100.0,
      'created_at': DateTime.now().toIso8601String(),
    });

    final products = await db.getProducts(companyId);
    final med = products.firstWhere((p) => p['id'] == medId);
    final parsedExp = DateTime.parse(med['expiry_date'] as String);
    expect(parsedExp.difference(DateTime.now()).inDays <= 30, isTrue);

    await db.deleteCompanyPermanently(companyId);
  });
}
