import 'package:flutter/material.dart';
import '../templates/business_templates.dart';

class TerminologyProvider extends ChangeNotifier {
  BusinessTemplate _currentTemplate = BusinessTemplates.all.first;

  BusinessTemplate get template => _currentTemplate;

  void updateTemplate(String templateId) {
    _currentTemplate = BusinessTemplates.getById(templateId);
    notifyListeners();
  }

  String get(String key) {
    return _currentTemplate.terminology[key] ?? key;
  }
}
