// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';

import 'package:bizmanager/app.dart';
import 'package:bizmanager/core/theme/app_theme.dart';

import 'package:bizmanager/core/providers/branding_provider.dart';
import 'package:bizmanager/core/providers/localization_provider.dart';
import 'package:bizmanager/core/providers/terminology_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('DukanEdge app builds without crashing',
      (WidgetTester tester) async {
    // Phase 58: app.dart now watches LocalizationProvider for reactive
    // locale changes, so the widget test must provide it in scope.
    // init() is async and reads SharedPreferences / DB; we let it run
    // best-effort and don't await — MaterialApp.locale starts as en
    // and the provider updates the UI later via notifyListeners().
    final localizationProvider = LocalizationProvider();
    unawaited(localizationProvider.init());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TerminologyProvider()),
          ChangeNotifierProvider(create: (_) => BrandingProvider()),
          ChangeNotifierProvider<LocalizationProvider>.value(
              value: localizationProvider),
        ],
        child: const BizManagerApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5100));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
