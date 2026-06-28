import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/coach_application_model.dart';
import 'analytics_service.dart';
import '../models/coach_profile_model.dart';
import '../models/gym_application_model.dart';
import '../models/gym_model.dart';

/// Admin-only service for reviewing and actioning coach/gym applications.
/// All write methods require the caller to be admin — enforced in Firestore rules.
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<CoachApplicationModel>> pendingCoachApplicationsStream() {
    return _db
        .collection('coach_applications')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt')
        .snapshots()
        .map((s) =>
            s.docs.map(CoachApplicationModel.fromFirestore).toList());
  }

  Stream<List<GymApplicationModel>> pendingGymApplicationsStream() {
    return _db
        .collection('gym_applications')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt')
        .snapshots()
        .map((s) =>
            s.docs.map(GymApplicationModel.fromFirestore).toList());
  }

  Stream<int> pendingCountStream() {
    return _db
        .collection('coach_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((coachSnap) async {
      final gymSnap = await _db
          .collection('gym_applications')
          .where('status', isEqualTo: 'pending')
          .get();
      return coachSnap.size + gymSnap.size;
    });
  }

  /// Total registered user count (approximate — reads first page of users stream).
  Stream<int> userCountStream() {
    return _db
        .collection('users')
        .snapshots()
        .map((s) => s.size);
  }

  /// Count of open/pending reports in the `reports` collection.
  Stream<int> openReportCountStream() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.size);
  }

  // ── Approve Coach ──────────────────────────────────────────────────────────

  Future<void> approveCoachApplication(
      CoachApplicationModel app) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: approving coach application ${app.id}');

    final batch = _db.batch();

    // 1. Update application status
    batch.update(_db.collection('coach_applications').doc(app.id), {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerUid': adminUid,
    });

    // 2. Create coach profile from application data
    final profile = CoachProfileModel(
      uid: app.applicantUid,
      displayName: app.displayName,
      bio: app.bio,
      specializations: app.specializations,
      certifications: app.evidenceLabels,
      isAcceptingClients: true,
      clientCount: 0,
      hourlyRate: app.hourlyRate.toDouble(),
      isPublic: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    batch.set(
        _db.collection('coach_profiles').doc(app.applicantUid),
        profile.toFirestore());

    // 3. Update user role
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_role': 'coach',
    });

    // 4. Send notification
    final notifRef = _db
        .collection('notifications')
        .doc(app.applicantUid)
        .collection('items')
        .doc();
    batch.set(notifRef, {
      'type': 'coachApplicationApproved',
      'actorUid': adminUid,
      'actorName': 'Cookrange Team',
      'actorPhotoUrl': null,
      'relatedId': app.id,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('AdminService: coach application ${app.id} approved');
  }

  // ── Approve Gym ─────────────────────────────────────────────────────────────

  Future<void> approveGymApplication(
      GymApplicationModel app) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: approving gym application ${app.id}');

    final gymId = 'gym_${app.applicantUid}';
    final batch = _db.batch();

    // 1. Update application status
    batch.update(_db.collection('gym_applications').doc(app.id), {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerUid': adminUid,
    });

    // 2. Create gym document
    final gymNow = DateTime.now();
    final gym = GymModel(
      id: gymId,
      ownerUid: app.applicantUid,
      name: app.gymName,
      description: app.description,
      address: app.address,
      city: app.city,
      country: 'Türkiye',
      logoUrl: app.photoUrls.isNotEmpty ? app.photoUrls.first : null,
      tags: app.tags,
      isPublic: true,
      memberCount: 0,
      subscriptionTier: GymSubscriptionTier.free,
      createdAt: gymNow,
      updatedAt: gymNow,
    );
    batch.set(_db.collection('gyms').doc(gymId), gym.toFirestore());

    // 3. Update user role
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_role': 'gym_owner',
    });

    // 4. Notification
    final notifRef = _db
        .collection('notifications')
        .doc(app.applicantUid)
        .collection('items')
        .doc();
    batch.set(notifRef, {
      'type': 'gymApplicationApproved',
      'actorUid': adminUid,
      'actorName': 'Cookrange Team',
      'actorPhotoUrl': null,
      'relatedId': app.id,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('AdminService: gym application ${app.id} approved');
  }

  // ── Reject Application ─────────────────────────────────────────────────────

  Future<void> rejectCoachApplication(
      CoachApplicationModel app, String notes) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: rejecting coach application ${app.id}');

    final batch = _db.batch();

    batch.update(_db.collection('coach_applications').doc(app.id), {
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerUid': adminUid,
      'reviewerNotes': notes,
    });

    final notifRef = _db
        .collection('notifications')
        .doc(app.applicantUid)
        .collection('items')
        .doc();
    batch.set(notifRef, {
      'type': 'coachApplicationRejected',
      'actorUid': adminUid,
      'actorName': 'Cookrange Team',
      'actorPhotoUrl': null,
      'relatedId': app.id,
      'metadata': {'notes': notes},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('AdminService: coach application ${app.id} rejected');
  }

  Future<void> rejectGymApplication(
      GymApplicationModel app, String notes) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    final batch = _db.batch();

    batch.update(_db.collection('gym_applications').doc(app.id), {
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerUid': adminUid,
      'reviewerNotes': notes,
    });

    final notifRef = _db
        .collection('notifications')
        .doc(app.applicantUid)
        .collection('items')
        .doc();
    batch.set(notifRef, {
      'type': 'gymApplicationRejected',
      'actorUid': adminUid,
      'actorName': 'Cookrange Team',
      'actorPhotoUrl': null,
      'relatedId': app.id,
      'metadata': {'notes': notes},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Request More Info ──────────────────────────────────────────────────────

  Future<void> requestMoreInfo(
      String applicationId, String collectionName, String message) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    await _db.collection(collectionName).doc(applicationId).update({
      'status': 'needs_more_info',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewerUid': adminUid,
      'reviewerNotes': message,
    });
  }

  // ── User Management ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    debugPrint('AdminService: searchUsers query="$query"');
    final end = query.isEmpty ? query : '\$query\uf8ff';
    final snap = await _db
        .collection('users')
        .where('display_name', isGreaterThanOrEqualTo: query)
        .where('display_name', isLessThan: end)
        .limit(20)
        .get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  Future<void> banUser(String uid, String reason) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: banUser uid=$uid reason="$reason"');

    final batch = _db.batch();
    batch.set(_db.collection('admin').doc('status').collection(uid).doc('flags'), {
      'is_banned': true,
      'ban_reason': reason,
      'banned_at': FieldValue.serverTimestamp(),
      'banned_by': adminUid,
    }, SetOptions(merge: true));
    batch.update(_db.collection('users').doc(uid), {'is_banned': true});
    await batch.commit();

    await logAuditAction(
      action: 'ban_user',
      targetUid: uid,
      metadata: {'reason': reason},
    );
    debugPrint('AdminService: banUser done uid=$uid');
  }

  Future<void> unbanUser(String uid) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: unbanUser uid=$uid');

    final batch = _db.batch();
    batch.set(_db.collection('admin').doc('status').collection(uid).doc('flags'), {
      'is_banned': false,
    }, SetOptions(merge: true));
    batch.update(_db.collection('users').doc(uid), {'is_banned': false});
    await batch.commit();

    await logAuditAction(action: 'unban_user', targetUid: uid);
    debugPrint('AdminService: unbanUser done uid=$uid');
  }

  Future<void> setUserRole(String uid, String role) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: setUserRole uid=$uid role=$role');

    await _db.collection('users').doc(uid).update({'user_role': role});
    await logAuditAction(
      action: 'set_user_role',
      targetUid: uid,
      metadata: {'role': role},
    );
  }

  // ── Application History ────────────────────────────────────────────────────

  Stream<List<CoachApplicationModel>> coachApplicationHistoryStream(
      {String? status}) {
    Query<Map<String, dynamic>> q = _db.collection('coach_applications');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q
        .orderBy('reviewedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(CoachApplicationModel.fromFirestore).toList());
  }

  Stream<List<GymApplicationModel>> gymApplicationHistoryStream(
      {String? status}) {
    Query<Map<String, dynamic>> q = _db.collection('gym_applications');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q
        .orderBy('reviewedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(GymApplicationModel.fromFirestore).toList());
  }

  // ── Audit Log ──────────────────────────────────────────────────────────────

  Future<void> logAuditAction({
    required String action,
    required String targetUid,
    Map<String, dynamic>? metadata,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    debugPrint('AdminService: audit action=$action targetUid=$targetUid');
    await _db.collection('admin_audit').add({
      'action': action,
      'targetUid': targetUid,
      'adminUid': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    });
    unawaited(AnalyticsService().logEvent(
      name: 'admin_action',
      parameters: {'action': action, 'target_uid': targetUid},
    ));
  }

  Stream<List<Map<String, dynamic>>> auditLogStream() {
    return _db
        .collection('admin_audit')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
