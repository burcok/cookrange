import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  static const int homeTab = 0;
  static const int communityTab = 1;
  static const int profileTab = 2;

  int _currentIndex = 0;
  bool _isMenuOpen = false;
  bool _isVoiceAssistantOpen = false;

  int get currentIndex => _currentIndex;
  bool get isMenuOpen => _isMenuOpen;
  bool get isVoiceAssistantOpen => _isVoiceAssistantOpen;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void toggleMenu(bool open) {
    _isMenuOpen = open;
    notifyListeners();
  }

  void toggleVoiceAssistant(bool open) {
    _isVoiceAssistantOpen = open;
    notifyListeners();
  }
}
