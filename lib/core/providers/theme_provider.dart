import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart' as c;

import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  Color _primaryColor = c.primaryColor;

  ThemeProvider() {
    _loadTheme();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final userData = await FirestoreService().getUserData(user.uid);
        if (userData != null && userData.primaryColor != null) {
          _primaryColor = Color(userData.primaryColor!);
          notifyListeners();

          // Also sync with local storage so it's available next time immediately
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('primary_color', _primaryColor.value);
        }
      }
    });
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      if (themeString == 'light')
        _themeMode = ThemeMode.light;
      else if (themeString == 'dark')
        _themeMode = ThemeMode.dark;
      else
        _themeMode = ThemeMode.system;
    }

    final colorInt = prefs.getInt('primary_color');
    if (colorInt != null) {
      _primaryColor = Color(colorInt);
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('theme_mode', modeStr);
  }

  Color get primaryColor => _primaryColor;

  void setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color', color.value);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirestoreService()
          .updateUserData(user.uid, {'primary_color': color.value});
    }
  }
}
