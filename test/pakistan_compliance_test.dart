import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/services/fbr_invoicing_service.dart';
import 'package:bizmanager/core/services/mobile_wallet_payment_service.dart';

void main() {
  group('1. FBR Digital Invoicing & Fiscal QR Tests', () {
    test('Generates syntactically valid 18-digit FBR Fiscal Invoice Number', () {
      final fbrInvoiceNum = FbrInvoicingService.generateFbrInvoiceNumber(posId: '700001');
      expect(fbrInvoiceNum.length, equals(18));
      expect(FbrInvoicingService.isValidFbrInvoiceNumber(fbrInvoiceNum), isTrue);
    });

    test('Constructs official FBR QR Code Payload string', () {
      final payload = FbrInvoicingService.buildFbrQrPayload(
        fbrInvoiceNumber: '700001202608281042',
        usin: 'INV-10042',
        posId: '700001',
        totalAmount: 12500.0,
        salesTaxAmount: 1875.0,
        pntn: '7000000-0',
      );

      expect(payload, contains('700001202608281042|INV-10042|700001'));
      expect(payload, contains('12500.00|1875.00|7000000-0'));
    });
  });

  group('2. Mobile Wallet Payments & Raast Deep-Link Tests', () {
    test('Generates Raast Instant Payment deep-link URI', () {
      final raastUri = MobileWalletPaymentService.generateRaastDeepLink(
        ibanOrMobile: '03001234567',
        amount: 1250.0,
        referenceInvoice: 'INV-1001',
      );

      expect(raastUri, contains('raast://pay?destination=03001234567'));
      expect(raastUri, contains('amount=1250.00'));
      expect(raastUri, contains('ref=INV-1001'));
    });

    test('Generates JazzCash and EasyPaisa customer payment instructions', () {
      final jazzCash = MobileWalletPaymentService.getJazzCashInstructions(
        tillCodeOrMobile: '123456',
        amount: 2500.0,
        invoiceNo: 'INV-2002',
      );

      final easyPaisa = MobileWalletPaymentService.getEasyPaisaInstructions(
        tillNumber: '789012',
        amount: 2500.0,
        invoiceNo: 'INV-2002',
      );

      expect(jazzCash, contains('*786#'));
      expect(jazzCash, contains('123456'));
      expect(easyPaisa, contains('789012'));
    });
  });
}
