import 'package:shared_preferences/shared_preferences.dart';

class TestModeService {
  static final TestModeService _instance = TestModeService._internal();
  factory TestModeService() => _instance;
  TestModeService._internal();

  static const _key = 'test_mode_enabled';
  bool _isActive = false;

  bool get isActive => _isActive;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isActive = prefs.getBool(_key) ?? false;
  }

  Future<void> setActive(bool value) async {
    _isActive = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
