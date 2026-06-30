import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gym_model.dart';
import '../models/gym_member_model.dart';
import '../models/checkin_model.dart';
import '../models/user_model.dart';
import '../data/test_data_library.dart';
import 'analytics_service.dart';
import 'firestore_service.dart';
import 'test_mode_service.dart';

class GymService {
  static final GymService _instance = GymService._internal();
  factory GymService() => _instance;
  GymService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _gyms =>
      _db.collection('gyms');

  CollectionReference<Map<String, dynamic>> _members(String gymId) =>
      _gyms.doc(gymId).collection('members');

  CollectionReference<Map<String, dynamic>> _checkins(String gymId) =>
      _gyms.doc(gymId).collection('checkins');

  // ── Create / Update ──────────────────────────────────────────────────────────

  /// Creates a new gym for the current user and promotes their role to gymOwner.
  Future<GymModel> createGym({
    required String name,
    String? description,
    String? address,
    String? city,
    String? country,
    bool isPublic = true,
    List<String> tags = const [],
    double? latitude,
    double? longitude,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final doc = _gyms.doc();

    final gym = GymModel(
      id: doc.id,
      ownerUid: uid,
      name: name,
      description: description,
      address: address,
      city: city,
      country: country,
      isPublic: isPublic,
      memberCount: 1,
      subscriptionTier: GymSubscriptionTier.free,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      latitude: latitude,
      longitude: longitude,
    );

    final batch = _db.batch();
    // Write gym document
    batch.set(doc, gym.toFirestore());
    // Add owner as first member
    batch.set(
      _members(doc.id).doc(uid),
      GymMemberModel(
        uid: uid,
        joinedAt: now,
        tier: GymMemberTier.premium,
      ).toFirestore(),
    );
    await batch.commit();

    // Promote user role to gym_owner (additive — preserves existing roles)
    await FirestoreService().addUserRole(uid, UserRole.gymOwner);

    debugPrint('[GymService] Created gym ${doc.id} for owner $uid');
    return gym;
  }

  Future<void> updateGym(
    String gymId,
    Map<String, dynamic> data,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _gyms.doc(gymId).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
    debugPrint('[GymService] Updated gym $gymId');
  }

  Future<void> updateGymLogo(String gymId, String logoUrl) async {
    await updateGym(gymId, {'logo_url': logoUrl});
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  Future<GymModel?> getGym(String gymId) async {
    final doc = await _gyms.doc(gymId).get();
    if (!doc.exists) return null;
    return GymModel.fromFirestore(doc);
  }

  Stream<GymModel> getGymStream(String gymId) {
    return _gyms.doc(gymId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Gym not found');
      return GymModel.fromFirestore(doc);
    });
  }

  /// Returns the gym owned by [uid], or null if none exists.
  Future<GymModel?> getOwnerGym(String uid) async {
    final q = await _gyms
        .where('owner_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return GymModel.fromFirestore(q.docs.first);
  }

  Stream<GymModel?> getOwnerGymStream(String uid) {
    return _gyms
        .where('owner_uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return null;
      return GymModel.fromFirestore(s.docs.first);
    });
  }

  /// Streams the gyms the given user has JOINED as a member (not owned).
  /// Reads the membership list off the user's own doc, then fetches those gyms.
  Stream<List<GymModel>> getMemberGymsStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().asyncMap((userDoc) async {
      final ids = List<String>.from(
          (userDoc.data()?['gym_memberships'] as List?) ?? const []);
      if (ids.isEmpty) return <GymModel>[];
      // Firestore whereIn supports up to 30 ids; chunk if needed.
      final List<GymModel> gyms = [];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
        final snap = await _gyms
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        gyms.addAll(snap.docs.map(GymModel.fromFirestore));
      }
      debugPrint('[GymService] Loaded ${gyms.length} member gyms for $uid');
      return gyms;
    });
  }

  /// Paginated search across public gyms with optional city/district/tag filters.
  ///
  /// When [city] is provided a Firestore equality filter is applied (exact match).
  /// [district] is only applied when [city] is also set. [tags] uses client-side
  /// intersection since Firestore array-contains only accepts a single value.
  Future<List<GymModel>> searchGyms(
    String query, {
    String? city,
    String? district,
    List<String>? tags,
    String sortBy = 'member_count', // 'name' | 'member_count' | 'created_at' | 'avg_rating'
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    if (TestModeService().isActive) {
      var results = TestDataLibrary.gyms();
      if (query.isNotEmpty) {
        final lower = query.toLowerCase();
        results = results
            .where((g) =>
                g.name.toLowerCase().contains(lower) ||
                (g.city?.toLowerCase().contains(lower) ?? false))
            .toList();
      }
      if (city != null && city.isNotEmpty) {
        results = results.where((g) => g.city == city).toList();
      }
      if (tags != null && tags.isNotEmpty) {
        results = results
            .where((g) => tags.any((t) => g.tags.contains(t)))
            .toList();
      }
      if (sortBy == 'avg_rating') {
        results.sort((a, b) => b.memberCount.compareTo(a.memberCount));
      } else {
        results.sort((a, b) => b.memberCount.compareTo(a.memberCount));
      }
      return results.take(limit).toList();
    }

    Query<Map<String, dynamic>> q =
        _gyms.where('is_public', isEqualTo: true);

    if (city != null && city.isNotEmpty) {
      q = q.where('city', isEqualTo: city);
    }
    if (district != null && district.isNotEmpty) {
      q = q.where('district', isEqualTo: district);
    }

    final firestoreSortField = sortBy == 'avg_rating' ? 'avg_rating' : sortBy;
    final orderDesc = firestoreSortField == 'member_count' ||
        firestoreSortField == 'created_at' ||
        firestoreSortField == 'avg_rating';
    q = q.orderBy(firestoreSortField, descending: orderDesc).limit(limit);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    var all = snap.docs.map(GymModel.fromFirestore).toList();

    // Client-side text filter
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      all = all
          .where((g) =>
              g.name.toLowerCase().contains(lower) ||
              (g.city?.toLowerCase().contains(lower) ?? false) ||
              (g.district?.toLowerCase().contains(lower) ?? false))
          .toList();
    }

    // Client-side tag intersection
    if (tags != null && tags.isNotEmpty) {
      all = all
          .where((g) => tags.any((t) => g.tags.contains(t)))
          .toList();
    }

    return all;
  }

  // ── Membership ───────────────────────────────────────────────────────────────

  Future<void> joinGym(String gymId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final batch = _db.batch();

    batch.set(
      _members(gymId).doc(uid),
      GymMemberModel(
        uid: uid,
        joinedAt: now,
        tier: GymMemberTier.standard,
      ).toFirestore(),
    );
    // Increment member count atomically
    batch.update(
        _gyms.doc(gymId), {'member_count': FieldValue.increment(1)});
    // Track membership on the user's own doc (owner-writable, no index needed)
    batch.set(
      _db.collection('users').doc(uid),
      {'gym_memberships': FieldValue.arrayUnion([gymId])},
      SetOptions(merge: true),
    );

    await batch.commit();
    unawaited(AnalyticsService().logEvent(name: 'gym_joined', parameters: {'gym_id': gymId}));
    debugPrint('[GymService] User $uid joined gym $gymId');
  }

  Future<void> leaveGym(String gymId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final batch = _db.batch();
    batch.delete(_members(gymId).doc(uid));
    batch.update(
        _gyms.doc(gymId), {'member_count': FieldValue.increment(-1)});
    // Remove membership from the user's own doc
    batch.set(
      _db.collection('users').doc(uid),
      {'gym_memberships': FieldValue.arrayRemove([gymId])},
      SetOptions(merge: true),
    );
    await batch.commit();
    debugPrint('[GymService] User $uid left gym $gymId');
  }

  Future<void> removeMember(String gymId, String memberUid) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final gym = await getGym(gymId);
    if (gym == null || gym.ownerUid != uid) {
      throw Exception('Only the gym owner can remove members');
    }

    final batch = _db.batch();
    batch.delete(_members(gymId).doc(memberUid));
    batch.update(
        _gyms.doc(gymId), {'member_count': FieldValue.increment(-1)});
    await batch.commit();
    debugPrint('[GymService] Owner removed member $memberUid from gym $gymId');
  }

  Future<bool> isMember(String gymId, String uid) async {
    final doc = await _members(gymId).doc(uid).get();
    return doc.exists;
  }

  /// Paginated member list (owner view).
  Future<({List<GymMemberModel> members, DocumentSnapshot? lastDoc})>
      getGymMembersPage(
    String gymId, {
    DocumentSnapshot? startAfter,
    int pageSize = 20,
  }) async {
    Query<Map<String, dynamic>> q = _members(gymId)
        .orderBy('joined_at', descending: false)
        .limit(pageSize);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final members =
        snap.docs.map(GymMemberModel.fromFirestore).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    return (members: members, lastDoc: lastDoc);
  }

  Stream<List<GymMemberModel>> getMembersStream(String gymId) {
    return _members(gymId)
        .orderBy('joined_at', descending: false)
        .snapshots()
        .map((s) =>
            s.docs.map(GymMemberModel.fromFirestore).toList());
  }

  // ── Haversine distance ────────────────────────────────────────────────────────

  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLng = (lng2 - lng1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // ── Check-in ─────────────────────────────────────────────────────────────────

  Future<void> checkIn(String gymId) async {
    await _recordCheckIn(gymId, CheckInMethod.manual);
  }

  Future<String> generateQRToken(String gymId) async {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final token =
        List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await _gyms.doc(gymId).update({
      'qr_token': token,
      'qr_token_expires_at': Timestamp.fromDate(expiresAt),
    });
    debugPrint(
        '[GymService] Generated QR token for gym $gymId (expires $expiresAt)');
    return token;
  }

  Future<void> validateQRCheckIn(String gymId, String token) async {
    final doc = await _gyms.doc(gymId).get();
    if (!doc.exists) throw Exception('Gym not found');
    final data = doc.data()!;
    final storedToken = data['qr_token'] as String?;
    final expiresAt = data['qr_token_expires_at'] is Timestamp
        ? (data['qr_token_expires_at'] as Timestamp).toDate()
        : null;

    if (storedToken != token ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now())) {
      throw Exception('Invalid or expired QR code');
    }
    await _recordCheckIn(gymId, CheckInMethod.qr);
  }

  Future<void> gpsCheckIn(
    String gymId,
    double gymLat,
    double gymLng,
    double userLat,
    double userLng,
    int radiusMeters,
  ) async {
    final distanceM =
        _haversineDistance(gymLat, gymLng, userLat, userLng);
    if (distanceM <= radiusMeters) {
      await _recordCheckIn(gymId, CheckInMethod.gps);
    } else {
      throw Exception(
          'Too far from gym (${distanceM.toStringAsFixed(0)} m)');
    }
  }

  Future<void> _recordCheckIn(String gymId, CheckInMethod method) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final user = FirebaseAuth.instance.currentUser!;

    final batch = _db.batch();
    final checkinDoc = _checkins(gymId).doc();
    batch.set(
        checkinDoc,
        CheckInModel(
          id: checkinDoc.id,
          uid: uid,
          displayName: user.displayName,
          photoURL: user.photoURL,
          timestamp: DateTime.now(),
          method: method,
        ).toFirestore());
    batch.update(_members(gymId).doc(uid), {
      'last_check_in': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    debugPrint(
        '[GymService] CheckIn recorded uid=$uid gym=$gymId method=${method.name}');
  }

  Stream<List<CheckInModel>> getRecentCheckInsStream(String gymId,
      {int limit = 20}) {
    return _checkins(gymId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(CheckInModel.fromFirestore).toList());
  }

  Stream<Map<int, int>> getWeeklyAttendanceStream(String gymId) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return _checkins(gymId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .snapshots()
        .map((s) {
      final counts = <int, int>{for (var i = 0; i < 7; i++) i: 0};
      for (final doc in s.docs) {
        final m = CheckInModel.fromFirestore(doc);
        final day = m.timestamp.weekday - 1;
        counts[day] = (counts[day] ?? 0) + 1;
      }
      return counts;
    });
  }
}
