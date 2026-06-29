import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  late SharedPreferences _prefs;
  Locale _currentLocale = const Locale('en');
  bool _isInitialized = false;

  LanguageProvider() {
    _initializeLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _initializeLanguage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final String? savedLanguageCode = _prefs.getString(_languageKey);
      final String deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      debugPrint('Device language: $deviceLanguage');
      debugPrint('Saved language code: $savedLanguageCode');

      if (savedLanguageCode == null) {
        _currentLocale =
            deviceLanguage == 'tr' ? const Locale('tr') : const Locale('en');
      } else {
        _currentLocale = Locale(savedLanguageCode);
        debugPrint('Using saved language: $savedLanguageCode');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing language: $e');
      final String deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _currentLocale =
          deviceLanguage == 'tr' ? const Locale('tr') : const Locale('en');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) {
      debugPrint('Language provider not initialized yet');
      return;
    }

    if (_currentLocale.languageCode != languageCode) {
      debugPrint('Changing language to: $languageCode');
      _currentLocale = Locale(languageCode);
      await _prefs.setString(_languageKey, languageCode);
      notifyListeners();
    }
  }
}
