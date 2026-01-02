import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    final authUser = AuthService().currentUser;
    if (authUser == null) {
      _user = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _user = await AuthService().getUserData(authUser.uid);
    } catch (e) {
      debugPrint('Error loading user in UserProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await loadUser();
  }
}
