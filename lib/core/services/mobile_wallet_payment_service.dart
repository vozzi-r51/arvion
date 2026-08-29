import '../utils/currency_formatter.dart';

/// Pakistan Mobile Wallet Payment Integration (JazzCash, EasyPaisa, Raast, NayaPay, SadaPay).
class MobileWalletPaymentService {
  MobileWalletPaymentService._();

  static const List<String> supportedWallets = [
    'Cash',
    'Bank Transfer',
    'JazzCash',
    'EasyPaisa',
    'Raast',
    'NayaPay',
    'SadaPay',
    'Cheque',
  ];

  /// Generates a Raast Person-to-Person / Merchant Payment Link for Pakistan Raast Instant Payments.
  /// Format: raast://pay?iban=PK...&amount=1250&ref=INV-1001
  static String generateRaastDeepLink({
    required String ibanOrMobile,
    required double amount,
    required String referenceInvoice,
  }) {
    final cleanRef = Uri.encodeComponent(referenceInvoice);
    return 'raast://pay?destination=$ibanOrMobile&amount=${amount.toStringAsFixed(2)}&ref=$cleanRef';
  }

  /// Generates JazzCash Till Code / Mobile Wallet Payment Instructions for Customers.
  static String getJazzCashInstructions({
    required String tillCodeOrMobile,
    required double amount,
    required String invoiceNo,
    Map<String, dynamic>? company,
  }) {
    return 'JazzCash Mobile Account: *786# dial karein -> Pay Till / Merchant -> Code: $tillCodeOrMobile -> Amount: ${CurrencyFormatter.formatFromCompany(amount, company, decimalPlaces: 0)} -> Ref: $invoiceNo';
  }

  /// Generates EasyPaisa Merchant Payment Instructions.
  static String getEasyPaisaInstructions({
    required String tillNumber,
    required double amount,
    required String invoiceNo,
    Map<String, dynamic>? company,
  }) {
    return 'EasyPaisa App kholain -> QR / Merchant Pay -> Till ID: $tillNumber -> Amount: ${CurrencyFormatter.formatFromCompany(amount, company, decimalPlaces: 0)} -> Ref: $invoiceNo';
  }
}
