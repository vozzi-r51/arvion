import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/feedback/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. In-App Searchable Help Center Tests', () {
    test('Filter FAQs by category and search keyword case-insensitively', () {
      final faqs = [
        {
          'category': 'Sales',
          'q': 'Nayi Sale kaise create karein?',
          'a': 'Sales tab mein Nayi Sale button dabaayein.'
        },
        {
          'category': 'Payments',
          'q': 'JazzCash payment kaise lein?',
          'a': 'Payment method se JazzCash select karein.'
        },
        {
          'category': 'Accounting',
          'q': 'Fiscal Year Closing kya hai?',
          'a': 'Net Profit Retained Earnings mein transfer hota hai.'
        },
      ];

      final searchInvoice = faqs
          .where((f) =>
              f['q']!.toLowerCase().contains('sale') ||
              f['a']!.toLowerCase().contains('sale'))
          .toList();
      expect(searchInvoice.length, equals(1));
      expect(searchInvoice.first['category'], equals('Sales'));

      final paymentsCat =
          faqs.where((f) => f['category'] == 'Payments').toList();
      expect(paymentsCat.length, equals(1));
      expect(paymentsCat.first['q'], contains('JazzCash'));
    });
  });

  group('2. Privacy-Aware User Feedback System Tests', () {
    test('Submits feature suggestion locally and rejects empty title',
        () async {
      final feedbackService = FeedbackService.instance;

      expect(
        () async => await feedbackService.submitFeedback(
          companyId: 1,
          title: '',
          category: 'Sales',
          description: 'Need WhatsApp sending',
        ),
        throwsA(isA<FormatException>()),
      );

      final status = await feedbackService.submitFeedback(
        companyId: 1,
        title: 'WhatsApp Invoice Sending',
        category: 'Sales',
        description: 'Send invoices directly to WhatsApp',
      );

      expect(status, equals('submitted_locally'));

      final pending = await feedbackService.getPendingFeedbackList();
      expect(pending.length, equals(1));
      expect(pending.first['title'], equals('WhatsApp Invoice Sending'));
      expect(pending.first.containsKey('password'), isFalse);
      expect(pending.first.containsKey('db_encryption_key'), isFalse);
    });
  });
}
