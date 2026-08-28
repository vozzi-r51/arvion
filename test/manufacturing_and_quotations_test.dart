import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/auth/rbac_service.dart';
import 'package:bizmanager/core/services/fbr_invoicing_service.dart';
import 'package:bizmanager/core/services/mobile_wallet_payment_service.dart';

void main() {
  group('Granular RBAC Permissions Tests', () {
    test('Default Owner Role should have all permissions', () {
      final ownerPerms = DefaultRoles.getPermissionsForRole(DefaultRoles.owner);
      expect(ownerPerms.contains(AppPermissions.canViewReports), isTrue);
      expect(ownerPerms.contains(AppPermissions.canEditPrices), isTrue);
      expect(ownerPerms.contains(AppPermissions.canDeleteRecords), isTrue);
      expect(ownerPerms.contains(AppPermissions.canManageFinance), isTrue);
    });

    test('Default Cashier Role should have limited permissions', () {
      final cashierPerms =
          DefaultRoles.getPermissionsForRole(DefaultRoles.cashier);
      expect(cashierPerms.contains(AppPermissions.canViewReports), isFalse);
      expect(cashierPerms.contains(AppPermissions.canDeleteRecords), isFalse);
      expect(cashierPerms.contains(AppPermissions.canManageFinance), isFalse);
    });
  });

  group('FBR Digital POS Invoicing Tests', () {
    test('generateFbrInvoiceNumber creates valid 18-digit ID', () {
      final fbrInvoiceNum =
          FbrInvoicingService.generateFbrInvoiceNumber(posId: '100001');
      expect(fbrInvoiceNum.length, equals(18));
      expect(
          FbrInvoicingService.isValidFbrInvoiceNumber(fbrInvoiceNum), isTrue);
    });

    test('buildFbrQrPayload builds correct pipe-delimited payload', () {
      final payload = FbrInvoicingService.buildFbrQrPayload(
        fbrInvoiceNumber: '100001202608271234',
        usin: 'USIN-991',
        posId: '100001',
        totalAmount: 1250.0,
        salesTaxAmount: 212.5,
      );

      expect(payload.contains('100001202608271234'), isTrue);
      expect(payload.contains('USIN-991'), isTrue);
      expect(payload.contains('1250.00'), isTrue);
    });
  });

  group('Pakistan Mobile Wallet Payment Service Tests', () {
    test('generateRaastDeepLink creates valid Raast URI', () {
      final link = MobileWalletPaymentService.generateRaastDeepLink(
        ibanOrMobile: '03001234567',
        amount: 5000.0,
        referenceInvoice: 'INV-2026-001',
      );

      expect(link.startsWith('raast://pay?destination=03001234567'), isTrue);
      expect(link.contains('amount=5000.00'), isTrue);
    });
  });
}
