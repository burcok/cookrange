import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/community_group_model.dart';
import 'analytics_service.dart';

/// CRUD + membership for location-based community groups.
/// Collections: `community_groups/{id}` + `.../members/{uid}`.
/// "My groups" are mirrored on `users/{uid}.group_memberships` (array).
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

  // ── Create / read ──────────────────────────────────────────────────────────

  Future<CommunityGroupModel> createGroup({
    required String name,
    String? description,
    String? city,
    String? district,
    List<String> tags = const [],
    bool isPublic = true,
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
      isPublic: isPublic,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    );

    final batch = _db.batch();
    batch.set(doc, group.toFirestore());
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
    return _groups.doc(groupId).snapshots().map((d) =>
        d.exists ? CommunityGroupModel.fromFirestore(d) : null);
  }

  /// Groups the user belongs to (read off their own doc, then fetched).
  Stream<List<CommunityGroupModel>> getMyGroupsStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().asyncMap((userDoc) async {
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

  // ── Membership ───────────────────────────────────────────────────────────

  Future<bool> isMember(String groupId, String uid) async {
    final doc = await _members(groupId).doc(uid).get();
    return doc.exists;
  }

  Stream<bool> isMemberStream(String groupId, String uid) {
    return _members(groupId).doc(uid).snapshots().map((d) => d.exists);
  }

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
    batch.update(_groups.doc(groupId),
        {'member_count': FieldValue.increment(-1)});
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

  Stream<List<CommunityGroupMemberModel>> getMembersStream(String groupId) {
    return _members(groupId)
        .orderBy('joined_at', descending: false)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map(CommunityGroupMemberModel.fromFirestore).toList());
  }

  /// Touches `last_activity_at` (called when a member posts to the group).
  Future<void> touchActivity(String groupId) async {
    try {
      await _groups.doc(groupId).update(
          {'last_activity_at': Timestamp.fromDate(DateTime.now())});
    } catch (e) {
      debugPrint('[CommunityGroupService] touchActivity error: $e');
    }
  }
}
