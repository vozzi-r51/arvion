import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/services/ux_mode_service.dart';

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
      'progressive disclosure: simple mode default, manual toggle & auto-detect for existing advanced users',
      () async {
    final db = DBHelper.instance;

    final companyId = await db.insertCompany({
      'name': 'Progressive UX Test Company',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 1. Default for new company is Simple
    var mode = await UXModeService.getEffectiveMode(companyId);
    expect(mode, UXMode.simple);

    // 2. Manual toggle to Advanced
    await UXModeService.setMode(companyId, UXMode.advanced);
    mode = await UXModeService.getEffectiveMode(companyId);
    expect(mode, UXMode.advanced);

    // Reset back to Simple
    await UXModeService.setMode(companyId, UXMode.simple);

    // 3. Auto-detect advanced usage: Add a product with variants
    await db.insertProduct({
      'company_id': companyId,
      'name': 'Shirt with Variants',
      'purchase_price': 50.0,
      'retail_price': 100.0,
      'current_stock': 10.0,
      'has_variants': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Clear explicit preference to trigger auto-detection
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_ui_mode_$companyId');

    mode = await UXModeService.getEffectiveMode(companyId);
    expect(mode, UXMode.advanced);

    await db.deleteCompanyPermanently(companyId);
  });
}
