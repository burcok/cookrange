import 'package:cloud_firestore/cloud_firestore.dart';

/// Discovery/structure axis — independent of [GroupJoinPolicy] (how you get
/// in). 'gym' groups are auto-created by `AdminService.approveGymApplication`
/// and are deliberately NOT surfaced in general discovery (see
/// `CommunityGroupService.createGroup`'s `isPublic` derivation) — they're
/// reached from the gym's own screen, not the groups carousel.
enum GroupKind { public, private, gym }

extension GroupKindX on GroupKind {
  String get value => name;
  static GroupKind fromString(String? v) => switch (v) {
        'private' => GroupKind.private,
        'gym' => GroupKind.gym,
        _ => GroupKind.public,
      };
}

/// How a new member gets in. Only 'open' allows the existing self-join
/// (`members/{uid}` self-create) path in firestore.rules — 'request' routes
/// through `join_requests/{uid}` + owner/admin approval; 'invite' requires a
/// redeemed `group_invites/{code}` (server-side, `functions/groups.js`).
enum GroupJoinPolicy { open, request, invite }

extension GroupJoinPolicyX on GroupJoinPolicy {
  String get value => name;
  static GroupJoinPolicy fromString(String? v) => switch (v) {
        'request' => GroupJoinPolicy.request,
        'invite' => GroupJoinPolicy.invite,
        _ => GroupJoinPolicy.open,
      };
}

/// A location-based community group (e.g. a city/neighborhood/diet-style hub)
/// — Faz 2 §2.3: also the canonical home of gym groups and any group's
/// announcement/chat surface. Stored at `community_groups/{groupId}`.
class CommunityGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? district;
  final String? coverImageUrl;
  final String ownerUid;
  final int memberCount;
  final bool isPublic;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActivityAt;

  // Faz 2 §2.3 additions ------------------------------------------------
  /// Stable id for this group's message stream
  /// (`community_groups/{id}/messages`). Deliberately == [id] itself — the
  /// group's chat has no independent existence or lifecycle apart from the
  /// group (unlike a DM/ad-hoc `chats/{chatId}` doc), so a self-reference is
  /// the simplest faithful value. Kept as its own field (rather than callers
  /// just reusing [id]) because the plan's schema names it explicitly and it
  /// gives calling code one consistent "which chat" field name across DMs
  /// and groups.
  final String chatId;
  final GroupKind kind;
  final String? gymId;

  /// When true, only owner/admin members may post in the group's message
  /// stream — everyone else may still read and react (WhatsApp community
  /// "announcement" semantics). Enforced server-side by
  /// `canPostInGroup()` in firestore.rules, not just in the UI.
  final bool announcementOnly;

  /// Whether an invite code currently exists and is redeemable
  /// (`functions/groups.js: redeemGroupInvite`). The code ITSELF is
  /// deliberately NOT a field here — see `community_groups/{id}/secrets/
  /// invite` doc comment in firestore.rules for why (this doc is readable by
  /// any authenticated user; a redeemable secret can't live on it).
  final bool inviteEnabled;
  final GroupJoinPolicy joinPolicy;
  final String? rulesText;
  final String? pinnedMessageId;

  /// Recency-weighted engagement signal computed by a scheduled Cloud
  /// Function (Faz 2 §2.5, not built here) — this field just needs to exist
  /// with a safe default so §2.5 has somewhere to write. Never
  /// client-computed (`canUpdateGroupCounters()` in firestore.rules does not
  /// allow a member to touch it).
  final double activityScore;
  final DateTime? activityUpdatedAt;

  const CommunityGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.city,
    this.district,
    this.coverImageUrl,
    required this.ownerUid,
    this.memberCount = 1,
    this.isPublic = true,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
    String? chatId,
    this.kind = GroupKind.public,
    this.gymId,
    this.announcementOnly = false,
    this.inviteEnabled = false,
    this.joinPolicy = GroupJoinPolicy.open,
    this.rulesText,
    this.pinnedMessageId,
    this.activityScore = 0,
    this.activityUpdatedAt,
  }) : chatId = chatId ?? id;

  /// "City · District" (or whichever parts exist).
  String get locationDisplay {
    final parts = [
      if (district != null && district!.isNotEmpty) district,
      if (city != null && city!.isNotEmpty) city,
    ];
    return parts.join(' · ');
  }

  factory CommunityGroupModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(String k) =>
        (d[k] is Timestamp) ? (d[k] as Timestamp).toDate() : DateTime(2025);
    return CommunityGroupModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String?,
      city: d['city'] as String?,
      district: d['district'] as String?,
      coverImageUrl: d['cover_image_url'] as String?,
      ownerUid: d['owner_uid'] as String? ?? '',
      memberCount: (d['member_count'] as num?)?.toInt() ?? 0,
      isPublic: d['is_public'] as bool? ?? true,
      tags: List<String>.from(d['tags'] ?? const []),
      createdAt: ts('created_at'),
      updatedAt: ts('updated_at'),
      lastActivityAt: ts('last_activity_at'),
      chatId: d['chat_id'] as String? ?? doc.id,
      kind: GroupKindX.fromString(d['kind'] as String?),
      gymId: d['gym_id'] as String?,
      announcementOnly: d['announcement_only'] as bool? ?? false,
      inviteEnabled: d['invite_enabled'] as bool? ?? false,
      joinPolicy: GroupJoinPolicyX.fromString(d['join_policy'] as String?),
      rulesText: d['rules_text'] as String?,
      pinnedMessageId: d['pinned_message_id'] as String?,
      activityScore: (d['activity_score'] as num?)?.toDouble() ?? 0,
      activityUpdatedAt: d['activity_updated_at'] is Timestamp
          ? (d['activity_updated_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      'owner_uid': ownerUid,
      'member_count': memberCount,
      'is_public': isPublic,
      'tags': tags,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_activity_at': Timestamp.fromDate(lastActivityAt),
      'chat_id': chatId,
      'kind': kind.value,
      if (gymId != null) 'gym_id': gymId,
      'announcement_only': announcementOnly,
      'invite_enabled': inviteEnabled,
      'join_policy': joinPolicy.value,
      if (rulesText != null) 'rules_text': rulesText,
      if (pinnedMessageId != null) 'pinned_message_id': pinnedMessageId,
      'activity_score': activityScore,
      if (activityUpdatedAt != null)
        'activity_updated_at': Timestamp.fromDate(activityUpdatedAt!),
    };
  }

  CommunityGroupModel copyWith({
    String? name,
    String? description,
    bool? announcementOnly,
    bool? inviteEnabled,
    GroupJoinPolicy? joinPolicy,
    String? rulesText,
    String? pinnedMessageId,
    int? memberCount,
  }) {
    return CommunityGroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      city: city,
      district: district,
      coverImageUrl: coverImageUrl,
      ownerUid: ownerUid,
      memberCount: memberCount ?? this.memberCount,
      isPublic: isPublic,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastActivityAt: lastActivityAt,
      chatId: chatId,
      kind: kind,
      gymId: gymId,
      announcementOnly: announcementOnly ?? this.announcementOnly,
      inviteEnabled: inviteEnabled ?? this.inviteEnabled,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      rulesText: rulesText ?? this.rulesText,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      activityScore: activityScore,
      activityUpdatedAt: activityUpdatedAt,
    );
  }
}

