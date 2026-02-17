// lib/providers/language_provider.dart
import 'package:flutter/material.dart';
import '../services/language_service.dart';

class LanguageProvider extends ChangeNotifier {
  final LanguageService _languageService = LanguageService();

  Locale get currentLocale => _languageService.currentLocale;
  
  List<Map<String, dynamic>> get supportedLanguages => 
      LanguageService.supportedLanguages;

  Future<void> init() async {
    await _languageService.init();
    _languageService.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    await _languageService.setLanguage(languageCode);
  }

  String getLanguageName(String code) {
    return _languageService.getLanguageName(code);
  }

  String getCurrentLanguageCode() {
    return _languageService.getCurrentLanguageCode();
  }

  String getCurrentLanguageName() {
    return _languageService.getCurrentLanguageName();
  }

  @override
  void dispose() {
    _languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }
}
