import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
///
/// A live Firestore stream watches the user document and auto-refreshes when
/// role/subscription fields change (e.g., admin approves a coach application).
class UserProvider extends ChangeNotifier {
  UserModel? _user;
  UserNutritionProfile _nutritionProfile = UserNutritionProfile.empty;
  bool _isLoading = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  UserModel? get user => _user;

  /// The owner's full nutrition profile, loaded from the private subcollection.
  /// Always [UserNutritionProfile.empty] when no user is logged in.
  UserNutritionProfile get nutritionProfile => _nutritionProfile;

  bool get isLoading => _isLoading;

  // ─── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadUser({bool silent = false}) async {
    final authUser = AuthService().currentUser;
    if (authUser == null) {
      await _stopLiveListener();
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
      await _fetchAndMerge(authUser.uid);
    } catch (e) {
      debugPrint('UserProvider.loadUser error: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }

    // Start live listener after the first full load so role/subscription
    // changes (e.g. admin approval) update the app without a restart.
    _startLiveListener(authUser.uid);
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
      debugPrint('UserProvider.updateUserProfile error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Live Firestore listener ────────────────────────────────────────────────

  void _startLiveListener(String uid) {
    if (_userDocSub != null) return; // already listening

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snap) async {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;

        // Only reload when role/roles or subscription tier actually changed —
        // avoids noisy rebuilds on every field touch.
        final newRole = data['user_role'] as String?;
        final newRoles = (data['user_roles'] as List<dynamic>?)?.join(',') ?? '';
        final newTier = data['subscription_tier'] as String?;
        final oldRole = _user?.userRole.firestoreValue;
        final oldRoles = _user?.userRoles.map((r) => r.firestoreValue).join(',') ?? '';
        final oldTier = _user?.subscriptionTier.name;

        if (newRole != oldRole || newRoles != oldRoles || newTier != oldTier) {
          debugPrint(
              'UserProvider: role/tier changed ($oldRole→$newRole, $oldTier→$newTier) — refreshing');
          await _fetchAndMerge(uid);
          notifyListeners();
        }
      },
      onError: (e) =>
          debugPrint('UserProvider live listener error: $e'),
    );
  }

  Future<void> _stopLiveListener() async {
    await _userDocSub?.cancel();
    _userDocSub = null;
  }

  Future<void> _fetchAndMerge(String uid) async {
    final base = await AuthService().getUserData(uid);
    if (base != null) {
      final privateData =
          await FirestoreService().getPrivateNutritionData(uid);
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
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }
}
