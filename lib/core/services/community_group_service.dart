import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/community_group_model.dart';
import '../utils/local_week.dart';
import 'analytics_service.dart';
import 'crashlytics_service.dart';

/// A ranked row in a group's weekly contribution leaderboard (Faz 5 §5.3).
/// Parsed directly off `community_groups/{id}/weekly_leaderboard/{weekKey}`'s
/// `entries` array — that doc is ALREADY the fully denormalized, ranked
/// summary (`display_name`/`photo_url`/`score`/`rank` baked in by
/// `computeGroupContributionLeaderboards`, `functions/engagement_credit.js`),
/// so this class does no computation of its own, just a typed read.
class GroupContributionEntry {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final int score;
  final int rank;

  const GroupContributionEntry({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.score,
    required this.rank,
  });

  factory GroupContributionEntry.fromMap(Map<String, dynamic> map) {
    return GroupContributionEntry(
      uid: map['uid'] as String? ?? '',
      displayName: map['display_name'] as String?,
      photoURL: map['photo_url'] as String?,
      score: (map['score'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

/// CRUD + membership for location-based community groups — Faz 2 §2.3
/// expands this into the canonical "unified group" surface: gym groups,
/// announcement-only mode, join requests, moderation, and invite codes.
///
/// Collections: `community_groups/{id}` + `.../members/{uid}` +
/// `.../join_requests/{uid}` + `.../moderation/{autoId}` +
/// `.../secrets/invite` + top-level `group_invites/{code}` (server-only
/// reverse lookup for redemption). "My groups" are mirrored on
/// `users/{uid}.group_memberships` (array).
///
/// The group's own message stream ("akış + sohbet") is deliberately NOT a
/// method on this service — every group gets a paired `chats/{chat_id}` doc
/// (see [createGroup]'s `chatId == id` and the `groupId` back-reference on
/// that chat doc), so sending/reading/reacting/editing group messages reuses
/// `ChatService` exactly as-is, unchanged, with `group.chatId` as the
/// `chatId` argument. firestore.rules' `canAccessGroupChat()` /
/// `canPostInGroup()` (on `chats/{chatId}` and its `messages` subcollection)
/// are what actually enforce group membership + announcement_only for that
/// shared path — see firestore.rules' "─── Chats ───" section.
class CommunityGroupService {
  static final CommunityGroupService _instance =
      CommunityGroupService._internal();
  factory CommunityGroupService() => _instance;
  CommunityGroupService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('community_groups');

  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');

  CollectionReference<Map<String, dynamic>> _joinRequests(String groupId) =>
      _groups.doc(groupId).collection('join_requests');

  CollectionReference<Map<String, dynamic>> _moderation(String groupId) =>
      _groups.doc(groupId).collection('moderation');

  DocumentReference<Map<String, dynamic>> _inviteSecret(String groupId) =>
      _groups.doc(groupId).collection('secrets').doc('invite');

  // ── Create / read ──────────────────────────────────────────────────────────

  Future<CommunityGroupModel> createGroup({
    required String name,
    String? description,
    String? city,
    String? district,
    List<String> tags = const [],
    bool isPublic = true,
    GroupKind kind = GroupKind.public,
    String? gymId,
    GroupJoinPolicy joinPolicy = GroupJoinPolicy.open,
    bool announcementOnly = false,
    String? rulesText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final doc = _groups.doc();
    final group = CommunityGroupModel(
      id: doc.id,
      name: name,
      description: description,
      city: city,
      district: district,
      ownerUid: user.uid,
      // gym groups aren't meant to clutter general discovery (they're
      // reached from the gym's own screen) — isPublic follows kind unless
      // the caller overrides it explicitly for a non-gym kind.
      isPublic: kind == GroupKind.gym ? false : isPublic,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
      chatId: doc.id,
      kind: kind,
      gymId: kind == GroupKind.gym ? gymId : null,
      announcementOnly: announcementOnly,
      joinPolicy: joinPolicy,
      rulesText: rulesText,
    );

    // The parent doc is created FIRST and awaited on its own — NOT batched
    // together with the owner's membership doc below. firestore.rules'
    // members-create check must confirm a self-assigned role:'owner' by
    // reading the parent's owner_uid via get(); that has to observe an
    // already-committed document rather than depend on same-batch write
    // visibility, which this codebase doesn't rely on anywhere else.
    await doc.set(group.toFirestore());

    // Faz 2 §2.3 — paired chat doc (chatId == groupId; see class doc
    // comment). `participants` holds only the owner — the WHOLE group's
    // membership gets read/post access via firestore.rules'
    // `canAccessGroupChat()`/`canPostInGroup()`, keyed off `groupId`, not
    // this array (a public/gym group's membership doesn't belong in a
    // Firestore array field). `type` is 'gym' for gym groups (making
    // ChatType.gym real — chat_list_screen.dart's `_buildGymChatCard` has
    // been dormant, rendering nothing, until this) and the pre-existing
    // 'group' for public/private ones — the same chat "kind" the ad-hoc
    // `createGroupChat` flow already produces, just now optionally governed
    // by a community_groups doc when `groupId` is set.
    final chat = ChatModel(
      id: doc.id,
      participants: [user.uid],
      unreadCounts: {user.uid: 0},
      type: kind == GroupKind.gym ? ChatType.gym : ChatType.group,
      updatedAt: now,
      name: name,
      groupId: doc.id,
    );
    await _db.collection('chats').doc(doc.id).set(chat.toJson());

    final batch = _db.batch();
    batch.set(
      _members(doc.id).doc(user.uid),
      CommunityGroupMemberModel(
        uid: user.uid,
        displayName: user.displayName,
        photoURL: user.photoURL,
        role: GroupMemberRole.owner,
        joinedAt: now,
      ).toFirestore(),
    );
    batch.set(
      _db.collection('users').doc(user.uid),
      {
        'group_memberships': FieldValue.arrayUnion([doc.id])
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    unawaited(AnalyticsService()
        .logEvent(name: 'group_created', parameters: {'group_id': doc.id}));
    debugPrint('[CommunityGroupService] created group ${doc.id}');
    return group;
  }

  Stream<CommunityGroupModel?> getGroupStream(String groupId) {
    return _groups
        .doc(groupId)
        .snapshots()
        .map((d) => d.exists ? CommunityGroupModel.fromFirestore(d) : null);
  }

  /// Groups the user belongs to (read off their own doc, then fetched).
  Stream<List<CommunityGroupModel>> getMyGroupsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((userDoc) async {
      final ids = List<String>.from(
          (userDoc.data()?['group_memberships'] as List?) ?? const []);
      if (ids.isEmpty) return <CommunityGroupModel>[];
      final out = <CommunityGroupModel>[];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
        final snap =
            await _groups.where(FieldPath.documentId, whereIn: chunk).get();
        out.addAll(snap.docs.map(CommunityGroupModel.fromFirestore));
      }
      return out;
    }).handleError((Object e) {
      debugPrint('[CommunityGroupService] getMyGroupsStream error: $e');
    });
  }

  /// Public group discovery, optionally filtered by city/district.
  /// [sortBy]: 'last_activity_at' (default) | 'member_count' | 'created_at'.
  Future<List<CommunityGroupModel>> searchGroups({
    String query = '',
    String? city,
    String? district,
    String sortBy = 'last_activity_at',
    int limit = 30,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _groups.where('is_public', isEqualTo: true);
      if (city != null && city.isNotEmpty) {
        q = q.where('city', isEqualTo: city);
      }
      if (district != null && district.isNotEmpty) {
        q = q.where('district', isEqualTo: district);
      }
      q = q.orderBy(sortBy, descending: true).limit(limit);

      final snap = await q.get();
      var all = snap.docs.map(CommunityGroupModel.fromFirestore).toList();
      if (query.isNotEmpty) {
        final lower = query.toLowerCase();
        all = all
            .where((g) =>
                g.name.toLowerCase().contains(lower) ||
                (g.description?.toLowerCase().contains(lower) ?? false) ||
                g.tags.any((t) => t.toLowerCase().contains(lower)))
            .toList();
      }
      return all;
    } catch (e) {
      debugPrint('[CommunityGroupService] searchGroups error: $e');
      return [];
    }
  }

  /// "Günün en aktif grupları" (Faz 2 §2.5) — top [limit] public groups by
  /// server-computed [CommunityGroupModel.activityScore]. Uses the
  /// `community_groups (is_public, activity_score DESC)` composite index.
  /// The score itself is written only by `computeGroupActivityScores`
  /// (functions/groups.js, every 15 min) — this method never computes or
  /// writes it, only reads (see firestore.rules'
  /// `touchesProtectedGroupFields()` for why a client can't write it at all).
  Future<List<CommunityGroupModel>> getTopActiveGroups({int limit = 5}) async {
    try {
      final snap = await _groups
          .where('is_public', isEqualTo: true)
          .orderBy('activity_score', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(CommunityGroupModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('[CommunityGroupService] getTopActiveGroups error: $e');
      return [];
    }
  }

  /// City-scoped second strip ("{city} içinde yeni", Faz 2 §2.5) — the SAME
  /// activity_score ranking as [getTopActiveGroups], narrowed to one city,
  /// so a locally active group that wouldn't crack the global top 5 still
  /// surfaces for someone who specifically cares about that city. This is
  /// deliberately activity-sorted, not created_at-sorted, despite the
  /// "yeni" (new) label — read as "freshly relevant to you", matching what
  /// activity_score itself already measures (recency-weighted engagement);
  /// a plain newest-first list would need no new index at all (city +
  /// created_at already exists), which is why the plan calls out a
  /// dedicated `(is_public, city, activity_score DESC)` index for this
  /// strip specifically. Uses `groups_last_city`
  /// (`GroupsDiscoveryScreen._prefsCity`, already persisted) — no GPS
  /// permission needed.
  Future<List<CommunityGroupModel>> getActiveGroupsInCity(
    String city, {
    int limit = 10,
  }) async {
    try {
      final snap = await _groups
          .where('is_public', isEqualTo: true)
          .where('city', isEqualTo: city)
          .orderBy('activity_score', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(CommunityGroupModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('[CommunityGroupService] getActiveGroupsInCity error: $e');
      return [];
    }
  }

  /// Owner/admin settings edit — description, rules text, announcement-only.
  /// firestore.rules restricts the underlying write to owner or site admin
  /// (the group-doc `allow update` rule; group-level 'admin' role holders do
  /// NOT get this — see `setMemberRole` doc comment for why role-changing /
  /// structural edits stay owner-only while day-to-day moderation doesn't).
  Future<void> updateGroupSettings(
    String groupId, {
    String? description,
    String? rulesText,
    bool? announcementOnly,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (description != null) updates['description'] = description;
    if (rulesText != null) updates['rules_text'] = rulesText;
    if (announcementOnly != null) {
      updates['announcement_only'] = announcementOnly;
    }
    await _groups.doc(groupId).update(updates);
  }

  // ── Membership ───────────────────────────────────────────────────────────

  Future<bool> isMember(String groupId, String uid) async {
    final doc = await _members(groupId).doc(uid).get();
    return doc.exists;
  }

  Stream<bool> isMemberStream(String groupId, String uid) {
    return _members(groupId).doc(uid).snapshots().map((d) => d.exists);
  }

  /// Owner/group-admin directly adds a known user as a member — distinct
  /// from [joinGroup] (self-service) and [approveJoinRequest] (turns an
  /// existing `join_requests/{uid}` doc into membership). Useful for e.g. a
  /// gym owner adding staff without routing through invite/request. Cannot
  /// be used to grant 'owner' (firestore.rules rejects that for anyone but
  /// the real owner self-joining or a site admin — see the `members/
  /// {memberId}` create rule's doc comment).
  Future<void> addMember(
    String groupId,
    String uid, {
    String? displayName,
    String? photoURL,
  }) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final now = DateTime.now();
    final batch = _db.batch();
    batch.set(
      _members(groupId).doc(uid),
      CommunityGroupMemberModel(
        uid: uid,
        displayName: displayName,
        photoURL: photoURL,
        joinedAt: now,
      ).toFirestore(),
    );
    batch.update(_groups.doc(groupId), {
      'member_count': FieldValue.increment(1),
      'last_activity_at': Timestamp.fromDate(now),
    });
    batch.set(
      _db.collection('users').doc(uid),
      {
        'group_memberships': FieldValue.arrayUnion([groupId])
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    debugPrint('[CommunityGroupService] $callerUid added $uid to $groupId');
  }

  /// Self-join. Only succeeds server-side when the group's `join_policy` is
  /// 'open' (firestore.rules) — for 'request'/'invite' groups use
  /// [requestToJoin] or a redeemed invite code instead.
  Future<void> joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final now = DateTime.now();

    final batch = _db.batch();
    batch.set(
      _members(groupId).doc(user.uid),
      CommunityGroupMemberModel(
        uid: user.uid,
        displayName: user.displayName,
        photoURL: user.photoURL,
        joinedAt: now,
      ).toFirestore(),
    );
    batch.update(_groups.doc(groupId), {
      'member_count': FieldValue.increment(1),
      'last_activity_at': Timestamp.fromDate(now),
    });
    batch.set(
      _db.collection('users').doc(user.uid),
      {
        'group_memberships': FieldValue.arrayUnion([groupId])
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    unawaited(AnalyticsService()
        .logEvent(name: 'group_joined', parameters: {'group_id': groupId}));
    debugPrint('[CommunityGroupService] ${user.uid} joined $groupId');
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final batch = _db.batch();
    batch.delete(_members(groupId).doc(uid));
    batch.update(
        _groups.doc(groupId), {'member_count': FieldValue.increment(-1)});
    batch.set(
      _db.collection('users').doc(uid),
      {
        'group_memberships': FieldValue.arrayRemove([groupId])
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    debugPrint('[CommunityGroupService] $uid left $groupId');
  }

  /// One-shot check: is [uid] this group's owner or a group-level 'admin'?
  /// Faz 2 §2.6 — backs moderator-only UI (message takedown in a group chat)
  /// where pulling the WHOLE member list just to find one row would be
  /// wasteful; a direct two-doc get is O(1) instead of O(member count).
  Future<bool> isOwnerOrGroupAdmin(String groupId, String uid) async {
    final groupDoc = await _groups.doc(groupId).get();
    if (!groupDoc.exists) return false;
    if (groupDoc.data()?['owner_uid'] == uid) return true;
    final memberDoc = await _members(groupId).doc(uid).get();
    return memberDoc.data()?['role'] == 'admin';
  }

  Stream<List<CommunityGroupMemberModel>> getMembersStream(String groupId) {
    return _members(groupId)
        .orderBy('joined_at', descending: false)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map(CommunityGroupMemberModel.fromFirestore).toList());
  }

  /// Faz 5 §5.3 — this week's contribution leaderboard (top 10, already
  /// ranked). This is EXACTLY the "denormalized public summary" the
  /// `weekly_contributions` collection's own firestore.rules comment
  /// promised — never a widened read on that raw, fully-internal counter.
  /// Single-doc read (the whole ranked list lives in one `entries` array),
  /// recomputed every 15 min by `computeGroupContributionLeaderboards`
  /// (`functions/engagement_credit.js`) for the CURRENT (still-accumulating)
  /// week — this is a live "who's winning right now" display, not the
  /// after-the-fact award (that's `awardWeeklyGroupTop3`, unrelated to what
  /// this stream reads). Returns an empty list (not an error) before the
  /// first sweep has produced anything for a brand-new/quiet group this
  /// week — the UI's own empty state handles that, not this method.
  Stream<List<GroupContributionEntry>> getWeeklyContributionLeaderboardStream(
      String groupId) {
    final weekKey = LocalWeek.key(DateTime.now());
    return _groups
        .doc(groupId)
        .collection('weekly_leaderboard')
        .doc(weekKey)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final rawEntries = data?['entries'] as List<dynamic>?;
      if (rawEntries == null) return const <GroupContributionEntry>[];
      return rawEntries
          .whereType<Map<String, dynamic>>()
          .map(GroupContributionEntry.fromMap)
          .toList();
    });
  }

  /// Touches `last_activity_at` (called when a member posts to the group).
  Future<void> touchActivity(String groupId) async {
    try {
      await _groups
          .doc(groupId)
          .update({'last_activity_at': Timestamp.fromDate(DateTime.now())});
    } catch (e) {
      debugPrint('[CommunityGroupService] touchActivity error: $e');
    }
  }

  /// Promotes/demotes a member's role. Owner (or site admin) only —
  /// firestore.rules' `members/{memberId}` update rule allows a group-level
  /// 'admin' to touch ONLY `muted_until`/`banned` (day-to-day moderation);
  /// changing `role` itself — the structural, rarer action — stays scoped to
  /// the group's real owner. This is how "salonun koçları/personeli admin'e
  /// yükseltilebilir" (Faz 2 §2.3) is meant to work: the OWNER promotes
  /// staff, not another admin. `role` remains one of the 4 schema values;
  /// nothing here ever assigns 'moderator' automatically — a human owner
  /// must choose to.
  Future<void> setMemberRole(
      String groupId, String uid, GroupMemberRole role) async {
    await _members(groupId).doc(uid).update({'role': role.value});
  }

  /// Kick — removes membership immediately (rejoin is possible afterward,
  /// subject to the group's `join_policy`, exactly like a normal leave/join).
  /// Owner or a group-level 'admin' may call this.
  Future<void> kickMember(String groupId, String uid, {String? reason}) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final batch = _db.batch();
    batch.delete(_members(groupId).doc(uid));
    batch.update(
        _groups.doc(groupId), {'member_count': FieldValue.increment(-1)});
    batch.set(
      _moderation(groupId).doc(),
      GroupModerationActionModel(
        id: '',
        targetUid: uid,
        action: GroupModerationAction.kick,
        reason: reason,
        issuedBy: callerUid,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    await batch.commit();
    debugPrint('[CommunityGroupService] $callerUid kicked $uid from $groupId');
  }

  /// Ban — keeps the (now `banned: true`) member doc rather than deleting
  /// it, so the uid can never self-recreate it via the open-join path (see
  /// `CommunityGroupMemberModel.banned` doc comment), and decrements
  /// `member_count` to reflect the member leaving the active headcount.
  /// Reversible via [unbanMember] — because the doc was never deleted (and
  /// [isMember]/[isMemberStream] key off doc EXISTENCE, not the `banned`
  /// field), unbanning restores full active membership immediately with no
  /// separate rejoin step, so its `member_count` increment mirrors this one.
  Future<void> banMember(String groupId, String uid, {String? reason}) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final batch = _db.batch();
    batch.update(_members(groupId).doc(uid), {
      'banned': true,
      'role': GroupMemberRole.member.value,
    });
    batch.update(
        _groups.doc(groupId), {'member_count': FieldValue.increment(-1)});
    batch.set(
      _moderation(groupId).doc(),
      GroupModerationActionModel(
        id: '',
        targetUid: uid,
        action: GroupModerationAction.ban,
        reason: reason,
        issuedBy: callerUid,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    await batch.commit();
    debugPrint('[CommunityGroupService] $callerUid banned $uid in $groupId');
  }

  Future<void> unbanMember(String groupId, String uid) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final batch = _db.batch();
    batch.update(_members(groupId).doc(uid), {'banned': false});
    batch.update(
        _groups.doc(groupId), {'member_count': FieldValue.increment(1)});
    batch.set(
      _moderation(groupId).doc(),
      GroupModerationActionModel(
        id: '',
        targetUid: uid,
        action: GroupModerationAction.unban,
        issuedBy: callerUid,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    await batch.commit();
  }

  /// Mute — [duration] from now; the member keeps read access and can still
  /// react, just can't post (`canPostInGroup()` in firestore.rules).
  Future<void> muteMember(
    String groupId,
    String uid, {
    required Duration duration,
    String? reason,
  }) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final until = DateTime.now().add(duration);
    final batch = _db.batch();
    batch.update(_members(groupId).doc(uid), {
      'muted_until': Timestamp.fromDate(until),
    });
    batch.set(
      _moderation(groupId).doc(),
      GroupModerationActionModel(
        id: '',
        targetUid: uid,
        action: GroupModerationAction.mute,
        reason: reason,
        durationMinutes: duration.inMinutes,
        issuedBy: callerUid,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    await batch.commit();
  }

  Future<void> unmuteMember(String groupId, String uid) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final batch = _db.batch();
    batch.update(_members(groupId).doc(uid), {
      'muted_until': FieldValue.delete(),
    });
    batch.set(
      _moderation(groupId).doc(),
      GroupModerationActionModel(
        id: '',
        targetUid: uid,
        action: GroupModerationAction.unmute,
        issuedBy: callerUid,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );
    await batch.commit();
  }

  /// Owner/admin moderation log view, most recent first.
  Stream<List<GroupModerationActionModel>> getModerationLogStream(
      String groupId) {
    return _moderation(groupId)
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map(GroupModerationActionModel.fromFirestore).toList());
  }

  /// Faz 2 §2.6 — "my moderation history" across EVERY group at once (a
  /// collection-group scan, unlike [getModerationLogStream] which is scoped
  /// to one group's admin view). Backs the appeal-filing screen: a member
  /// needs to see every mute/kick/ban ever issued against them, regardless
  /// of which group it happened in. No rules change was needed — the
  /// `moderation/{autoId}` read rule already allows `target_uid ==
  /// request.auth.uid` for exactly this "transparency" reason, and a
  /// collection-group query is evaluated per-document against that same
  /// rule. `groupId` is read off each doc's own reference (`moderation` docs
  /// carry no denormalized group id field of their own) since the model
  /// alone can't say which group it came from.
  Stream<List<({GroupModerationActionModel action, String groupId})>>
      getMyModerationHistoryStream(String uid) {
    return _db
        .collectionGroup('moderation')
        .where('target_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => (
                  action: GroupModerationActionModel.fromFirestore(d),
                  groupId: d.reference.parent.parent!.id,
                ))
            .toList());
  }

  // ── Join requests (join_policy == 'request') ───────────────────────────────

  /// Files (or re-files) a join request. Only meaningful — and only
  /// server-accepted — when the group's `join_policy` is 'request'.
  Future<void> requestToJoin(String groupId, {String? message}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await _joinRequests(groupId).doc(user.uid).set(
          GroupJoinRequestModel(
            uid: user.uid,
            displayName: user.displayName,
            photoURL: user.photoURL,
            message: message,
            requestedAt: DateTime.now(),
          ).toFirestore(),
        );
  }

  Future<void> withdrawJoinRequest(String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _joinRequests(groupId).doc(uid).delete();
  }

  /// Owner/admin queue view — pending requests only, oldest first.
  Stream<List<GroupJoinRequestModel>> getPendingJoinRequestsStream(
      String groupId) {
    return _joinRequests(groupId)
        .where('status', isEqualTo: GroupJoinRequestStatus.pending.value)
        .orderBy('requested_at', descending: false)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(GroupJoinRequestModel.fromFirestore).toList());
  }

  Future<void> approveJoinRequest(String groupId, String uid) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    final now = DateTime.now();
    final reqDoc = await _joinRequests(groupId).doc(uid).get();
    final data = reqDoc.data();

    final batch = _db.batch();
    batch.set(
      _members(groupId).doc(uid),
      CommunityGroupMemberModel(
        uid: uid,
        displayName: data?['display_name'] as String?,
        photoURL: data?['photo_url'] as String?,
        joinedAt: now,
      ).toFirestore(),
    );
    batch.update(_groups.doc(groupId), {
      'member_count': FieldValue.increment(1),
      'last_activity_at': Timestamp.fromDate(now),
    });
    batch.update(_joinRequests(groupId).doc(uid), {
      'status': GroupJoinRequestStatus.approved.value,
      'responded_at': FieldValue.serverTimestamp(),
      'responded_by': callerUid,
    });
    batch.set(
      _db.collection('users').doc(uid),
      {
        'group_memberships': FieldValue.arrayUnion([groupId])
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> declineJoinRequest(String groupId, String uid) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');
    await _joinRequests(groupId).doc(uid).update({
      'status': GroupJoinRequestStatus.declined.value,
      'responded_at': FieldValue.serverTimestamp(),
      'responded_by': callerUid,
    });
  }

  // ── Invite codes ─────────────────────────────────────────────────────────
  // The code itself deliberately never lives on the public community_groups
  // doc (any authenticated user can read that whole doc — firestore.rules
  // can't hide individual fields, same lesson as the gym QR token / user PII
  // fixes elsewhere in this codebase). It lives in an owner/admin-only
  // `secrets/invite` doc, plus a fully server-only `group_invites/{code}`
  // top-level doc (doc id == code, mirrors `referrals/{code}`'s O(1)
  // doc-id lookup) that `functions/groups.js: redeemGroupInvite` uses as the
  // reverse (code -> group_id) index.

  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final Random _codeRandom = Random.secure();

  String _generateCode({int length = 8}) {
    return List.generate(
      length,
      (_) => _codeAlphabet[_codeRandom.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// Generates (or regenerates) this group's invite code. Owner/admin only —
  /// enforced by firestore.rules on both `secrets/invite` and
  /// `group_invites/{code}`. Regenerating deactivates the previous code
  /// (`is_active: false`) rather than deleting it, mirroring
  /// `voidReferralCode`'s pattern.
  Future<String> generateInviteCode(String groupId) async {
    final callerUid = _uid;
    if (callerUid == null) throw Exception('Not authenticated');

    final secretRef = _inviteSecret(groupId);
    final existing = await secretRef.get();
    final previousCode = existing.data()?['code'] as String?;

    final code = _generateCode();
    final batch = _db.batch();
    if (previousCode != null && previousCode.isNotEmpty) {
      batch.update(
        _db.collection('group_invites').doc(previousCode),
        {'is_active': false},
      );
    }
    batch.set(secretRef, {
      'code': code,
      'created_at': FieldValue.serverTimestamp(),
      'created_by': callerUid,
    });
    batch.set(_db.collection('group_invites').doc(code), {
      'group_id': groupId,
      'is_active': true,
      'created_by': callerUid,
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.update(_groups.doc(groupId), {'invite_enabled': true});
    await batch.commit();
    debugPrint('[CommunityGroupService] generated invite code for $groupId');
    return code;
  }

  Future<void> disableInvite(String groupId) async {
    final secretRef = _inviteSecret(groupId);
    final existing = await secretRef.get();
    final code = existing.data()?['code'] as String?;

    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {'invite_enabled': false});
    if (code != null && code.isNotEmpty) {
      batch.update(
          _db.collection('group_invites').doc(code), {'is_active': false});
    }
    await batch.commit();
  }

  /// Owner/admin fetch of their own current code (to display/copy/print) —
  /// not a validation call, just a read of the private doc.
  Future<String?> getInviteCode(String groupId) async {
    final doc = await _inviteSecret(groupId).get();
    return doc.data()?['code'] as String?;
  }

  /// Redeems an invite code — validates it and adds the caller as a member,
  /// entirely server-side (`functions/groups.js: redeemGroupInvite`). Must
  /// go through the callable rather than a direct client write: the code
  /// lives in a fully closed `group_invites/{code}` doc (`allow read: if
  /// false` — see that collection's firestore.rules comment), so there is
  /// no client-readable path to validate it any other way. Returns the
  /// joined group's id + name (for a "you joined {name}" confirmation) —
  /// throws `FirebaseFunctionsException` with `code: 'failed-precondition'`
  /// and a `message` of `code_not_found`/`code_inactive`/`invite_disabled`/
  /// `banned`/`already_member` on the expected failure paths.
  Future<({String groupId, String groupName})> redeemInviteCode(
      String code) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemGroupInvite')
          .call({'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return (
        groupId: data['groupId'] as String? ?? '',
        groupName: data['groupName'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint(
          'CommunityGroupService.redeemInviteCode error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'CommunityGroupService.redeemInviteCode'));
      rethrow;
    } catch (e, st) {
      debugPrint('CommunityGroupService.redeemInviteCode error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'CommunityGroupService.redeemInviteCode'));
      rethrow;
    }
  }

  /// Cold-start content for the discovery carousels (Faz 2 §2.5) — a
  /// handful of official groups per major Turkish city, so
  /// [getTopActiveGroups]/[getActiveGroupsInCity] aren't empty before any
  /// organic public group exists. Admin-only, idempotent
  /// (`functions/groups.js: seedOfficialGroups` skips any city/template
  /// combination that already has a doc) — owned by the CALLING admin's own
  /// uid, since there is no synthetic "system" account anywhere in this
  /// schema. **Not wired to any button in this pass** — invoke once,
  /// manually, signed in as an admin (see docs/SERVICES.md for the exact
  /// note); building a dedicated admin-tools UI for a one-time operation
  /// was judged out of scope for this change.
  Future<({int created, int skipped})> seedOfficialGroups() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('seedOfficialGroups')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      created: (data['created'] as num?)?.toInt() ?? 0,
      skipped: (data['skipped'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Member CSV export (Faz 5 §5.4 — Entitlements.exportData) ───────────────
  // "Premium grup admin araçları" was undefined scope in the plan; the
  // moderation tools (kick/ban/mute/unmute/setMemberRole, all above) already
  // exist for free, unconditionally, for every owner/admin — gating THOSE
  // would be a regression, not a new premium promise. This is the one
  // genuinely NEW, small capability found worth building: a group owner/
  // admin's member list as CSV, mirroring `GymAnalyticsService.exportCsv`'s
  // exact shape/pattern (same column style, same capped-read + debug-log
  // discipline) for a DIFFERENT, previously-nonexistent surface — nothing
  // free owners/admins already had is touched.

  static const memberCsvColumns = [
    'uid',
    'display_name',
    'role',
    'joined_at',
    'status',
  ];

  /// Builds a CSV of every member of [groupId] — caller (the screen) is
  /// responsible for the `Entitlements.exportData` paywall check and for
  /// actually sharing/saving the returned string, exactly like
  /// `GymAnalyticsService.exportCsv`'s own caller does. Read is capped at
  /// [limit] (documented, logged if hit) rather than unbounded — R1.
  Future<String> exportMembersCsv(String groupId, {int limit = 5000}) async {
    debugPrint('[CommunityGroupService] exportMembersCsv start: $groupId');
    final snap = await _members(groupId)
        .orderBy('joined_at', descending: false)
        .limit(limit)
        .get();
    final members =
        snap.docs.map(CommunityGroupMemberModel.fromFirestore).toList();
    if (members.length >= limit) {
      debugPrint(
          '[CommunityGroupService] exportMembersCsv capped at $limit rows for $groupId');
    }

    final buf = StringBuffer();
    buf.writeln(memberCsvColumns.join(','));
    for (final m in members) {
      final name = (m.displayName ?? '').replaceAll('"', '""');
      final status = m.banned
          ? 'banned'
          : (m.mutedUntil != null && m.mutedUntil!.isAfter(DateTime.now()))
              ? 'muted'
              : 'active';
      buf.writeln([
        m.uid,
        '"$name"',
        m.role.value,
        m.joinedAt.toIso8601String(),
        status,
      ].join(','));
    }
    debugPrint(
        '[CommunityGroupService] exportMembersCsv done: ${members.length} rows');
    return buf.toString();
  }

  // ── Pinned message (mirrors the group's chat, Faz 2 §2.3) ─────────────────
  // The group's own message stream lives at `chats/{chat_id}/messages` (see
  // class doc comment) — send/read/react/edit all go through the existing
  // `ChatService` with `group.chatId`. `pinned_message_id` is tracked here,
  // on the community_groups doc itself (per the plan's schema), rather than
  // via `ChatService.pinMessage` (which would set the CHAT doc's own
  // camelCase `pinnedMessageId` instead) — one canonical field for a group's
  // pin, not two out-of-sync copies.

  /// Pins a message — owner/site-admin only (the underlying write goes
  /// through the same owner/admin-gated `community_groups/{id}` update rule
  /// as [updateGroupSettings]; a group-level 'admin' does not get this in
  /// this pass — see that method's doc comment).
  Future<void> pinGroupMessage(String groupId, String messageId) async {
    await _groups.doc(groupId).update({'pinned_message_id': messageId});
  }

  Future<void> unpinGroupMessage(String groupId) async {
    await _groups
        .doc(groupId)
        .update({'pinned_message_id': FieldValue.delete()});
  }
}
