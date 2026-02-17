// lib/services/language_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LanguageService extends ChangeNotifier {
  LanguageService._internal();
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;

  static const String _languageKey = 'app_language';
  final AuthService _auth = AuthService();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  // Supported languages
  static const List<Map<String, dynamic>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'locale': Locale('en')},
    {'code': 'hi', 'name': 'हिंदी (Hindi)', 'locale': Locale('hi')},
    {'code': 'es', 'name': 'Español (Spanish)', 'locale': Locale('es')},
    {'code': 'fr', 'name': 'Français (French)', 'locale': Locale('fr')},
    {'code': 'de', 'name': 'Deutsch (German)', 'locale': Locale('de')},
  ];

  Future<void> init() async {
    // Load saved language preference
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    
    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage);
      notifyListeners();
    } else {
      // Try to load from backend if user is logged in (with timeout)
      if (_auth.isLoggedIn) {
        try {
          final settings = await _auth.getSettings().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw Exception('Settings request timeout');
            },
          );
          final backendLanguage = settings['language'] as String?;
          if (backendLanguage != null && backendLanguage.isNotEmpty) {
            await setLanguage(backendLanguage, saveToBackend: false);
          } else {
            _currentLocale = const Locale('en');
          }
        } catch (e) {
          // If error, use default
          _currentLocale = const Locale('en');
        }
      } else {
        // Not logged in, use default
        _currentLocale = const Locale('en');
      }
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode, {bool saveToBackend = true}) async {
    // Validate language code
    final validLanguage = supportedLanguages.firstWhere(
      (lang) => lang['code'] == languageCode.toLowerCase(),
      orElse: () => supportedLanguages[0], // Default to English
    );

    _currentLocale = validLanguage['locale'] as Locale;
    
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode.toLowerCase());
    
    // Save to backend if user is logged in
    if (saveToBackend) {
      try {
        await _auth.updateSettings(language: languageCode.toLowerCase());
      } catch (e) {
        // If backend update fails, language is still changed locally
        print('Failed to save language to backend: $e');
      }
    }
    
    notifyListeners();
  }

  String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == code.toLowerCase(),
      orElse: () => supportedLanguages[0],
    );
    return lang['name'] as String;
  }

  String getCurrentLanguageCode() {
    return _currentLocale.languageCode;
  }

  String getCurrentLanguageName() {
    return getLanguageName(_currentLocale.languageCode);
  }
}
