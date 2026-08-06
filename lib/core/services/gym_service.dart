import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gym_model.dart';
import '../models/gym_member_model.dart';
import '../models/checkin_model.dart';
import '../models/gym_qr_token_model.dart';
import '../data/test_data_library.dart';
import 'analytics_service.dart';
import 'test_mode_service.dart';

class GymService {
  static final GymService _instance = GymService._internal();
  factory GymService() => _instance;
  GymService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _gyms => _db.collection('gyms');

  CollectionReference<Map<String, dynamic>> _members(String gymId) =>
      _gyms.doc(gymId).collection('members');

  CollectionReference<Map<String, dynamic>> _checkins(String gymId) =>
      _gyms.doc(gymId).collection('checkins');

  // ── Create / Update ──────────────────────────────────────────────────────────
  //
  // Faz 0 §0.7: removed createGym() and updateGymLogo() — both had zero
  // callers anywhere in lib/. The real gym-creation path is
  // AdminService.approveGymApplication (constructs GymModel + writes
  // directly, since a gym only ever comes into existence via an approved
  // application, never a direct self-serve create), and the real logo path
  // is gym_setup_screen.dart's Edit Gym Profile calling updateGym directly
  // (below) with {'logo_url': url} after an upload.

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
    final q = await _gyms.where('owner_uid', isEqualTo: uid).limit(1).get();
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
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((userDoc) async {
      final ids = List<String>.from(
          (userDoc.data()?['gym_memberships'] as List?) ?? const []);
      if (ids.isEmpty) return <GymModel>[];
      // Firestore whereIn supports up to 30 ids; chunk if needed.
      final List<GymModel> gyms = [];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
        final snap =
            await _gyms.where(FieldPath.documentId, whereIn: chunk).get();
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
    String sortBy =
        'member_count', // 'name' | 'member_count' | 'created_at' | 'avg_rating'
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
        results =
            results.where((g) => tags.any((t) => g.tags.contains(t))).toList();
      }
      if (sortBy == 'avg_rating') {
        results.sort((a, b) => b.memberCount.compareTo(a.memberCount));
      } else {
        results.sort((a, b) => b.memberCount.compareTo(a.memberCount));
      }
      return results.take(limit).toList();
    }

    Query<Map<String, dynamic>> q = _gyms.where('is_public', isEqualTo: true);

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
      all = all.where((g) => tags.any((t) => g.tags.contains(t))).toList();
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
    batch.update(_gyms.doc(gymId), {'member_count': FieldValue.increment(1)});
    // Track membership on the user's own doc (owner-writable, no index needed)
    batch.set(
      _db.collection('users').doc(uid),
      {
        'gym_memberships': FieldValue.arrayUnion([gymId])
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    unawaited(AnalyticsService()
        .logEvent(name: 'gym_joined', parameters: {'gym_id': gymId}));
    debugPrint('[GymService] User $uid joined gym $gymId');
  }

  Future<void> leaveGym(String gymId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final batch = _db.batch();
    batch.delete(_members(gymId).doc(uid));
    batch.update(_gyms.doc(gymId), {'member_count': FieldValue.increment(-1)});
    // Remove membership from the user's own doc
    batch.set(
      _db.collection('users').doc(uid),
      {
        'gym_memberships': FieldValue.arrayRemove([gymId])
      },
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
    batch.update(_gyms.doc(gymId), {'member_count': FieldValue.increment(-1)});
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
    Query<Map<String, dynamic>> q =
        _members(gymId).orderBy('joined_at', descending: false).limit(pageSize);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final members = snap.docs.map(GymMemberModel.fromFirestore).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    return (members: members, lastDoc: lastDoc);
  }

  Stream<List<GymMemberModel>> getMembersStream(String gymId,
      {int limit = 200}) {
    // Capped: avoid re-reading an entire (potentially huge) member collection on
    // every change. Paginate with startAfter for gyms exceeding the cap.
    return _members(gymId)
        .orderBy('joined_at', descending: false)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(GymMemberModel.fromFirestore).toList());
  }

  // ── Check-in ─────────────────────────────────────────────────────────────────
  //
  // Faz 0 §0.7: removed checkIn() (the CheckInMethod.manual entry point) —
  // zero callers anywhere in lib/, no UI ever offered a manual check-in
  // button. CheckInMethod.manual itself is left in place (checkin_model.dart)
  // since firestore.rules' checkins-create allowlist still names it and a
  // future front-desk/admin flow may want it — only the unreachable client
  // method is removed.

  /// Faz 0 §0.7: writes to gyms/{gymId}/private/qr_token (owner/admin-read-
  /// only), not the public gym doc — see GymQrToken's doc comment. Only the
  /// owner/admin can call this (firestore.rules), matching who could
  /// previously update() the public doc's qr_token field.
  Future<String> generateQRToken(String gymId) async {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final token =
        List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await _gyms.doc(gymId).collection('private').doc('qr_token').set({
      'token': token,
      'expires_at': Timestamp.fromDate(expiresAt),
    });
    debugPrint(
        '[GymService] Generated QR token for gym $gymId (expires $expiresAt)');
    return token;
  }

  /// Live stream of the gym's current QR token — owner/admin only
  /// (firestore.rules gates the read; a non-owner call simply errors).
  /// Used by GymQrScreen to render/re-render the QR image and its
  /// expiry countdown.
  Stream<GymQrToken> getQrTokenStream(String gymId) {
    return _gyms
        .doc(gymId)
        .collection('private')
        .doc('qr_token')
        .snapshots()
        .map(GymQrToken.fromFirestore);
  }

  /// Faz 0 §0.7: validation moved server-side (functions/gym.js). The
  /// client used to read the token straight off the public gym doc and
  /// compare it itself — trivially bypassable (the doc was readable by any
  /// authenticated user, and nothing stopped a modified client from calling
  /// _recordCheckIn directly regardless of the comparison's outcome).
  /// validateGymCheckin now re-verifies membership + token + expiry with
  /// the Admin SDK and is the only writer of a QR-method check-in.
  Future<void> validateQRCheckIn(String gymId, String token) async {
    await FirebaseFunctions.instance
        .httpsCallable('validateGymCheckin')
        .call<Map<String, dynamic>>({'gymId': gymId, 'token': token});
  }

  /// SEC-08 fix: used to compute Haversine distance client-side and, if
  /// "close enough," write `checkins/*` directly — firestore.rules' create
  /// rule only ever checked uid/timestamp/method shape, so a modified
  /// client could self-report any distance (or skip the check entirely).
  /// Now calls `validateGymGpsCheckin` (functions/gym.js), which re-derives
  /// membership AND recomputes the distance server-side against the gym's
  /// own stored coordinates — the client's GPS reading is the only
  /// untrusted input now, exactly like `validateQRCheckIn`'s token is the
  /// only untrusted input for the QR path.
  Future<void> gpsCheckIn(
    String gymId,
    double userLat,
    double userLng,
  ) async {
    await FirebaseFunctions.instance
        .httpsCallable('validateGymGpsCheckin')
        .call<Map<String, dynamic>>({
      'gymId': gymId,
      'userLat': userLat,
      'userLng': userLng,
    });
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
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
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
