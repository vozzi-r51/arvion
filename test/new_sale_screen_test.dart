import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bizmanager/features/sales/new_sale_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('NewSaleScreen builds without layout exceptions', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: NewSaleScreen(companyId: 1)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
