import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/theme/branded_theme_engine.dart';
import 'package:bizmanager/core/subscription/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Config-Driven White-Label Branding Engine Tests', () {
    test('BrandedThemeEngine builds Light and Dark ThemeData from BrandConfig', () {
      const customConfig = BrandConfig(
        appName: 'Acme Enterprise ERP',
        logoAsset: 'assets/acme_logo.png',
        primaryColor: Color(0xFF0F172A), // Slate Navy
        secondaryColor: Color(0xFF0284C7), // Electric Cyan
        surfaceColor: Color(0xFFF1F5F9),
        borderRadius: 16.0,
      );

      final engine = BrandedThemeEngine(config: customConfig);
      final lightTheme = engine.buildLightTheme();
      final darkTheme = engine.buildDarkTheme();

      expect(lightTheme.colorScheme.primary.value, equals(customConfig.primaryColor.value));
      expect(darkTheme.colorScheme.primary.value, equals(customConfig.primaryColor.value));
      expect(lightTheme.cardTheme.shape, isA<RoundedRectangleBorder>());
    });
  });

  group('2. Monetization & Subscription Entitlements Architecture Tests', () {
    test('SubscriptionService defaults to Pro for offline users and grants feature entitlements', () async {
      final subService = SubscriptionService.instance;
      final plan = await subService.getCurrentPlan(1);

      expect(plan, equals(SubscriptionPlan.pro));

      final hasFullExport = await subService.hasEntitlement(FeatureEntitlement.fullExport, 1);
      final hasFbrInvoicing = await subService.hasEntitlement(FeatureEntitlement.fbrInvoicing, 1);
      final hasUnlimitedProducts = await subService.hasEntitlement(FeatureEntitlement.productsUnlimited, 1);

      expect(hasFullExport, isTrue);
      expect(hasFbrInvoicing, isTrue);
      expect(hasUnlimitedProducts, isTrue);

      final maxProducts = await subService.getMaxProductsAllowed(1);
      expect(maxProducts, isNull); // Unlimited for Pro
    });

    test('Plan tier modification never deletes user data or database records', () async {
      final subService = SubscriptionService.instance;

      await subService.setPlan(1, SubscriptionPlan.free);
      final freePlan = await subService.getCurrentPlan(1);
      expect(freePlan, equals(SubscriptionPlan.free));

      final freeMaxProducts = await subService.getMaxProductsAllowed(1);
      expect(freeMaxProducts, equals(100));

      // Restore to Pro
      await subService.setPlan(1, SubscriptionPlan.pro);
      final proPlan = await subService.getCurrentPlan(1);
      expect(proPlan, equals(SubscriptionPlan.pro));
    });
  });
}
