import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;

class SMSService {
  SMSService._();

  static Future<bool> sendSMS({
    required String mobile,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool('sms_enabled') ?? false;
    if (!enabled) return false;

    final String? gatewayUrl = prefs.getString('sms_gateway_url');
    final String? apiKey = prefs.getString('sms_api_key');

    if (gatewayUrl == null ||
        gatewayUrl.isEmpty ||
        apiKey == null ||
        apiKey.isEmpty) {
      return false;
    }

    try {
      // Standard generic implementation: many gateways use a simple GET or POST
      // with mobile and message as query params.
      // User can customize the URL in settings, e.g.,
      // https://api.gateway.com/send?key={key}&to={mobile}&msg={message}

      String finalUrl = gatewayUrl
          .replaceAll('{key}', apiKey)
          .replaceAll('{mobile}', mobile)
          .replaceAll('{message}', Uri.encodeComponent(message));

      final response = await http
          .get(Uri.parse(finalUrl))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      dev.log('SMS Error: $e');
      return false;
    }
  }
}
