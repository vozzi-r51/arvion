import 'package:flutter/material.dart';
import '../database/db_helper.dart';

/// Enum for UI experience modes
enum UiMode {
  simple,    // Basic fields only, advanced features hidden
  advanced,  // All features visible
}

/// Provider managing UI complexity mode and feature visibility
class UiModeProvider extends ChangeNotifier {
  Map<String, dynamic>? _company;
  UiMode _uiMode = UiMode.simple;

  UiMode get uiMode => _uiMode;
  bool get isSimple => _uiMode == UiMode.simple;
  bool get isAdvanced => _uiMode == UiMode.advanced;

  /// Initialize with active company
  Future<void> init() async {
    _company = await DBHelper.instance.getActiveCompany();
    _loadUiMode();
    notifyListeners();
  }

  /// Update company
  void setCompany(Map<String, dynamic> company) {
    _company = company;
    _loadUiMode();
    notifyListeners();
  }

  /// Toggle between Simple and Advanced modes
  Future<void> toggleMode() async {
    _uiMode = isSimple ? UiMode.advanced : UiMode.simple;

    // Save to database
    if (_company != null) {
      await DBHelper.instance.updateCompany(
        _company!['id'] as int,
        {'ui_mode': isSimple ? 'simple' : 'advanced'},
      );
    }
    notifyListeners();
  }

  /// Set specific mode
  Future<void> setMode(UiMode mode) async {
    _uiMode = mode;

    // Save to database
    if (_company != null) {
      await DBHelper.instance.updateCompany(
        _company!['id'] as int,
        {'ui_mode': mode == UiMode.simple ? 'simple' : 'advanced'},
      );
    }
    notifyListeners();
  }

  /// Feature visibility helpers
  bool shouldShowVariants() {
    // Always show if advanced mode
    if (isAdvanced) return true;

    // Show if template requires it (e.g., Clothing always needs variants)
    final templateFamily = _company?['template_family'] as String?;
    final requiresVariants = ['clothing', 'jewelry', 'apparel'].contains(templateFamily?.toLowerCase());
    return requiresVariants;
  }

  bool shouldShowCustomFields() {
    return isAdvanced;
  }

  bool shouldShowMultiUom() {
    return isAdvanced;
  }

  bool shouldShowMultiTax() {
    // Tax is important even in simple mode
    return true;
  }

  bool shouldShowManufacturing() {
    return isAdvanced;
  }

  bool shouldShowJournal() {
    return isAdvanced;
  }

  bool shouldShowAccounting() {
    return isAdvanced;
  }

  bool shouldShowQuotations() {
    // Quotations are useful in simple mode too
    return true;
  }

  bool shouldShowPromotions() {
    // Promotions/discounts are important in simple mode
    return true;
  }

  bool shouldShowCheque() {
    return isAdvanced;
  }

  bool shouldShowCommittee() {
    return isAdvanced;
  }

  /// Load UI mode from company data
  void _loadUiMode() {
    final modeStr = _company?['ui_mode'] as String? ?? 'simple';
    _uiMode = modeStr == 'advanced' ? UiMode.advanced : UiMode.simple;
  }

  /// Get description for mode selection
  String getModeDescription(UiMode mode) {
    switch (mode) {
      case UiMode.simple:
        return 'Recommended for most users. Shows only essential fields:\n• Product name, price, stock, category\n• Basic sales & purchase\n• Customer ledger';
      case UiMode.advanced:
        return 'For experienced users. All features visible:\n• Variants, custom fields, multi-UOM\n• Manufacturing, accounting\n• Advanced reporting';
    }
  }
}
