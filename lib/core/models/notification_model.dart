import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification categories. Stored in Firestore as the enum `name`.
///
/// Backward-compatibility: older documents wrote a smaller set of names
/// (`like`, `comment`, `system`, `follow`, `friend_request`,
/// `friend_accepted`). [NotificationTypeX.fromName] still parses those, so
/// existing notifications keep rendering. New code should prefer the granular
/// values below.
enum NotificationType {
  // Legacy / generic
  like,
  comment,
  system,
  follow,
  friend_request,
  friend_accepted,
  // Granular (new)
  likePost,
  likeComment,
  reaction,
  referral,
  streakMilestone,
  mealPlan,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromName(String? name) {
    if (name == null) return NotificationType.system;
    for (final t in NotificationType.values) {
      if (t.name == name) return t;
    }
    return NotificationType.system;
  }
}

/// A user-facing notification.
///
/// The display text is NOT stored anymore — only structured data (type, actor
/// identity, related ids and [metadata]). The frontend renders the localized
/// title/body dynamically (see `NotificationPresenter`). [title]/[body] are kept
/// only as a fallback for legacy documents created before this redesign.
class NotificationModel {
  final String id;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  /// Who triggered the notification (null for system notifications).
  final String? actorUid;
  final String? actorName;
  final String? actorPhotoUrl;

  /// Primary related entity. Meaning depends on [type]:
  /// post-related → postId; friend-related → the other user's uid.
  final String? relatedId;

  /// Extra structured data, e.g. `{ 'emoji': '🔥' }`, `{ 'streakDays': 7 }`,
  /// `{ 'rewardDays': 7 }`, `{ 'commentId': '...' }`.
  final Map<String, dynamic>? metadata;

  /// Legacy pre-rendered strings (only present on old documents).
  final String? legacyTitle;
  final String? legacyBody;

  NotificationModel({
    required this.id,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actorUid,
    this.actorName,
    this.actorPhotoUrl,
    this.relatedId,
    this.metadata,
    this.legacyTitle,
    this.legacyBody,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      type: NotificationTypeX.fromName(data['type'] as String?),
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      actorUid: data['actorUid'] as String?,
      actorName: data['actorName'] as String?,
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      relatedId: data['relatedId'] as String?,
      metadata: (data['metadata'] as Map<String, dynamic>?),
      legacyTitle: data['title'] as String?,
      legacyBody: data['body'] as String?,
    );
  }

  /// Serializes the structured payload for a NEW notification. Server timestamp
  /// is added by the service, not here.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'isRead': isRead,
      if (actorUid != null) 'actorUid': actorUid,
      if (actorName != null) 'actorName': actorName,
      if (actorPhotoUrl != null) 'actorPhotoUrl': actorPhotoUrl,
      if (relatedId != null) 'relatedId': relatedId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Returns a copy with [isRead] set to true (for optimistic UI updates).
  NotificationModel copyWithRead() => NotificationModel(
        id: id,
        type: type,
        timestamp: timestamp,
        isRead: true,
        actorUid: actorUid,
        actorName: actorName,
        actorPhotoUrl: actorPhotoUrl,
        relatedId: relatedId,
        metadata: metadata,
        legacyTitle: legacyTitle,
        legacyBody: legacyBody,
      );

  /// True when this is an old document with no structured actor data — the
  /// presenter falls back to [legacyTitle]/[legacyBody].
  bool get isLegacy =>
      actorUid == null &&
      metadata == null &&
      (legacyTitle != null || legacyBody != null);
}
