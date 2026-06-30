import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../models/notification_model.dart';

/// Manages per-type notification mute preferences.
/// Stored in users/{uid}.notification_muted as a map of type -> bool.
class NotificationPreferencesService {
  static final NotificationPreferencesService _instance =
      NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;
  NotificationPreferencesService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  static const _field = 'notification_muted';

  /// Grouped notification type keys displayed in Settings
  static final preferencePairs = <String, List<NotificationType>>{
    'likes': [
      NotificationType.likePost,
      NotificationType.likeComment,
      NotificationType.reaction,
    ],
    'comments': [NotificationType.comment],
    'friends': [
      NotificationType.friendRequest,
      NotificationType.friendAccepted,
      NotificationType.follow,
    ],
    'system': [
      NotificationType.system,
      NotificationType.streakMilestone,
      NotificationType.mealPlan,
    ],
    'referral': [NotificationType.referral],
    'reminders': [
      NotificationType.mealReminder,
      NotificationType.streakAtRisk,
      NotificationType.weeklyPlanReady,
    ],
  };

  Future<Map<String, bool>> getPreferences() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final muted = doc.data()?[_field] as Map<String, dynamic>? ?? {};
      final result = <String, bool>{};
      for (final key in preferencePairs.keys) {
        result[key] = muted[key] as bool? ?? false;
      }
      return result;
    } catch (e) {
      debugPrint('NotificationPreferencesService.getPreferences error: $e');
      return {};
    }
  }

  Future<void> setMuted(String groupKey, bool muted) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set(
        {
          _field: {groupKey: muted}
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('NotificationPreferencesService.setMuted error: $e');
    }
  }

  /// Returns true if [group] is muted for [uid].
  Future<bool> isGroupMuted(String uid, String group) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final muted = doc.data()?[_field] as Map<String, dynamic>? ?? {};
      return muted[group] as bool? ?? false;
    } catch (e) {
      debugPrint('NotificationPreferencesService.isGroupMuted error: $e');
      return false;
    }
  }

  /// Sets mute state for [group] for [uid].
  Future<void> setGroupMuted(String uid, String group, bool muted) async {
    try {
      await _db.collection('users').doc(uid).set(
        {
          _field: {group: muted}
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('NotificationPreferencesService.setGroupMuted error: $e');
    }
  }

  /// Returns true if the type is muted for the current user.
  Future<bool> isMuted(NotificationType type) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final muted = doc.data()?[_field] as Map<String, dynamic>? ?? {};
      for (final entry in preferencePairs.entries) {
        if (entry.value.contains(type) && muted[entry.key] == true) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
