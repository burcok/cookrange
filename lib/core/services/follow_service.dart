import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'crashlytics_service.dart';

/// Manages unidirectional follow relationships.
///
/// Firestore paths:
///   users/{currentUid}/following/{targetUid}   — who the current user follows
///   users/{targetUid}/followers/{currentUid}   — who follows the target user
///
/// Follow is instant (no approval step) and completely separate from the
/// bidirectional friends system.
///
/// Writes go through the `followUser`/`unfollowUser` Cloud Functions (SEC-06)
/// so the edge write and the follow notification commit atomically, with the
/// actor always derived server-side from the caller's own auth identity.
class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Helpers ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _following(String uid) =>
      _firestore.collection('users').doc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> _followers(String uid) =>
      _firestore.collection('users').doc(uid).collection('followers');

  // ─── Write operations ──────────────────────────────────────────────────────

  /// Follows [targetUid] as [currentUid] (the currently authenticated user —
  /// the server derives the real actor from the auth token regardless).
  Future<void> follow(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return;
    debugPrint('FollowService.follow: $currentUid → $targetUid');

    try {
      await FirebaseFunctions.instance
          .httpsCallable('followUser')
          .call({'targetUid': targetUid});
      debugPrint('FollowService.follow: done');
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('FollowService.follow error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FollowService.follow targetUid=$targetUid'));
      rethrow;
    } catch (e, st) {
      debugPrint('FollowService.follow error: $e\n$st');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FollowService.follow targetUid=$targetUid'));
      rethrow;
    }
  }

  /// Unfollows [targetUid] as [currentUid].
  Future<void> unfollow(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return;
    debugPrint('FollowService.unfollow: $currentUid ↛ $targetUid');

    try {
      await FirebaseFunctions.instance
          .httpsCallable('unfollowUser')
          .call({'targetUid': targetUid});
      debugPrint('FollowService.unfollow: done');
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('FollowService.unfollow error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FollowService.unfollow targetUid=$targetUid'));
      rethrow;
    } catch (e, st) {
      debugPrint('FollowService.unfollow error: $e\n$st');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FollowService.unfollow targetUid=$targetUid'));
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
}
