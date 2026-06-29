import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Manages unidirectional follow relationships.
///
/// Firestore paths:
///   users/{currentUid}/following/{targetUid}   — who the current user follows
///   users/{targetUid}/followers/{currentUid}   — who follows the target user
///
/// Follow is instant (no approval step) and completely separate from the
/// bidirectional friends system.
class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final NotificationService _notificationService = NotificationService();

  // ─── Helpers ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _following(String uid) =>
      _firestore.collection('users').doc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> _followers(String uid) =>
      _firestore.collection('users').doc(uid).collection('followers');

  // ─── Write operations ──────────────────────────────────────────────────────

  /// Follows [targetUid] as [currentUid]. Writes both sides in a single batch
  /// and sends a follow notification (fire-and-forget).
  Future<void> follow(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return;
    debugPrint('FollowService.follow: $currentUid → $targetUid');

    try {
      final batch = _firestore.batch();
      final followedAtPayload = {'followedAt': FieldValue.serverTimestamp()};

      // users/{currentUid}/following/{targetUid}
      batch.set(_following(currentUid).doc(targetUid), followedAtPayload);
      // users/{targetUid}/followers/{currentUid}
      batch.set(_followers(targetUid).doc(currentUid), followedAtPayload);

      await batch.commit();
      debugPrint('FollowService.follow: batch committed');

      // Fire-and-forget notification fan-out
      unawaited(_sendFollowNotification(currentUid, targetUid));
    } catch (e, st) {
      debugPrint('FollowService.follow error: $e\n$st');
      rethrow;
    }
  }

  /// Unfollows [targetUid] as [currentUid]. Deletes both sides in a batch.
  Future<void> unfollow(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return;
    debugPrint('FollowService.unfollow: $currentUid ↛ $targetUid');

    try {
      final batch = _firestore.batch();
      batch.delete(_following(currentUid).doc(targetUid));
      batch.delete(_followers(targetUid).doc(currentUid));
      await batch.commit();
      debugPrint('FollowService.unfollow: batch committed');
    } catch (e, st) {
      debugPrint('FollowService.unfollow error: $e\n$st');
      rethrow;
    }
  }

  // ─── Read operations ───────────────────────────────────────────────────────

  /// Real-time stream: true if [currentUid] is currently following [targetUid].
  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    return _following(currentUid)
        .doc(targetUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Returns the list of UIDs that [uid] follows.
  Future<List<String>> getFollowingIds(String uid) async {
    try {
      final snap = await _following(uid).get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('FollowService.getFollowingIds error: $e');
      return [];
    }
  }

  /// Returns the number of users who follow [uid] using Firestore count().
  Future<int> getFollowersCount(String uid) async {
    try {
      final result = await _followers(uid).count().get();
      return result.count ?? 0;
    } catch (e) {
      debugPrint('FollowService.getFollowersCount error: $e');
      return 0;
    }
  }

  /// Returns the number of users that [uid] follows using Firestore count().
  Future<int> getFollowingCount(String uid) async {
    try {
      final result = await _following(uid).count().get();
      return result.count ?? 0;
    } catch (e) {
      debugPrint('FollowService.getFollowingCount error: $e');
      return 0;
    }
  }

  // ─── Notification ──────────────────────────────────────────────────────────

  Future<void> _sendFollowNotification(
      String actorUid, String targetUid) async {
    try {
      final actorData = await _auth.getUserData(actorUid);
      await _notificationService.sendNotification(
        targetUserId: targetUid,
        type: NotificationType.follow,
        actorUid: actorUid,
        actorName: actorData?.displayName,
        actorPhotoUrl: actorData?.photoURL,
        relatedId: actorUid,
      );
      debugPrint('FollowService: follow notification sent to $targetUid');
    } catch (e) {
      debugPrint('FollowService._sendFollowNotification error: $e');
    }
  }
}
