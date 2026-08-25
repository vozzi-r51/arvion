import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeechAvailable = false;
  String _currentLocaleId = "en_US";
  String? _urduLocaleId;

  Future<void> init() async {
    _isSpeechAvailable = await _speech.initialize();
    
    if (_isSpeechAvailable) {
      final locales = await _speech.locales();
      for (var l in locales) {
        if (l.localeId.toLowerCase().contains("ur")) {
          _urduLocaleId = l.localeId;
          break;
        }
      }
      // Default to Urdu if available, otherwise English
      _currentLocaleId = _urduLocaleId ?? "en_US";
    }

    await _updateTtsLanguage();
    await _tts.setPitch(1.0);
  }

  Future<void> _updateTtsLanguage() async {
    if (_currentLocaleId.toLowerCase().contains("ur")) {
      dynamic isUrduAvailable = await _tts.isLanguageAvailable("ur-PK");
      if (isUrduAvailable != null && isUrduAvailable != false) {
        await _tts.setLanguage("ur-PK");
      } else {
        await _tts.setLanguage("en-US");
      }
    } else {
      await _tts.setLanguage("en-US");
    }
  }

  void setLocale(bool isUrdu) {
    if (isUrdu && _urduLocaleId != null) {
      _currentLocaleId = _urduLocaleId!;
    } else {
      _currentLocaleId = "en_US";
    }
    _updateTtsLanguage();
  }

  bool get isUrduMode => _currentLocaleId.toLowerCase().contains("ur");
  bool get canUrdu => _urduLocaleId != null;

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> listen({required Function(String) onResult}) async {
    if (!_isSpeechAvailable) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: _currentLocaleId,
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
