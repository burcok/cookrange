import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  late SharedPreferences _prefs;
  Locale _currentLocale = const Locale('en');

  LanguageProvider() {
    _loadLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadLanguage() async {
    _prefs = await SharedPreferences.getInstance();
    final String? savedLanguageCode = _prefs.getString(_languageKey);

    if (savedLanguageCode != null) {
      // If there's a saved language preference, use it
      _currentLocale = Locale(savedLanguageCode);
    } else {
      // If no saved preference, check device language
      final String deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (deviceLanguage == 'tr') {
        _currentLocale = const Locale('tr');
        await _prefs.setString(_languageKey, 'tr');
      } else {
        _currentLocale = const Locale('en');
        await _prefs.setString(_languageKey, 'en');
      }
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLocale.languageCode != languageCode) {
      _currentLocale = Locale(languageCode);
      await _prefs.setString(_languageKey, languageCode);
      notifyListeners();
    }
  }
}
