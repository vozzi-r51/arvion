import 'package:shared_preferences/shared_preferences.dart';

/// Staged Feature Rollout & Feature Flag Manager.
/// Allows enabling Beta features for select users or early adopters.
class FeatureFlagService {
  FeatureFlagService._();
  static final FeatureFlagService instance = FeatureFlagService._();

  static const String _keyBetaMode = 'flag_beta_mode';
  static const String _keyFbrInvoicing = 'flag_fbr_invoicing';
  static const String _keyEcommerceSync = 'flag_ecommerce_sync';

  bool _isBetaMode = false;
  bool _isFbrInvoicing = true;
  bool _isEcommerceSync = true;

  bool get isBetaMode => _isBetaMode;
  bool get isFbrInvoicingEnabled => _isFbrInvoicing;
  bool get isEcommerceSyncEnabled => _isEcommerceSync;

  /// Loads feature flag preferences from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isBetaMode = prefs.getBool(_keyBetaMode) ?? false;
    _isFbrInvoicing = prefs.getBool(_keyFbrInvoicing) ?? true;
    _isEcommerceSync = prefs.getBool(_keyEcommerceSync) ?? true;
  }

  /// Toggles Beta mode for staged feature testing.
  Future<void> setBetaMode(bool enabled) async {
    _isBetaMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBetaMode, enabled);
  }

  /// Toggles FBR Digital Invoicing feature flag.
  Future<void> setFbrInvoicing(bool enabled) async {
    _isFbrInvoicing = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFbrInvoicing, enabled);
  }
}
