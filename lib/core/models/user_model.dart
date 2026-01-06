import 'package:cloud_firestore/cloud_firestore.dart';

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
  final int? primaryColor;

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
    this.primaryColor,
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
      userVerified: data['user_verified'] as Timestamp?,
      profileVisibility:
          (data['profile_visibility'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ),
      primaryColor: data['primary_color'] as int?,
    );
  }

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
    int? primaryColor,
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
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}
