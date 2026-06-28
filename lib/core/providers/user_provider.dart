import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/user_nutrition_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Holds the authenticated user's public profile ([user]) plus their private
/// nutrition profile ([nutritionProfile]), which is loaded from the
/// `users/{uid}/private/nutrition` owner-only subcollection.
///
/// All downstream code (home dashboard, meal plan service, etc.) should read
/// `user` — which already has the private nutrition data merged into
/// `onboardingData` via [UserModel.withPrivateNutrition] — so existing call
/// sites require no changes.
class UserProvider extends ChangeNotifier {
  UserModel? _user;
  UserNutritionProfile _nutritionProfile = UserNutritionProfile.empty;
  bool _isLoading = false;

  UserModel? get user => _user;

  /// The owner's full nutrition profile, loaded from the private subcollection.
  /// Always [UserNutritionProfile.empty] when no user is logged in.
  UserNutritionProfile get nutritionProfile => _nutritionProfile;

  bool get isLoading => _isLoading;

  Future<void> loadUser({bool silent = false}) async {
    final authUser = AuthService().currentUser;
    if (authUser == null) {
      _user = null;
      _nutritionProfile = UserNutritionProfile.empty;
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final base = await AuthService().getUserData(authUser.uid);
      if (base != null) {
        // Load owner-only PII and merge into the model so user.profile is full.
        final privateData = await FirestoreService()
            .getPrivateNutritionData(authUser.uid);
        if (privateData != null && privateData.isNotEmpty) {
          _user = base.withPrivateNutrition(privateData);
        } else {
          _user = base;
        }
        _nutritionProfile =
            UserNutritionProfile.fromOnboardingData(_user!.onboardingData);
      } else {
        _user = null;
        _nutritionProfile = UserNutritionProfile.empty;
      }
    } catch (e) {
      debugPrint('Error loading user in UserProvider: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  void setUser(UserModel? user) {
    _user = user;
    _nutritionProfile = user != null
        ? UserNutritionProfile.fromOnboardingData(user.onboardingData)
        : UserNutritionProfile.empty;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await loadUser(silent: true);
  }

  /// Splits [data] into public (non-PII) and private (PII) parts and writes
  /// each to the correct Firestore location.
  Future<void> updateUserProfile(
      Map<String, dynamic> data, Map<String, bool> visibility) async {
    _isLoading = true;
    notifyListeners();
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;

      // PII fields go to owner-only private subcollection.
      const privateKeys = {
        'personal_info', 'allergies', 'dietary_restrictions',
        'disliked_foods', 'avoid_ingredients',
      };
      final privateData = <String, dynamic>{};
      final publicData = <String, dynamic>{};
      for (final entry in data.entries) {
        if (privateKeys.contains(entry.key)) {
          privateData[entry.key] = entry.value;
        } else {
          publicData[entry.key] = entry.value;
        }
      }

      final futures = <Future>[];
      if (privateData.isNotEmpty) {
        futures.add(FirestoreService().savePrivateNutritionData(uid, privateData));
      }
      if (publicData.isNotEmpty || visibility.isNotEmpty) {
        futures.add(AuthService().updateUserOnboardingData({
          if (publicData.isNotEmpty) 'onboarding_data': publicData,
          'profile_visibility': visibility,
        }));
      }
      await Future.wait(futures);
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
