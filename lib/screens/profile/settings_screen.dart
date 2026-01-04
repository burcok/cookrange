import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFFDFDFD),
      appBar: AppBar(
        title: Text(
          "Preferences", // Should be localized potentially
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Appearance", isDark),
          _buildTile(
            title: "Theme",
            subtitle: _getThemeName(themeProvider.themeMode),
            icon: Icons.brightness_6,
            isDark: isDark,
            trailing: DropdownButton<ThemeMode>(
              value: themeProvider.themeMode,
              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text("System")),
                DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
              ],
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Language", isDark),
          _buildTile(
            title: "App Language",
            subtitle: languageProvider.currentLocale.languageCode == 'tr'
                ? 'Türkçe'
                : 'English',
            icon: Icons.language,
            isDark: isDark,
            trailing: DropdownButton<Locale>(
              value: languageProvider.currentLocale,
              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text("English")),
                DropdownMenuItem(value: Locale('tr'), child: Text("Türkçe")),
              ],
              onChanged: (val) {
                if (val != null) languageProvider.setLanguage(val.languageCode);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "System Default";
      case ThemeMode.light:
        return "Light Mode";
      case ThemeMode.dark:
        return "Dark Mode";
    }
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFF44075), size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}
