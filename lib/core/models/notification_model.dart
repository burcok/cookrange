import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification categories. Stored in Firestore as the enum `name`.
///
/// Backward-compatibility: older documents wrote a smaller set of names
/// (`like`, `comment`, `system`, `follow`, `friendRequest`,
/// `friendAccepted`). [NotificationTypeX.fromName] still parses those, so
/// existing notifications keep rendering. New code should prefer the granular
/// values below.
enum NotificationType {
  // Legacy / generic
  like,
  comment,
  system,
  follow,
  friendRequest,
  friendAccepted,
  // Granular (new)
  likePost,
  likeComment,
  reaction,
  referral,
  streakMilestone,
  mealPlan,
  // Application lifecycle
  coachApplicationApproved,
  coachApplicationRejected,
  gymApplicationApproved,
  gymApplicationRejected,
  // Phase 15
  streakFreezeUsed,
  achievementEarned,
  mealReminder,
  streakAtRisk,
  weeklyPlanReady,
  // Faz 0 §0.6 (S18): gym_wars had no automatic end — endWar() existed
  // with zero callers, so a war's status stayed 'active' forever past its
  // end_date. endExpiredGymWars (functions/index.js) now closes it and
  // notifies both gym owners of the result.
  gymWarEnded,
  // Faz 1 §1.7: a mutual friend's geofence-confirmed gym arrival
  // (functions/presence.js's onGymPresenceCreated trigger). metadata carries
  // `gymName`; actorUid/actorName/actorPhotoUrl are the arriving friend.
  friendAtGym,
  // Faz 3 §3.5: a gym/coach/admin sent this user a meal-plan template
  // (`sendPlanOffer` callable, functions/templates.js). actorUid/actorName
  // are the sender; relatedId is the plan_offers/{id} doc; metadata carries
  // `templateName`.
  planOfferReceived,
  // Faz 3 §3.5: the member declined a plan offer — sent to the ORIGINAL
  // SENDER (functions/templates.js's onPlanOfferResponded trigger), quiet by
  // design ("üye baskı altında kalmaz" — no accusatory framing). actorUid/
  // actorName are the declining member; relatedId is the plan_offers/{id}
  // doc; metadata carries an optional `reason`.
  planOfferDeclined,
  // Faz 4 §4.3: a gym owner/coach invited this (tier-0) member to turn on
  // progress sharing (`sendProgressShareInvite`, functions/summaries.js) —
  // fires at most ONCE ever per (scope, member) pair, never repeated
  // automatically. actorUid/actorName are the sender; relatedId is the
  // scopeId (`gym_{gymId}` | `coach_{uid}`); metadata carries `scopeType`
  // and, for a gym scope, `gymName` (the business name, not the owner's
  // personal displayName).
  progressShareInviteRequested,
  // Faz 5 §5.1: a level-up threshold was just crossed (`awardXp`,
  // functions/progress.js) — the celebration hook the plan asks for, reusing
  // this same notification pipeline rather than a new mechanism (no
  // confetti/animation library exists in this codebase). No actor (a
  // self-reported milestone, like `streakMilestone`); metadata carries
  // `level` and `xp` (the new totals, both already server-written to
  // `users/{uid}` by the time this notification lands).
  levelUp,
  // Faz 6 §6.5: a gym-issued invite code (`referrals/{code}`, `type: 'gym'`)
  // was just redeemed (`applyReferral`'s gym branch, functions/economy.js) —
  // sent to the GYM OWNER, not the redeemer. Deliberately no actor identity
  // is ever rendered for this type (see NotificationPresenter): "bireysel
  // kullanıcı kimliği salona gitmez" (individual identity never reaches the
  // gym) applies here exactly as it does to the funnel report itself.
  // actorUid is present on the doc for admin/audit lookups only; metadata is
  // unused today.
  gymAttribution,
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
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
