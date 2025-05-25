import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('tr'), // Turkish
  ];

  Future<bool> load() async {
    try {
      // Debug için mevcut locale bilgisini yazdır
      print('Current locale: ${locale.languageCode}');

      // Dil dosyası yolunu oluştur
      final String languageCode = locale.languageCode == 'tr' ? 'tr' : 'en';
      final String jsonPath =
          'lib/core/localization/translations/$languageCode.json';
      print('Loading translations from: $jsonPath');

      // Dosyayı yükle
      String jsonString = await rootBundle.loadString(jsonPath);
      print('Successfully loaded $languageCode translations');

      _localizedStrings = json.decode(jsonString);
      return true;
    } catch (e, stack) {
      print('Error loading translations: $e');
      print('Stack trace: $stack');
      print('Falling back to empty translations');
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key) {
    try {
      final keys = key.split('.');
      dynamic value = _localizedStrings;

      for (var k in keys) {
        if (value is Map && value.containsKey(k)) {
          value = value[k];
        } else {
          print(
              'Translation not found for key: $key in ${locale.languageCode}');
          return key;
        }
      }

      if (value is String) {
        return value;
      } else if (value is List) {
        return value.join(',');
      } else {
        print(
            'Translation value is not a string or array for key: $key in ${locale.languageCode}');
        return key;
      }
    } catch (e) {
      print('Error translating key $key in ${locale.languageCode}: $e');
      return key;
    }
  }

  List<String> translateArray(String key) {
    try {
      final keys = key.split('.');
      dynamic value = _localizedStrings;

      for (var k in keys) {
        if (value is Map && value.containsKey(k)) {
          value = value[k];
        } else {
          print('Translation not found for key: $key');
          return [];
        }
      }

      if (value is List) {
        return value.map((e) => e.toString()).toList();
      } else {
        print('Translation value is not an array for key: $key');
        return [];
      }
    } catch (e) {
      print('Error translating array key $key: $e');
      return [];
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    print('Checking if locale is supported: ${locale.languageCode}');
    return ['en', 'tr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    print('Loading delegate for locale: ${locale.languageCode}');
    AppLocalizations localizations = AppLocalizations(locale);
    final success = await localizations.load();
    if (!success) {
      print(
          'Failed to load translations for ${locale.languageCode}, falling back to English');
      // Fallback to English if loading fails
      localizations = AppLocalizations(const Locale('en'));
      await localizations.load();
    }
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
