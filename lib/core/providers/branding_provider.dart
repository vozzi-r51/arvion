import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class BrandingProvider extends ChangeNotifier {
  String _companyName = 'BizManager';
  String? _logoPath;
  Color _primaryColor = const Color(0xFF2563EB);

  String get companyName => _companyName;
  String? get logoPath => _logoPath;
  Color get primaryColor => _primaryColor;

  Future<void> loadBranding() async {
    final company = await DBHelper.instance.getActiveCompany();
    if (company != null) {
      _companyName = company['name'] as String? ?? 'BizManager';
      _logoPath = company['logo_path'] as String?;
      if (company['branding_color'] != null) {
        _primaryColor = Color(company['branding_color'] as int);
      }
    } else {
      _companyName = 'BizManager';
      _logoPath = null;
      _primaryColor = const Color(0xFF2563EB);
    }
    notifyListeners();
  }
}
