import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as dev;

/// Built-in SMS provider preset. Users pick one instead of hand-typing
/// a gateway URL + API key template. The {key}, {mobile}, {message}
/// placeholders in [urlTemplate] are substituted at send time.
class SmsProvider {
  final String id;
  final String label;
  final String urlTemplate; // must contain {mobile} and {message}
  final String description;
  const SmsProvider({
    required this.id,
    required this.label,
    required this.urlTemplate,
    required this.description,
  });
}

class SmsProviders {
  SmsProviders._();

  /// Curated list of commonly-used bulk-SMS providers worldwide. The
  /// user can still fall back to "Custom" and hand-write the URL.
  static const List<SmsProvider> presets = [
    SmsProvider(
      id: 'textlocal',
      label: 'TextLocal (India / UK)',
      urlTemplate:
          'https://api.textlocal.in/send/?apikey={key}&numbers={mobile}&message={message}&sender=BIZMGR',
      description: 'Popular in IN/UK. Free trial available.',
    ),
    SmsProvider(
      id: 'msg91',
      label: 'MSG91 (India)',
      urlTemplate:
          'https://control.msg91.com/api/v5/flow/?apikey={key}&mobiles={mobile}&message={message}',
      description: 'India-focused, supports DLT templates.',
    ),
    SmsProvider(
      id: 'twilio',
      label: 'Twilio (Global)',
      urlTemplate:
          'https://api.twilio.com/2010-04-01/Accounts/{key}/Messages.json',
      description: 'Global, paid. TwiML-driven (POST body required).',
    ),
    SmsProvider(
      id: 'bulksms',
      label: 'BulkSMS (Global)',
      urlTemplate:
          'https://api.bulksms.com/v1/messages?username={key}&to={mobile}&body={message}',
      description: 'Global, coverage in 200+ countries.',
    ),
    SmsProvider(
      id: 'telenor_pak',
      label: 'Telenor SMS (Pakistan)',
      urlTemplate:
          'https://telenorcsms.com.pk:27677/corporate_sms2/api/sendsms.jsp?user={key}&mobile={mobile}&message={message}&type=XML',
      description: 'Pakistani Telenor subscribers.',
    ),
    SmsProvider(
      id: 'jazz_sms',
      label: 'Jazz SMS (Pakistan)',
      urlTemplate:
          'https://services.jazz.com.pk/SendSMS?username={key}&to={mobile}&message={message}',
      description: 'Pakistani Jazz subscribers.',
    ),
    SmsProvider(
      id: 'infobip',
      label: 'Infobip (Global)',
      urlTemplate:
          'https://api.infobip.com/sms/1/text/single?to={mobile}&text={message}',
      description: 'Global, enterprise-grade.',
    ),
    SmsProvider(
      id: 'custom',
      label: 'Custom (URL + API Key)',
      urlTemplate:
          'https://api.example.com/send?key={key}&to={mobile}&msg={message}',
      description: 'Aap khud URL aur API key likhein.',
    ),
  ];

  static SmsProvider byId(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.last);
}

class SMSService {
  SMSService._();

  static Future<bool> sendSMS({
    required String mobile,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool('sms_enabled') ?? false;
    if (!enabled) return false;

    // Resolve the active gateway URL: either from a built-in provider
    // preset (provider_id + api_key) or from a fully custom URL.
    final String? providerId = prefs.getString('sms_provider_id');
    final String? gatewayUrl = prefs.getString('sms_gateway_url');
    final String? apiKey = prefs.getString('sms_api_key');

    String urlTemplate;
    if (providerId != null && providerId.isNotEmpty && providerId != 'custom') {
      urlTemplate = SmsProviders.byId(providerId).urlTemplate;
    } else if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
      urlTemplate = gatewayUrl;
    } else {
      return false;
    }

    if (apiKey == null || apiKey.isEmpty) return false;

    try {
      String finalUrl = urlTemplate
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

  /// Launch native SMS app on device (free, uses SIM card, no API gateway needed)
  static Future<bool> sendDeviceSMS({
    required String mobile,
    required String message,
  }) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(
      scheme: 'sms',
      path: cleanMobile,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