// Faz 2 §2.3: added 'admin' — a real, assignable rank between owner and
// moderator (gym staff / group co-managers). 'moderator' remains part of the
// enum but note it is STILL never assigned by any service method as of this
// change either — see CommunityGroupService doc comment on `setMemberRole`.
enum GroupMemberRole { owner, admin, moderator, member }

extension GroupMemberRoleX on GroupMemberRole {
  String get value => name;
  static GroupMemberRole fromString(String? v) => switch (v) {
        'owner' => GroupMemberRole.owner,
        'admin' => GroupMemberRole.admin,
        'moderator' => GroupMemberRole.moderator,
        _ => GroupMemberRole.member,
      };
}

/// A member of a group, stored at `community_groups/{groupId}/members/{uid}`.
class CommunityGroupMemberModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final GroupMemberRole role;
  final DateTime joinedAt;

  /// Set by a 'mute' moderation action (`CommunityGroupService.muteMember`);
  /// null/expired = free to post. Denormalized onto the member doc (rather
  /// than requiring a separate query over `moderation/*`) because
  /// firestore.rules' `canPostInGroup()` needs to check it on every message
  /// create — a single already-fetched doc, not a query.
  final DateTime? mutedUntil;

  /// Set by a 'ban' moderation action. The doc is kept (not deleted) so a
  /// banned uid can never re-create it via the self-join path — see the
  /// `members/{memberId}` create rule's join_policy branch, which is only
  /// reachable when no doc exists yet.
  final bool banned;

  const CommunityGroupMemberModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    this.role = GroupMemberRole.member,
    required this.joinedAt,
    this.mutedUntil,
    this.banned = false,
  });

  factory CommunityGroupMemberModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityGroupMemberModel(
      uid: doc.id,
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
      role: GroupMemberRoleX.fromString(d['role'] as String?),
      joinedAt: (d['joined_at'] is Timestamp)
          ? (d['joined_at'] as Timestamp).toDate()
          : DateTime(2025),
      mutedUntil: d['muted_until'] is Timestamp
          ? (d['muted_until'] as Timestamp).toDate()
          : null,
      banned: d['banned'] as bool? ?? false,
    );
  }

  /// True while an active (non-expired) mute is in effect.
  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toFirestore() {
    return {
      if (displayName != null) 'display_name': displayName,
      if (photoURL != null) 'photo_url': photoURL,
      'role': role.value,
      'joined_at': Timestamp.fromDate(joinedAt),
      if (mutedUntil != null) 'muted_until': Timestamp.fromDate(mutedUntil!),
      'banned': banned,
    };
  }
}

