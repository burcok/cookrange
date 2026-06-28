import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/coach_profile_model.dart';
import '../models/coach_client_model.dart';
import '../models/user_model.dart';
import 'analytics_service.dart';
import 'firestore_service.dart';

class CoachService {
  static final CoachService _i = CoachService._internal();
  factory CoachService() => _i;
  CoachService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _coaches =>
      _db.collection('coach_profiles');

  CollectionReference<Map<String, dynamic>> _clients(String coachUid) =>
      _coaches.doc(coachUid).collection('clients');

  // ─── Profile Setup ─────────────────────────────────────────────────────────

  Future<CoachProfileModel> setupCoachProfile({
    required String bio,
    required List<String> specializations,
    required List<String> certifications,
    required bool isAcceptingClients,
    String? vanityCode,
    double? hourlyRate,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('CoachService: no authenticated user');

    debugPrint('CoachService: setting up profile for ${user.uid}');

    if (vanityCode != null && vanityCode.isNotEmpty) {
      final refDoc = await _db.collection('referrals').doc(vanityCode).get();
      if (refDoc.exists) {
        final ownerUid = refDoc.data()?['owner_uid'] as String?;
        if (ownerUid != null && ownerUid != user.uid) {
          throw Exception('CoachService: vanity code already taken');
        }
      }
    }

    final existingDoc = await _coaches.doc(user.uid).get();
    final now = DateTime.now();
    final createdAt =
        existingDoc.exists && existingDoc.data()?['created_at'] != null
            ? (existingDoc.data()!['created_at'] as Timestamp).toDate()
            : now;

    final profile = CoachProfileModel(
      uid: user.uid,
      displayName: user.displayName ?? '',
      photoURL: user.photoURL,
      bio: bio,
      specializations: specializations,
      certifications: certifications,
      isAcceptingClients: isAcceptingClients,
      vanityCode:
          vanityCode != null && vanityCode.isNotEmpty ? vanityCode : null,
      clientCount: existingDoc.data()?['client_count'] as int? ?? 0,
      hourlyRate: hourlyRate,
      isPublic: isPublic,
      createdAt: createdAt,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(_coaches.doc(user.uid), profile.toFirestore());
    if (vanityCode != null && vanityCode.isNotEmpty) {
      batch.set(
        _db.collection('referrals').doc(vanityCode),
        {'owner_uid': user.uid, 'type': 'coach_vanity'},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    unawaited(
      FirestoreService()
          .addUserRole(user.uid, UserRole.coach)
          .catchError((e) {
        debugPrint('CoachService: failed to add coach role: $e');
      }),
    );

    debugPrint('CoachService: profile saved for ${user.uid}');
    return profile;
  }

  // ─── Profile Read ──────────────────────────────────────────────────────────

  Future<CoachProfileModel?> getCoachProfile(String uid) async {
    try {
      final doc = await _coaches.doc(uid).get();
      if (!doc.exists) return null;
      return CoachProfileModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('CoachService.getCoachProfile error: $e');
      return null;
    }
  }

  Stream<CoachProfileModel?> getCoachProfileStream(String uid) {
    return _coaches.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CoachProfileModel.fromFirestore(doc);
    });
  }

  // ─── Search ────────────────────────────────────────────────────────────────

  Future<List<CoachProfileModel>> searchCoaches(String query,
      {int limit = 20}) async {
    try {
      final snap = await _coaches
          .where('is_public', isEqualTo: true)
          .where('is_accepting_clients', isEqualTo: true)
          .orderBy('display_name')
          .limit(limit)
          .get();

      final lowerQuery = query.toLowerCase();
      return snap.docs
          .map(CoachProfileModel.fromFirestore)
          .where((c) =>
              query.isEmpty ||
              c.displayName.toLowerCase().contains(lowerQuery) ||
              c.bio?.toLowerCase().contains(lowerQuery) == true ||
              c.specializations
                  .any((s) => s.toLowerCase().contains(lowerQuery)))
          .toList();
    } catch (e) {
      debugPrint('CoachService.searchCoaches error: $e');
      return [];
    }
  }

  // ─── Coaching Requests (persistent state) ─────────────────────────────────

  /// Writes a pending coaching request from [clientUid] to [coachUid]'s
  /// `users/{coachUid}/coaching_requests/{clientUid}` subcollection.
  Future<void> requestCoaching(String coachUid, String clientUid) async {
    debugPrint('CoachService: $clientUid requesting coaching from $coachUid');
    await _db
        .collection('users')
        .doc(coachUid)
        .collection('coaching_requests')
        .doc(clientUid)
        .set({
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'clientUid': clientUid,
    });
    unawaited(AnalyticsService().logEvent(name: 'coach_requested', parameters: {'coach_uid': coachUid}));
    debugPrint('CoachService: coaching request written');
  }

  /// Streams the current request status ('pending' / 'accepted' / null) for
  /// the given client→coach pair.
  Stream<String?> getRequestStatusStream(String coachUid, String clientUid) {
    return _db
        .collection('users')
        .doc(coachUid)
        .collection('coaching_requests')
        .doc(clientUid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return doc.data()?['status'] as String?;
        });
  }

  // ─── Client Requests ───────────────────────────────────────────────────────

  Future<void> sendClientRequest(String coachUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('CoachService: no authenticated user');

    debugPrint('CoachService: ${user.uid} requesting coaching from $coachUid');

    final now = DateTime.now();
    final clientDoc = CoachClientModel(
      id: user.uid,
      coachUid: coachUid,
      clientUid: user.uid,
      clientDisplayName: user.displayName,
      clientPhotoURL: user.photoURL,
      status: CoachClientStatus.pending,
      linkedAt: now,
    );

    await _clients(coachUid).doc(user.uid).set(clientDoc.toFirestore());
    debugPrint('CoachService: client request sent');
  }

  Future<void> acceptClient(String clientUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('CoachService: no authenticated user');

    debugPrint('CoachService: ${user.uid} accepting client $clientUid');
    await _clients(user.uid).doc(clientUid).update({
      'status': CoachClientStatus.active.firestoreValue,
      'linked_at': Timestamp.fromDate(DateTime.now()),
    });

    await _coaches.doc(user.uid).update({
      'client_count': FieldValue.increment(1),
    });
    debugPrint('CoachService: client $clientUid accepted');
  }

  Future<void> rejectClient(String clientUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('CoachService: no authenticated user');

    debugPrint('CoachService: ${user.uid} rejecting client $clientUid');
    await _clients(user.uid).doc(clientUid).update({
      'status': CoachClientStatus.ended.firestoreValue,
      'ended_at': Timestamp.fromDate(DateTime.now()),
    });
    debugPrint('CoachService: client $clientUid rejected');
  }

  Future<void> endCoaching(String coachUid, String clientUid) async {
    debugPrint('CoachService: ending coaching $coachUid/$clientUid');
    await _clients(coachUid).doc(clientUid).update({
      'status': CoachClientStatus.ended.firestoreValue,
      'ended_at': Timestamp.fromDate(DateTime.now()),
    });

    try {
      await _coaches.doc(coachUid).update({
        'client_count': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('CoachService.endCoaching: failed to decrement count: $e');
    }
    debugPrint('CoachService: coaching ended');
  }

  // ─── Client Streams ────────────────────────────────────────────────────────

  Stream<List<CoachClientModel>> getClientsStream(String coachUid) {
    return _clients(coachUid).snapshots().map(
          (snap) => snap.docs.map(CoachClientModel.fromFirestore).toList(),
        );
  }

  Stream<List<CoachClientModel>> getPendingClientsStream(String coachUid) {
    return _clients(coachUid)
        .where('status', isEqualTo: CoachClientStatus.pending.firestoreValue)
        .snapshots()
        .map((snap) =>
            snap.docs.map(CoachClientModel.fromFirestore).toList());
  }

  Stream<List<CoachClientModel>> getActiveClientsStream(String coachUid) {
    return _clients(coachUid)
        .where('status', isEqualTo: CoachClientStatus.active.firestoreValue)
        .snapshots()
        .map((snap) =>
            snap.docs.map(CoachClientModel.fromFirestore).toList());
  }

  // ─── Cache Updates ─────────────────────────────────────────────────────────

  Future<void> updateClientCache(
    String coachUid,
    String clientUid, {
    int? streak,
    DateTime? lastLoggedAt,
  }) async {
    final updates = <String, dynamic>{};
    if (streak != null) updates['client_streak'] = streak;
    if (lastLoggedAt != null) {
      updates['last_logged_at'] = Timestamp.fromDate(lastLoggedAt);
    }
    if (updates.isEmpty) return;

    try {
      await _clients(coachUid).doc(clientUid).update(updates);
      debugPrint('CoachService: updated cache for $clientUid');
    } catch (e) {
      debugPrint('CoachService.updateClientCache error: $e');
    }
  }
}
