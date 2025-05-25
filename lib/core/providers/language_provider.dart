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
      print('Device language: $deviceLanguage');
      print('Saved language code: $savedLanguageCode');

      // Eğer kayıtlı dil yoksa veya ilk kurulum ise telefonun dilini kullan
      if (savedLanguageCode == null) {
        if (deviceLanguage == 'tr') {
          _currentLocale = const Locale('tr');
          // Bu kısımda dilleri set etmiyoruz çünkü default olarak
          // uygulama dilini kaydetmemeli
          // TODO: Ayarlardan dil değiştirildiği zaman
          // await _prefs.setString(_languageKey, languageCode); kaydedilmeli.
        } else {
          _currentLocale = const Locale('en');
        }
      } else {
        // Kayıtlı dil varsa onu kullan
        _currentLocale = Locale(savedLanguageCode);
        print('Using saved language: $savedLanguageCode');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing language: $e');
      // Hata durumunda telefonun dilini kullan
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
      print('Language provider not initialized yet');
      return;
    }

    if (_currentLocale.languageCode != languageCode) {
      print('Changing language to: $languageCode');
      _currentLocale = Locale(languageCode);
      await _prefs.setString(_languageKey, languageCode);
      notifyListeners();
    }
  }
}
