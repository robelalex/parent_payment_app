// lib/services/language_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

/// Holds the current app language and exposes t(key) for lookups.
/// Persists the choice via SharedPreferences (already a dependency) so it
/// survives app restarts, mirroring the web app's localStorage approach.
class LanguageService extends ChangeNotifier {
  static const supportedLanguages = [
    {'code': 'en', 'label': 'English', 'short': 'EN'},
    {'code': 'am', 'label': 'አማርኛ', 'short': 'አማ'},
    {'code': 'om', 'label': 'Afaan Oromoo', 'short': 'OM'},
  ];

  String _languageCode = 'en';
  String get languageCode => _languageCode;

  LanguageService() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');
    if (saved != null && appStrings.containsKey(saved)) {
      _languageCode = saved;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    if (!appStrings.containsKey(code)) return;
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }

  /// Looks up [key] in the current language, falling back to English,
  /// then to the raw key — so a missing translation never crashes the UI.
  String t(String key) {
    return appStrings[_languageCode]?[key] ??
        appStrings['en']?[key] ??
        key;
  }
}
