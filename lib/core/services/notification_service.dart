import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference<Map<String, dynamic>> _userNotifications(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
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

  /// Create a structured notification. The display text is rendered on the
  /// client (see `NotificationPresenter`) — only structured data is persisted.
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
      await _userNotifications(targetUserId).add({
        'type': type.name,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        if (actorUid != null) 'actorUid': actorUid,
        if (actorName != null) 'actorName': actorName,
        if (actorPhotoUrl != null) 'actorPhotoUrl': actorPhotoUrl,
        if (relatedId != null) 'relatedId': relatedId,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
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

  // Delete notification by relatedId and type (used to undo like/reaction fan-out)
  Future<void> deleteNotificationByRelatedId({
    required String targetUserId,
    required String relatedId,
    required NotificationType type,
  }) async {
    try {
      final snapshot = await _userNotifications(targetUserId)
          .where('relatedId', isEqualTo: relatedId)
          .where('type', isEqualTo: type.name)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting notification by relatedId: $e');
    }
  }
}
