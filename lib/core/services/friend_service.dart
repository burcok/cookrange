import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../localization/app_localizations.dart';

enum FriendshipStatus {
  none,
  pending_sent,
  pending_received,
  friends,
}

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final NotificationService _notificationService = NotificationService();

  String? get currentUserId => _auth.currentUser?.uid;

  // Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();
    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: q + '\uf8ff')
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
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
      if (friendIds.isEmpty) return [];

      final List<UserModel> friends = [];
      // Chunking if needed, but for now simple loop for reliability
      for (final fid in friendIds) {
        final userDoc = await _firestore.collection('users').doc(fid).get();
        if (userDoc.exists) {
          friends.add(UserModel.fromFirestore(userDoc));
        }
      }
      return friends;
    });
  }

  // Send Friend Request
  Future<void> sendFriendRequest(
      BuildContext context, String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Check if already friends or pending
    final status = await checkFriendshipStatus(targetUserId);
    if (status != FriendshipStatus.none) return;

    // 1. Create outgoing request (sender's side)
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('friend_requests')
        .doc(targetUserId)
        .set({'type': 'outgoing', 'timestamp': FieldValue.serverTimestamp()});

    // 2. Create incoming request (target's side)
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('friend_requests')
        .doc(uid)
        .set({'type': 'incoming', 'timestamp': FieldValue.serverTimestamp()});

    // 3. Send Notification
    final currentUserData = await _auth.getUserData(uid);
    final userName = currentUserData?.displayName ?? "Someone";

    final title = AppLocalizations.of(context)
        .translate('community.friend_request_title');
    final body = AppLocalizations.of(context)
        .translate('community.friend_request_body')
        .replaceAll('{name}', userName);

    await _notificationService.sendNotification(
      targetUserId: targetUserId,
      title: title,
      body: body,
      type: NotificationType.friend_request,
      relatedId: uid, // Sender ID
    );
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(
      BuildContext context, String senderUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // 1. Add to my friends
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(senderUserId)
        .set({'since': FieldValue.serverTimestamp()});

    // 2. Add me to their friends
    await _firestore
        .collection('users')
        .doc(senderUserId)
        .collection('friends')
        .doc(uid)
        .set({'since': FieldValue.serverTimestamp()});

    // 3. Delete request docs
    await _deleteRequestDocs(uid, senderUserId);

    // 4. Notify sender
    final currentUserData = await _auth.getUserData(uid);
    final userName = currentUserData?.displayName ?? "Someone";

    final title = AppLocalizations.of(context)
        .translate('community.friend_accepted_title');
    final body = AppLocalizations.of(context)
        .translate('community.friend_accepted_body')
        .replaceAll('{name}', userName);

    await _notificationService.sendNotification(
      targetUserId: senderUserId,
      title: title,
      body: body,
      type: NotificationType.friend_accepted,
      relatedId: uid,
    );

    // 5. Delete the original friend request notification for the receiver (me)
    await _notificationService.deleteNotificationByRelatedId(
      targetUserId: uid,
      relatedId: senderUserId,
      type: NotificationType.friend_request,
    );
  }

  // Reject Friend Request
  Future<void> rejectFriendRequest(String senderUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _deleteRequestDocs(uid, senderUserId);
  }

  // Cancel Sent Request
  Future<void> cancelFriendRequest(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _deleteRequestDocs(uid, targetUserId);
  }

  Future<void> _deleteRequestDocs(String uid1, String uid2) async {
    // Delete for user 1
    await _firestore
        .collection('users')
        .doc(uid1)
        .collection('friend_requests')
        .doc(uid2)
        .delete();

    // Delete for user 2
    await _firestore
        .collection('users')
        .doc(uid2)
        .collection('friend_requests')
        .doc(uid1)
        .delete();
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
      if (type == 'outgoing') return FriendshipStatus.pending_sent;
      if (type == 'incoming') return FriendshipStatus.pending_received;
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
}
