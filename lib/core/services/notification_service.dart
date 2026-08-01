import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'crashlytics_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  // Canonical path (BLK-03) — matches the onInAppNotificationCreated Cloud
  // Function trigger. Client `create` is denied by firestore.rules; writes go
  // through the createNotification/retractNotification callables below.
  CollectionReference<Map<String, dynamic>> _userNotifications(String uid) {
    return _firestore.collection('notifications').doc(uid).collection('items');
  }

  // Get notifications stream
  Stream<List<NotificationModel>> getNotificationsStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _userNotifications(uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Get unread notification count
  Stream<int> getUnreadCountStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(0);

    return _userNotifications(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Warming up the cache for unread count
  Future<void> preloadUnreadCount() async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      // Just a shallow query to populate Firestore cache
      await _userNotifications(uid)
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();
    } catch (e) {
      // Ignore errors during preloading
    }
  }

  // Fetch once (for existing logic if needed)
  Future<List<NotificationModel>> getNotifications() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final snapshot = await _userNotifications(uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  static const int _pageSize = 20;

  /// Paginated fetch — pass [lastDoc] for subsequent pages.
  Future<
      ({
        List<NotificationModel> items,
        DocumentSnapshot? lastDoc,
        bool hasMore
      })> getNotificationsPage({DocumentSnapshot? lastDoc}) async {
    final uid = currentUserId;
    if (uid == null) {
      return (items: <NotificationModel>[], lastDoc: null, hasMore: false);
    }

    Query<Map<String, dynamic>> query = _userNotifications(uid)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize + 1); // fetch one extra to detect hasMore

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.get();
    final hasMore = snap.docs.length > _pageSize;
    final docs = hasMore ? snap.docs.sublist(0, _pageSize) : snap.docs;

    return (
      items:
          docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList(),
      lastDoc: docs.isNotEmpty ? docs.last : null,
      hasMore: hasMore,
    );
  }

  /// Create a structured notification. Written server-side (BLK-03) by the
  /// `createNotification` callable, which derives the actor from the caller's
  /// own auth identity and re-fetches their current name/photo — the client
  /// can no longer inject an arbitrary actorName. Display text is rendered on
  /// the client (see `NotificationPresenter`) from the structured data.
  ///
  /// [actorUid]/[actorName]/[actorPhotoUrl] are accepted for call-site source
  /// compatibility but ignored: the callable always uses `context.auth.uid`.
  Future<void> sendNotification({
    required String targetUserId,
    required NotificationType type,
    String? actorUid,
    String? actorName,
    String? actorPhotoUrl,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('createNotification')
          .call({
        'targetUid': targetUserId,
        'type': type.name,
        if (relatedId != null) 'relatedId': relatedId,
        if (metadata != null) 'metadata': metadata,
      });
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Error sending notification: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'NotificationService.sendNotification type=${type.name}'));
    } catch (e, stack) {
      debugPrint('Error sending notification: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'NotificationService.sendNotification type=${type.name}'));
    }
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _userNotifications(uid).doc(notificationId).update({'isRead': true});
  }

  /// Mark multiple notifications as read in batch
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final uid = currentUserId;
    if (uid == null || notificationIds.isEmpty) return;

    final batch = _firestore.batch();
    for (var id in notificationIds) {
      batch.update(_userNotifications(uid).doc(id), {'isRead': true});
    }
    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _userNotifications(uid).doc(notificationId).delete();
  }

  // Clear all
  Future<void> clearAllNotifications() async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _firestore.batch();
    final snapshots = await _userNotifications(uid).get();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Undoes a [sendNotification] call (e.g. un-like, un-react) by deleting
  /// the matching doc(s) from [targetUserId]'s inbox. Server-side (BLK-03) via
  /// the `retractNotification` callable — the caller can only retract
  /// notifications whose `actorUid` matches their own auth identity, so one
  /// user can never delete another user's unrelated notifications.
  Future<void> deleteNotificationByRelatedId({
    required String targetUserId,
    required String relatedId,
    required NotificationType type,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('retractNotification')
          .call({
        'targetUid': targetUserId,
        'relatedId': relatedId,
        'type': type.name,
      });
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint(
          'Error deleting notification by relatedId: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason:
              'NotificationService.deleteNotificationByRelatedId type=${type.name}'));
    } catch (e, stack) {
      debugPrint('Error deleting notification by relatedId: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason:
              'NotificationService.deleteNotificationByRelatedId type=${type.name}'));
    }
  }
}
