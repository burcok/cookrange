import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/coach_application_model.dart';
import '../models/privacy_request_model.dart';
import '../models/report_model.dart';
import 'analytics_service.dart';
import '../models/coach_profile_model.dart';
import '../models/gym_application_model.dart';
import '../models/gym_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

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

  // ── Reports ────────────────────────────────────────────────────────────────

  Stream<List<ReportModel>> pendingReportsStream() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReportModel.fromFirestore).toList());
  }

  Stream<List<ReportModel>> reviewedReportsStream() {
    return _db
        .collection('reports')
        .where('status', whereIn: ['dismissed', 'removed'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(ReportModel.fromFirestore).toList());
  }

  Future<void> dismissReport(ReportModel report) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return;
    debugPrint('AdminService: dismissReport id=${report.id}');
    await _db.collection('reports').doc(report.id).update({
      'status': 'dismissed',
      'reviewedBy': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    unawaited(logAuditAction(
      action: 'dismiss_report',
      targetUid: report.reporterId,
      metadata: {'reportId': report.id},
    ));
  }

  // ── Privacy / data-subject requests (DSAR) ──────────────────────────────────

  Stream<List<PrivacyRequestModel>> privacyRequestsStream({String? status}) {
    Query<Map<String, dynamic>> q = _db.collection('privacy_requests');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(PrivacyRequestModel.fromFirestore).toList());
  }

  Future<void> updatePrivacyRequest(
    PrivacyRequestModel req,
    PrivacyRequestStatus status, {
    String? adminNote,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return;
    debugPrint('AdminService: updatePrivacyRequest ${req.id} -> ${status.key}');
    await _db.collection('privacy_requests').doc(req.id).update({
      'status': status.key,
      if (adminNote != null) 'admin_note': adminNote,
      if (status == PrivacyRequestStatus.resolved ||
          status == PrivacyRequestStatus.rejected)
        'resolved_at': FieldValue.serverTimestamp(),
    });
    unawaited(logAuditAction(
      action: 'privacy_request_${status.key}',
      targetUid: req.uid,
      metadata: {'requestId': req.id, 'type': req.type.key},
    ));
  }

  Future<void> removeReportedContent(ReportModel report) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return;

    debugPrint(
        'AdminService: removeReportedContent type=${report.targetType} id=${report.targetId}');

    final batch = _db.batch();

    if (report.targetType == 'post') {
      batch.delete(_db.collection('posts').doc(report.targetId));
    } else {
      batch.delete(
        _db
            .collection('posts')
            .doc(report.postId)
            .collection('comments')
            .doc(report.targetId),
      );
    }

    batch.update(_db.collection('reports').doc(report.id), {
      'status': 'removed',
      'reviewedBy': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    unawaited(logAuditAction(
      action: 'remove_content_${report.targetType}',
      targetUid: report.authorId ?? '',
      metadata: {'reportId': report.id, 'targetId': report.targetId},
    ));
    debugPrint(
        'AdminService: removed ${report.targetType} ${report.targetId}');
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

    // 3. Update user roles (additive — preserves existing roles)
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_roles': FieldValue.arrayUnion(['coach']),
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

    // Use application ID as gymId — unique per application, avoids collision on reapply
    final gymId = app.id;
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
      memberCount: 1,
      subscriptionTier: GymSubscriptionTier.free,
      createdAt: gymNow,
      updatedAt: gymNow,
      latitude: app.latitude,
      longitude: app.longitude,
      brandColor: app.brandColor,
    );
    batch.set(_db.collection('gyms').doc(gymId), gym.toFirestore());

    // 2a. Add owner as first member
    batch.set(
      _db.collection('gyms').doc(gymId).collection('members').doc(app.applicantUid),
      {
        'uid': app.applicantUid,
        'joined_at': FieldValue.serverTimestamp(),
        'tier': 'premium',
      },
    );

    // 3. Update user roles (additive — preserves existing roles)
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_roles': FieldValue.arrayUnion(['gym_owner']),
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

    final parsed = UserRoleX.fromString(role);
    if (parsed == UserRole.consumer) {
      // Demote to consumer — clear all non-consumer roles
      const nonConsumerRoles = ['gym_owner', 'coach', 'admin'];
      await _db.collection('users').doc(uid).update({
        'user_roles': FieldValue.arrayRemove(nonConsumerRoles),
        'user_role': 'consumer',
      });
    } else {
      await FirestoreService().addUserRole(uid, parsed);
    }

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

  // ── Broadcasts ─────────────────────────────────────────────────────────────

  /// [audience] values: 'all' | 'coaches' | 'gymOwners' | 'user:{uid}'
  Future<void> sendBroadcast({
    required String titleEn,
    required String bodyEn,
    required String titleTr,
    required String bodyTr,
    required String audience,
    DateTime? scheduleAt,
  }) async {
    final adminUid = _auth.currentUser?.uid ?? '';
    debugPrint(
        'AdminService: sendBroadcast audience=$audience scheduleAt=$scheduleAt');

    final docRef = _db.collection('broadcasts').doc();
    final isScheduled =
        scheduleAt != null && scheduleAt.isAfter(DateTime.now());

    await docRef.set({
      'admin_uid': adminUid,
      'title_en': titleEn,
      'body_en': bodyEn,
      'title_tr': titleTr,
      'body_tr': bodyTr,
      'audience': audience,
      'status': isScheduled ? 'scheduled' : 'pending',
      'scheduled_at':
          scheduleAt != null ? Timestamp.fromDate(scheduleAt) : null,
      'sent_at': null,
      'recipient_count': 0,
      'created_at': FieldValue.serverTimestamp(),
    });

    await logAuditAction(
      action: 'send_broadcast',
      targetUid: 'audience:$audience',
      metadata: {
        'broadcast_id': docRef.id,
        'title_en': titleEn,
        'audience': audience,
        'scheduled': isScheduled,
      },
    );

    debugPrint('AdminService: broadcast doc created ${docRef.id}');
  }

  Stream<List<Map<String, dynamic>>> broadcastsStream() {
    return _db
        .collection('broadcasts')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: broadcastsStream error — $e');
    });
  }

  // ── Program Marketplace Approval ──────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> pendingProgramsStream() {
    return _db
        .collection('programs')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: pendingProgramsStream error — $e');
    });
  }

  Stream<List<Map<String, dynamic>>> programHistoryStream({String? status}) {
    Query<Map<String, dynamic>> q = _db.collection('programs');
    if (status != null) {
      q = q.where('status', isEqualTo: status);
    } else {
      q = q.where('status', whereIn: ['approved', 'rejected']);
    }
    return q
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: programHistoryStream error — $e');
    });
  }

  Future<void> approveProgram(String programId) async {
    final adminUid = _auth.currentUser?.uid ?? '';
    debugPrint('AdminService: approveProgram $programId');
    await _db.collection('programs').doc(programId).update({
      'status': 'approved',
      'reviewed_by': adminUid,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
    await logAuditAction(
      action: 'approve_program',
      targetUid: programId,
      metadata: {'programId': programId},
    );
  }

  Future<void> rejectProgram(String programId, String notes) async {
    final adminUid = _auth.currentUser?.uid ?? '';
    debugPrint('AdminService: rejectProgram $programId notes=$notes');
    await _db.collection('programs').doc(programId).update({
      'status': 'rejected',
      'rejection_notes': notes,
      'reviewed_by': adminUid,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
    await logAuditAction(
      action: 'reject_program',
      targetUid: programId,
      metadata: {'programId': programId, 'notes': notes},
    );
  }

  // ── Verification Badges ────────────────────────────────────────────────────

  Future<void> setGymVerified(String gymId, bool verified) async {
    debugPrint('AdminService: setGymVerified gymId=$gymId verified=$verified');
    await _db.collection('gyms').doc(gymId).update({'is_verified': verified});
    await logAuditAction(
      action: verified ? 'verify_gym' : 'unverify_gym',
      targetUid: gymId,
      metadata: {'gymId': gymId, 'verified': verified},
    );
  }

  Future<void> setCoachVerified(String coachUid, bool verified) async {
    debugPrint(
        'AdminService: setCoachVerified uid=$coachUid verified=$verified');
    await _db
        .collection('coach_profiles')
        .doc(coachUid)
        .update({'is_verified': verified});
    await logAuditAction(
      action: verified ? 'verify_coach' : 'unverify_coach',
      targetUid: coachUid,
      metadata: {'coachUid': coachUid, 'verified': verified},
    );
  }

  // ── Admin Config ───────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> adminConfigStream() {
    return _db
        .collection('admin_config')
        .doc('global')
        .snapshots()
        .map((d) => d.exists ? d.data() : null)
        .handleError((Object e) {
      debugPrint('AdminService: adminConfigStream error — $e');
    });
  }

  Future<void> updateAdminConfig(Map<String, dynamic> updates) async {
    final adminUid = _auth.currentUser?.uid ?? '';
    debugPrint(
        'AdminService: updateAdminConfig keys=${updates.keys.join(",")}');
    await _db.collection('admin_config').doc('global').set(
      {
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': adminUid,
      },
      SetOptions(merge: true),
    );
    await logAuditAction(
      action: 'update_admin_config',
      targetUid: adminUid,
      metadata: {'keys': updates.keys.toList()},
    );
  }

  // ── AI Credits Admin ───────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> aiUsageStream({int limit = 20}) {
    return _db
        .collection('users')
        .where('ai_credits_used', isGreaterThan: 0)
        .orderBy('ai_credits_used', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: aiUsageStream error — $e');
    });
  }

  Future<void> grantBonusCredits(String uid, int count, String reason) async {
    debugPrint(
        'AdminService: grantBonusCredits uid=$uid count=$count reason=$reason');
    await _db.collection('users').doc(uid).update({
      'ai_credits_bonus': FieldValue.increment(count),
    });
    await logAuditAction(
      action: 'grant_bonus_credits',
      targetUid: uid,
      metadata: {'count': count, 'reason': reason},
    );
  }

  // ── Referrals ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> referralsStream({int limit = 50}) {
    return _db
        .collection('referrals')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: referralsStream error — $e');
    });
  }

  Future<void> voidReferralCode(String code) async {
    debugPrint('AdminService: voidReferralCode code=$code');
    await _db.collection('referrals').doc(code).update({'maxUses': 0});
    await logAuditAction(
      action: 'void_referral_code',
      targetUid: code,
      metadata: {'code': code},
    );
  }

  // ── Support Tools ──────────────────────────────────────────────────────────

  Future<Map<String, int>> getUserDataStats(String uid) async {
    debugPrint('AdminService: getUserDataStats uid=$uid');
    try {
      final userRef = _db.collection('users').doc(uid);
      final results = await Future.wait([
        userRef.collection('food_logs').count().get(),
        userRef.collection('program_enrollments').count().get(),
        userRef.collection('favorites').count().get(),
      ]);
      return {
        'food_logs': results[0].count ?? 0,
        'enrolled_programs': results[1].count ?? 0,
        'favorites': results[2].count ?? 0,
      };
    } catch (e) {
      debugPrint('AdminService: getUserDataStats error — $e');
      return {'food_logs': 0, 'enrolled_programs': 0, 'favorites': 0};
    }
  }

  Future<void> forceLogout(String uid) async {
    debugPrint('AdminService: forceLogout uid=$uid');
    await _db.collection('users').doc(uid).update({
      'session_token': FieldValue.delete(),
      'force_logout': true,
    });
    await logAuditAction(action: 'force_logout', targetUid: uid);
  }

  Future<void> sendPasswordReset(String email) async {
    debugPrint('AdminService: sendPasswordReset email=$email');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    await logAuditAction(
      action: 'send_password_reset',
      targetUid: email,
      metadata: {'email': email},
    );
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  /// Snapshot metrics for the analytics dashboard.
  /// Uses Firestore aggregate count() queries for efficiency.
  Future<Map<String, int>> fetchAnalyticsSnapshot() async {
    try {
      final results = await Future.wait([
        _db.collection('users').count().get(),
        _db.collection('users').where('subscription_tier', whereIn: ['premium', 'pro']).count().get(),
        _db.collection('users').where('user_role', isEqualTo: 'coach').count().get(),
        _db.collection('users').where('user_role', isEqualTo: 'gymOwner').count().get(),
        _db.collection('posts').count().get(),
        _db.collection('reports').where('status', isEqualTo: 'pending').count().get(),
        _db.collection('squads').count().get(),
      ]);
      return {
        'total_users': results[0].count ?? 0,
        'premium_users': results[1].count ?? 0,
        'coaches': results[2].count ?? 0,
        'gym_owners': results[3].count ?? 0,
        'posts': results[4].count ?? 0,
        'open_reports': results[5].count ?? 0,
        'squads': results[6].count ?? 0,
      };
    } catch (e) {
      debugPrint('AdminService: fetchAnalyticsSnapshot error — $e');
      return {};
    }
  }

  // ── Billing & Abuse Streams ───────────────────────────────────────────────

  /// Live stream of premium/pro subscribers, ordered by join date (newest first).
  Stream<List<Map<String, dynamic>>> premiumUsersStream({int limit = 100}) {
    return _db
        .collection('users')
        .where('subscription_tier', whereIn: ['premium', 'pro'])
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: premiumUsersStream error — $e');
    });
  }

  /// Live stream of currently banned users.
  Stream<List<Map<String, dynamic>>> bannedUsersStream({int limit = 50}) {
    return _db
        .collection('users')
        .where('is_banned', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: bannedUsersStream error — $e');
    });
  }

  // ── Bulk Moderation ────────────────────────────────────────────────────────

  Future<void> bulkDismissReports(List<String> reportIds) async {
    if (reportIds.isEmpty) return;
    debugPrint('AdminService: bulkDismissReports count=${reportIds.length}');
    final batch = _db.batch();
    final uid = _auth.currentUser?.uid ?? 'system';
    for (final id in reportIds) {
      batch.update(_db.collection('reports').doc(id), {
        'status': 'dismissed',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': uid,
      });
    }
    await batch.commit();
    await logAuditAction(
      action: 'bulk_dismiss_reports',
      targetUid: 'bulk',
      metadata: {'count': reportIds.length},
    );
  }

  Future<void> bulkRemoveContent(List<ReportModel> reports) async {
    if (reports.isEmpty) return;
    debugPrint('AdminService: bulkRemoveContent count=${reports.length}');
    final batch = _db.batch();
    final uid = _auth.currentUser?.uid ?? 'system';
    for (final r in reports) {
      batch.update(_db.collection('reports').doc(r.id), {
        'status': 'removed',
        'reviewed_at': FieldValue.serverTimestamp(),
        'reviewed_by': uid,
      });
      if (r.targetId.isNotEmpty) {
        if (r.targetType == 'post') {
          batch.delete(_db.collection('posts').doc(r.targetId));
        } else if (r.targetType == 'comment' && r.postId.isNotEmpty) {
          batch.delete(_db.collection('posts')
              .doc(r.postId)
              .collection('comments')
              .doc(r.targetId));
        }
      }
    }
    await batch.commit();
    await logAuditAction(
      action: 'bulk_remove_content',
      targetUid: 'bulk',
      metadata: {'count': reports.length},
    );
  }
}
