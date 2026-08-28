/// Centralized Phone Number Normalization & WhatsApp Deep-Link Generator.
class PhoneFormatter {
  PhoneFormatter._();

  /// Normalizes input phone string into clean international digits without leading '+' or special chars.
  /// Converts Pakistan local numbers (03xx-xxxxxxx) into international 923xxxxxxxx.
  static String toWhatsAppNumber(String phone) {
    if (phone.isEmpty) return '';

    // Remove all non-numeric characters
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '').trim();

    if (clean.isEmpty) return '';

    // Handle Pakistan local 03xx format -> 923xx
    if (clean.startsWith('03') && clean.length == 11) {
      clean = '92${clean.substring(1)}';
    }

    return clean;
  }

  /// Constructs Uri for WhatsApp wa.me deep-link with URL-encoded message.
  static Uri buildWhatsAppUri(String phone, String message) {
    final cleanPhone = toWhatsAppNumber(phone);
    final encodedMessage = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
  }
}
