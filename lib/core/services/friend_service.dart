import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'crashlytics_service.dart';

enum FriendshipStatus {
  none,
  pendingSent,
  pendingReceived,
  friends,
}

/// Manages the bidirectional friends system (requests, accept/reject, unfriend).
///
/// Mutation (send/accept/reject/cancel) goes through Cloud Functions callables
/// (SEC-06: `functions/social.js`) — firestore.rules denies client `create` on
/// `friends`/`friend_requests` unconditionally. The server re-verifies status,
/// writes both sides atomically, and sends the notification with the actor
/// derived from the caller's own auth identity. `removeFriend` stays
/// client-direct: it only ever deletes the caller's own subtree on both
/// sides, already safe under the owner-scoped delete rule.
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  // Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final String qLower = query.toLowerCase();
    final String qOriginal = query;

    // We do multiple queries as Firestore doesn't support "OR" between fields with prefix match easily
    // 1. Search by exact email first (often what's wanted)
    final emailQuery = _firestore
        .collection('users')
        .where('email', isEqualTo: qLower)
        .limit(5)
        .get();

    // 2. Search by displayName prefix (Original Case)
    final nameOriginalQuery = _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: qOriginal)
        .where('displayName', isLessThan: '$qOriginal')
        .limit(10)
        .get();

    // 3. Search by displayName prefix (Lowercase - works better if stored names are lowercase or for specific matches)
    final nameLowerQuery = _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: qLower)
        .where('displayName', isLessThan: '$qLower')
        .limit(10)
        .get();

    // 4. Search by email prefix
    final emailPrefixQuery = _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: qLower)
        .where('email', isLessThan: '$qLower')
        .limit(10)
        .get();

    try {
      final results = await Future.wait([
        emailQuery,
        nameOriginalQuery,
        nameLowerQuery,
        emailPrefixQuery,
      ]);

      final Map<String, UserModel> usersMap = {};
      final String? myUid = currentUserId;

      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (doc.id == myUid) continue; // Skip self

          if (!usersMap.containsKey(doc.id)) {
            usersMap[doc.id] = UserModel.fromFirestore(doc);
          }
        }
      }

      return usersMap.values.toList();
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  // Get current user's friends
  Stream<List<UserModel>> getFriendsStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      final friendIds = snapshot.docs.map((doc) => doc.id).toList();
      if (friendIds.isEmpty) return <UserModel>[];

      try {
        // Batch fetch in chunks of 30 (Firestore whereIn limit)
        final friends = <UserModel>[];
        for (var i = 0; i < friendIds.length; i += 30) {
          final chunk = friendIds.sublist(
              i, i + 30 > friendIds.length ? friendIds.length : i + 30);
          final snap = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            friends.add(UserModel.fromFirestore(doc));
          }
        }
        return friends;
      } catch (e) {
        debugPrint('getFriendsStream fetch error: $e');
        return <UserModel>[];
      }
    });
  }

  // Send Friend Request
  Future<void> sendFriendRequest(
      BuildContext context, String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Quick client-side check for responsive UX — the callable re-verifies
    // authoritatively, so this is an optimization, not the security boundary.
    final status = await checkFriendshipStatus(targetUserId);
    if (status != FriendshipStatus.none) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendFriendRequest')
          .call({'targetUid': targetUserId});
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('sendFriendRequest error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FriendService.sendFriendRequest targetUid=$targetUserId'));
      rethrow;
    }
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(
      BuildContext context, String senderUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('respondToFriendRequest')
          .call({'senderUid': senderUserId, 'accept': true});
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('acceptFriendRequest error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FriendService.acceptFriendRequest senderUid=$senderUserId'));
      rethrow;
    }
  }

  // Reject Friend Request
  Future<void> rejectFriendRequest(String senderUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('respondToFriendRequest')
          .call({'senderUid': senderUserId, 'accept': false});
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('rejectFriendRequest error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FriendService.rejectFriendRequest senderUid=$senderUserId'));
      rethrow;
    }
  }

  // Cancel Sent Request
  Future<void> cancelFriendRequest(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelFriendRequest')
          .call({'targetUid': targetUserId});
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('cancelFriendRequest error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'FriendService.cancelFriendRequest targetUid=$targetUserId'));
      rethrow;
    }
  }

  // Check Status
  Future<FriendshipStatus> checkFriendshipStatus(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return FriendshipStatus.none;
    if (uid == targetUserId) return FriendshipStatus.none; // Self

    // Check if friends
    final friendDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(targetUserId)
        .get();
    if (friendDoc.exists) return FriendshipStatus.friends;

    // Check requests
    final reqDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('friend_requests')
        .doc(targetUserId)
        .get();

    if (reqDoc.exists) {
      final type = reqDoc.data()?['type'];
      if (type == 'outgoing') return FriendshipStatus.pendingSent;
      if (type == 'incoming') return FriendshipStatus.pendingReceived;
    }

    return FriendshipStatus.none;
  }

  // Method to remove friend (unfriend)
  Future<void> removeFriend(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(targetUserId)
        .delete();
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('friends')
        .doc(uid)
        .delete();
  }

  /// Returns just the UIDs of the current user's friends (lightweight).
  Future<List<String>> getFriendIds() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('getFriendIds error: $e');
      return [];
    }
  }

  /// Preload friends to warm up cache
  Future<void> preloadFriends() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      // Just fetch the IDs, detail fetch is asyncMap anyway
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .limit(20)
          .get();
    } catch (e) {
      // Ignore
    }
  }
}
