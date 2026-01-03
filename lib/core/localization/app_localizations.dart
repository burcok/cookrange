import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static AppLocalizations of(BuildContext context) {
    final instance = maybeOf(context);
    assert(instance != null,
        'No AppLocalizations found in context. Ensure AppLocalizations.delegate is added to localizationsDelegates.');
    return instance!;
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
      debugPrint('Current locale: ${locale.languageCode}');

      // Dil dosyası yolunu oluştur
      final String languageCode = locale.languageCode == 'tr' ? 'tr' : 'en';
      final String jsonPath =
          'lib/core/localization/translations/$languageCode.json';
      debugPrint('Loading translations from: $jsonPath');

      // Dosyayı yükle
      String jsonString = await rootBundle.loadString(jsonPath);
      debugPrint('Successfully loaded $languageCode translations');

      _localizedStrings = json.decode(jsonString);
      return true;
    } catch (e, stack) {
      debugPrint('Error loading translations: $e');
      debugPrint('Stack trace: $stack');
      debugPrint('Falling back to empty translations');
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key, {Map<String, String>? variables}) {
    try {
      final keys = key.split('.');
      dynamic value = _localizedStrings;

      for (var k in keys) {
        if (value is Map && value.containsKey(k)) {
          value = value[k];
        } else {
          debugPrint(
              'Translation not found for key: $key in ${locale.languageCode}');
          return key;
        }
      }

      if (value is String) {
        String result = value;
        if (variables != null) {
          variables.forEach((key, replacement) {
            result = result.replaceAll('{$key}', replacement);
          });
        }
        return result;
      } else if (value is List) {
        return value.join(',');
      } else {
        debugPrint(
            'Translation value is not a string or array for key: $key in ${locale.languageCode}');
        return key;
      }
    } catch (e) {
      debugPrint('Error translating key $key in ${locale.languageCode}: $e');
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
          debugPrint('Translation not found for key: $key');
          return [];
        }
      }

      if (value is List) {
        return value.map((e) => e.toString()).toList();
      } else {
        debugPrint('Translation value is not an array for key: $key');
        return [];
      }
    } catch (e) {
      debugPrint('Error translating array key $key: $e');
      return [];
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    debugPrint('Checking if locale is supported: ${locale.languageCode}');
    return ['en', 'tr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    debugPrint('Loading delegate for locale: ${locale.languageCode}');
    AppLocalizations localizations = AppLocalizations(locale);
    final success = await localizations.load();
    if (!success) {
      debugPrint(
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
