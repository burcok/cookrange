import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLocale = languageProvider.currentLocale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('English'),
          trailing: currentLocale.languageCode == 'en'
              ? const Icon(Icons.check, color: Colors.green)
              : null,
          onTap: () => languageProvider.setLanguage('en'),
        ),
        ListTile(
          title: const Text('Türkçe'),
          trailing: currentLocale.languageCode == 'tr'
              ? const Icon(Icons.check, color: Colors.green)
              : null,
          onTap: () => languageProvider.setLanguage('tr'),
        ),
      ],
    );
  }
}
