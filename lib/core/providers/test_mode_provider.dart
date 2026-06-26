import 'package:flutter/foundation.dart';
import '../services/test_mode_service.dart';

class TestModeProvider extends ChangeNotifier {
  bool get isActive => TestModeService().isActive;

  Future<void> toggle() async {
    await TestModeService().setActive(!isActive);
    notifyListeners();
  }
}
