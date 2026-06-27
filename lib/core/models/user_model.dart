import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_nutrition_profile.dart';
import 'subscription_model.dart';

/// Represents the main user document in Firestore.
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isOnline;
  final bool onboardingCompleted;
  final Timestamp? createdAt;
  final Timestamp? lastLoginAt;
  final Timestamp? lastActiveAt;
  final Timestamp? onboardingCompletedAt;
  final Map<String, dynamic>? onboardingData;
  final String? appVersion;
  final String? buildNumber;
  final Timestamp? userVerified;
  final Map<String, bool>? profileVisibility; // Field: isVisible
  final bool isPrivate;
  final int? primaryColor;
  final SubscriptionTier subscriptionTier;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.isOnline,
    required this.onboardingCompleted,
    this.createdAt,
    this.lastLoginAt,
    this.lastActiveAt,
    this.onboardingCompletedAt,
    this.onboardingData,
    this.appVersion,
    this.buildNumber,
    this.userVerified,
    this.profileVisibility,
    this.isPrivate = false,
    this.primaryColor,
    this.subscriptionTier = SubscriptionTier.free,
  });

  /// Creates a UserModel from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      isOnline: data['is_online'] as bool? ?? false,
      onboardingCompleted: data['onboarding_completed'] as bool? ?? false,
      createdAt: data['created_at'] as Timestamp?,
      lastLoginAt: data['last_login_at'] as Timestamp?,
      lastActiveAt: data['last_active_at'] as Timestamp?,
      onboardingCompletedAt: data['onboarding_completed_at'] as Timestamp?,
      onboardingData: data['onboarding_data'] as Map<String, dynamic>?,
      appVersion: data['app_version'] as String?,
      buildNumber: data['build_number'] as String?,
      userVerified: data['user_verified'] is Timestamp
          ? data['user_verified'] as Timestamp
          : null,
      profileVisibility:
          (data['profile_visibility'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ),
      isPrivate: data['is_private'] as bool? ?? false,
      primaryColor: data['primary_color'] as int?,
      subscriptionTier:
          SubscriptionTier.fromString(data['subscription_tier'] as String?),
    );
  }

  /// Typed view over the raw [onboardingData] map.
  UserNutritionProfile get profile =>
      UserNutritionProfile.fromOnboardingData(onboardingData);

  /// Typed entitlements for the user's current subscription tier.
  Entitlements get entitlements => Entitlements(subscriptionTier);

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isOnline,
    bool? onboardingCompleted,
    Timestamp? createdAt,
    Timestamp? lastLoginAt,
    Timestamp? lastActiveAt,
    Timestamp? onboardingCompletedAt,
    Map<String, dynamic>? onboardingData,
    String? appVersion,
    String? buildNumber,
    Timestamp? userVerified,
    Map<String, bool>? profileVisibility,
    bool? isPrivate,
    int? primaryColor,
    SubscriptionTier? subscriptionTier,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isOnline: isOnline ?? this.isOnline,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      onboardingData: onboardingData ?? this.onboardingData,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      userVerified: userVerified ?? this.userVerified,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      isPrivate: isPrivate ?? this.isPrivate,
      primaryColor: primaryColor ?? this.primaryColor,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }
}
