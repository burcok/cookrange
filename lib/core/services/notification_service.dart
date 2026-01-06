import 'package:cloud_firestore/cloud_firestore.dart';
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
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isRead: data['isRead'] ?? false,
          type: _parseType(data['type']),
          relatedId: data['relatedId'],
        );
      }).toList();
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

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return NotificationModel(
        id: doc.id,
        title: data['title'] ?? '',
        body: data['body'] ?? '',
        timestamp:
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isRead: data['isRead'] ?? false,
        type: _parseType(data['type']),
        relatedId: data['relatedId'],
      );
    }).toList();
  }

  // Create a notification
  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId,
  }) async {
    try {
      await _userNotifications(targetUserId).add({
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type.name,
        'relatedId': relatedId,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _userNotifications(uid).doc(notificationId).update({'isRead': true});
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

  NotificationType _parseType(String? type) {
    return NotificationType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => NotificationType.system,
    );
  }

  // Delete notification by relatedId and type
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
      print('Error deleting notification by relatedId: $e');
    }
  }
}
