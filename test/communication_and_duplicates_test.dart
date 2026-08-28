import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bizmanager/core/utils/phone_formatter.dart';
import 'package:bizmanager/core/services/duplicate_detection_service.dart';
import 'package:bizmanager/core/notifications/sms_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'db_encryption_key': 'MDAwMDAwMDAw00000000MDAwMDAwMDAwMDAwMDA=',
    });
  });

  group('1. Phone Normalization & WhatsApp Deep-Link Tests', () {
    test('Normalizes various Pakistan phone formats into clean WhatsApp international digits', () {
      expect(PhoneFormatter.toWhatsAppNumber('+92 300 1234567'), equals('923001234567'));
      expect(PhoneFormatter.toWhatsAppNumber('0300-1234567'), equals('923001234567'));
      expect(PhoneFormatter.toWhatsAppNumber('+92 (300) 123-4567'), equals('923001234567'));
      expect(PhoneFormatter.toWhatsAppNumber('92 300 1234567'), equals('923001234567'));
    });

    test('Constructs wa.me URL with properly URL-encoded spaces and Urdu text', () {
      final uri = PhoneFormatter.buildWhatsAppUri('+92 300 1234567', 'Assalam o Alaikum, Rs. 5,000 pending!');
      final urlStr = uri.toString();

      expect(urlStr, contains('https://wa.me/923001234567'));
      expect(urlStr, contains('text=Assalam'));
      expect(urlStr, contains('%20')); // Encoded space
    });
  });

  group('2. Same-Company Duplicate Customer & Supplier Detection Tests', () {
    test('Normalizes customer names and phone numbers for case-insensitive duplicate matching', () {
      final name1 = DuplicateDetectionService.normalizeName('  Ali Traders  ');
      final name2 = DuplicateDetectionService.normalizeName('ali traders');

      expect(name1, equals('ali traders'));
      expect(name2, equals('ali traders'));
      expect(name1, equals(name2));

      final phone1 = PhoneFormatter.toWhatsAppNumber('0300-1234567');
      final phone2 = PhoneFormatter.toWhatsAppNumber('+92 300 1234567');

      expect(phone1, equals('923001234567'));
      expect(phone2, equals('923001234567'));
      expect(phone1, equals(phone2));
    });
  });

  group('3. Optional SMS Module Isolation & Offline Safety Tests', () {
    test('SMS module default state is OFF and fails gracefully without throwing errors when internet is unavailable', () async {
      SharedPreferences.setMockInitialValues({'sms_enabled': false});

      final resultDisabled = await SMSService.sendSMS(
        mobile: '923001234567',
        message: 'Payment received',
      );
      expect(resultDisabled, isFalse);

      // Enable SMS with mock unconfigured gateway
      SharedPreferences.setMockInitialValues({
        'sms_enabled': true,
        'sms_gateway_url': 'https://unreachable.gateway.com/api?key={key}&to={mobile}&msg={message}',
        'sms_api_key': 'mock_key_123',
      });

      final resultFailed = await SMSService.sendSMS(
        mobile: '923001234567',
        message: 'Payment received',
      );

      // Gracefully returns false without throwing unhandled exceptions
      expect(resultFailed, isFalse);
    });
  });
}