enum GroupJoinRequestStatus { pending, approved, declined }

extension GroupJoinRequestStatusX on GroupJoinRequestStatus {
  String get value => name;
  static GroupJoinRequestStatus fromString(String? v) => switch (v) {
        'approved' => GroupJoinRequestStatus.approved,
        'declined' => GroupJoinRequestStatus.declined,
        _ => GroupJoinRequestStatus.pending,
      };
}

/// A pending ask to join a `join_policy == 'request'` group. Stored at
/// `community_groups/{groupId}/join_requests/{uid}` (doc id == requester's
/// uid — one outstanding request per user per group, idempotent re-request).
class GroupJoinRequestModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final String? message;
  final GroupJoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? respondedBy;

  const GroupJoinRequestModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    this.message,
    this.status = GroupJoinRequestStatus.pending,
    required this.requestedAt,
    this.respondedAt,
    this.respondedBy,
  });

  factory GroupJoinRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupJoinRequestModel(
      uid: doc.id,
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
      message: d['message'] as String?,
      status: GroupJoinRequestStatusX.fromString(d['status'] as String?),
      requestedAt: (d['requested_at'] is Timestamp)
          ? (d['requested_at'] as Timestamp).toDate()
          : DateTime(2025),
      respondedAt: d['responded_at'] is Timestamp
          ? (d['responded_at'] as Timestamp).toDate()
          : null,
      respondedBy: d['responded_by'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      if (displayName != null) 'display_name': displayName,
      if (photoURL != null) 'photo_url': photoURL,
      if (message != null) 'message': message,
      'status': status.value,
      'requested_at': Timestamp.fromDate(requestedAt),
      if (respondedAt != null) 'responded_at': Timestamp.fromDate(respondedAt!),
      if (respondedBy != null) 'responded_by': respondedBy,
    };
  }
}

enum GroupModerationAction { mute, kick, ban, unmute, unban }

extension GroupModerationActionX on GroupModerationAction {
  String get value => name;
  static GroupModerationAction fromString(String? v) => switch (v) {
        'kick' => GroupModerationAction.kick,
        'ban' => GroupModerationAction.ban,
        'unmute' => GroupModerationAction.unmute,
        'unban' => GroupModerationAction.unban,
        _ => GroupModerationAction.mute,
      };
}

/// Append-only moderation log entry —
/// `community_groups/{groupId}/moderation/{autoId}`. Never updated/deleted
/// (mirrors `admin_audit`'s immutability). The target uid may read their own
/// entries (transparency: "muted, reason X, until Y") but never anyone
/// else's, and never write.
class GroupModerationActionModel {
  final String id;
  final String targetUid;
  final GroupModerationAction action;
  final String? reason;
  final int? durationMinutes;
  final String issuedBy;
  final DateTime createdAt;

  const GroupModerationActionModel({
    required this.id,
    required this.targetUid,
    required this.action,
    this.reason,
    this.durationMinutes,
    required this.issuedBy,
    required this.createdAt,
  });

  factory GroupModerationActionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupModerationActionModel(
      id: doc.id,
      targetUid: d['target_uid'] as String? ?? '',
      action: GroupModerationActionX.fromString(d['action'] as String?),
      reason: d['reason'] as String?,
      durationMinutes: (d['duration_minutes'] as num?)?.toInt(),
      issuedBy: d['issued_by'] as String? ?? '',
      createdAt: (d['created_at'] is Timestamp)
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime(2025),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'target_uid': targetUid,
      'action': action.value,
      if (reason != null) 'reason': reason,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      'issued_by': issuedBy,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
