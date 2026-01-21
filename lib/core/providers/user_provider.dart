import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadUser({bool silent = false}) async {
    final authUser = AuthService().currentUser;
    if (authUser == null) {
      _user = null;
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _user = await AuthService().getUserData(authUser.uid);
    } catch (e) {
      debugPrint('Error loading user in UserProvider: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        // Even if silent, we want to notify that the user data changed
        notifyListeners();
      }
    }
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await loadUser(silent: true);
  }

  Future<void> updateUserProfile(
      Map<String, dynamic> data, Map<String, bool> visibility) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updates = {
        'onboarding_data': data,
        'profile_visibility': visibility,
      };
      await AuthService().updateUserOnboardingData(updates);
      await refreshUser();
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
