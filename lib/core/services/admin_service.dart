import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/coach_application_model.dart';
import '../models/moderation_appeal_model.dart';
import '../models/privacy_request_model.dart';
import '../models/report_model.dart';
import '../utils/firestore_count.dart';
import 'analytics_service.dart';
import 'community_group_service.dart';
import 'crashlytics_service.dart';
import '../models/chat_model.dart';
import '../models/coach_profile_model.dart';
import '../models/community_group_model.dart';
import '../models/gym_application_model.dart';
import '../models/gym_model.dart';
import '../models/user_model.dart';
import '../data/test_data_library.dart';
import '../config/app_config_schema.g.dart';
import '../utils/deep_merge.dart';
import 'firestore_service.dart';
import 'test_mode_service.dart';

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
        .map((s) => s.docs.map(CoachApplicationModel.fromFirestore).toList());
  }

  Stream<List<GymApplicationModel>> pendingGymApplicationsStream() {
    return _db
        .collection('gym_applications')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt')
        .snapshots()
        .map((s) => s.docs.map(GymApplicationModel.fromFirestore).toList());
  }

  // These counts use the cheap count() aggregation polled periodically, instead
  // of streaming (and re-reading) entire collections on every change. Aggregate
  // queries have no .snapshots(), so we poll via pollCount.
  // Broadcast so multiple StreamBuilders (the badge appears in >1 place on the
  // admin overview) can listen without a single-subscription crash.
  Stream<int> pendingCountStream() =>
      _pendingCountGenerator().asBroadcastStream();

  Stream<int> _pendingCountGenerator() async* {
    while (true) {
      try {
        final coach = await _db
            .collection('coach_applications')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        final gym = await _db
            .collection('gym_applications')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        yield (coach.count ?? 0) + (gym.count ?? 0);
      } catch (_) {
        yield 0;
      }
      await Future<void>.delayed(const Duration(seconds: 45));
    }
  }

  /// Total registered user count via aggregation (not a whole-collection listen).
  Stream<int> userCountStream() => pollCount(_db.collection('users'));

  /// Count of open/pending reports via aggregation.
  Stream<int> openReportCountStream() => pollCount(
        _db.collection('reports').where('status', isEqualTo: 'pending'),
      );

  /// Count of pending moderation appeals via aggregation (Faz 2 §2.6).
  Stream<int> pendingModerationAppealCountStream() => pollCount(
        _db
            .collection('moderation_appeals')
            .where('status', isEqualTo: 'pending'),
      );

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

  // ── Moderation appeals (Faz 2 §2.6 — "itiraz yolu") ─────────────────────────
  // Mirrors the DSAR flow immediately above: a member files their own
  // appeal against a specific group moderation action; admin reviews and
  // resolves it here. See docs/COMPLIANCE.md §7 for why this pattern (not a
  // new one) was reused.

  Stream<List<ModerationAppealModel>> pendingModerationAppealsStream() {
    return _db
        .collection('moderation_appeals')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(ModerationAppealModel.fromFirestore).toList());
  }

  Stream<List<ModerationAppealModel>> reviewedModerationAppealsStream() {
    return _db
        .collection('moderation_appeals')
        .where('status', whereIn: ['upheld', 'denied'])
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(ModerationAppealModel.fromFirestore).toList());
  }

  /// Resolves an appeal. When [status] is `upheld` and the underlying action
  /// is `mute`/`ban`, this ALSO reverses it via the existing
  /// `CommunityGroupService.unmuteMember`/`unbanMember` — an "upheld" appeal
  /// that doesn't actually restore anything would be a hollow gesture. A
  /// `kick` has no persistent restriction to lift (the member can simply be
  /// re-added or can re-request to join), so upholding a kick appeal is
  /// admin-note-only. Always notifies the appellant of the outcome via the
  /// existing free-text admin-notification path (`sendNotificationToUser`) —
  /// deliberately not a new `NotificationType` for one admin-authored
  /// message, mirroring how coach/gym rejection notes already work.
  ///
  /// Faz 5 §5.2: [appeal.isCreditRestriction] (a shadow-restriction appeal,
  /// not a group action) reverses via [_liftCreditRestriction] instead —
  /// `appeal.action`/`appeal.groupId` are meaningless placeholders for this
  /// appeal kind (see `ModerationAppealModel`'s doc comment), so this branch
  /// must come BEFORE the mute/ban check below, which would otherwise
  /// misread the placeholder `action` value.
  Future<void> resolveModerationAppeal(
    ModerationAppealModel appeal,
    ModerationAppealStatus status, {
    String? adminNote,
    required String notifyTitle,
    required String notifyBody,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return;
    debugPrint(
        'AdminService: resolveModerationAppeal id=${appeal.id} -> ${status.key}');

    await _db.collection('moderation_appeals').doc(appeal.id).update({
      'status': status.key,
      'resolved_by': adminUid,
      'resolved_at': FieldValue.serverTimestamp(),
      if (adminNote != null) 'admin_note': adminNote,
    });

    if (status == ModerationAppealStatus.upheld) {
      try {
        if (appeal.isCreditRestriction) {
          await _liftCreditRestriction(appeal.uid, adminUid);
        } else if (appeal.action == GroupModerationAction.ban) {
          await CommunityGroupService().unbanMember(appeal.groupId, appeal.uid);
        } else if (appeal.action == GroupModerationAction.mute) {
          await CommunityGroupService()
              .unmuteMember(appeal.groupId, appeal.uid);
        }
      } catch (e, st) {
        debugPrint('AdminService: resolveModerationAppeal reversal failed: $e');
        unawaited(CrashlyticsService().recordError(e, st,
            reason: 'AdminService.resolveModerationAppeal reversal'));
      }
    }

    unawaited(logAuditAction(
      action: 'resolve_moderation_appeal_${status.key}',
      targetUid: appeal.uid,
      metadata: {
        'appealId': appeal.id,
        'groupId': appeal.groupId,
        // rawAction, not appeal.action.value — the latter is a meaningless
        // placeholder for a credit-restriction appeal (see
        // ModerationAppealModel's doc comment); rawAction is correct for
        // both appeal kinds.
        'action': appeal.rawAction,
      },
    ));

    await sendNotificationToUser(
      uid: appeal.uid,
      title: notifyTitle,
      body: notifyBody,
    );
  }

  /// Faz 5 §5.2 — reverses a shadow restriction on an upheld appeal: writes
  /// a `lift` entry to the same immutable `users/{uid}/credit_moderation`
  /// log `engagement_credit.js`'s `bumpSuspicionFlag` writes `restrict`
  /// entries to, then clears `is_shadow_restricted` AND resets `flag_count`
  /// to 0 on `credit_restrictions/{uid}` — a genuine clean slate, since
  /// leaving the counter at/above the auto-restrict threshold would let the
  /// very next flagged event immediately re-restrict an account whose
  /// appeal was just upheld (i.e. judged UNWARRANTED). Both writes are
  /// legitimate here because `isAdmin()` is exempted on both collections in
  /// firestore.rules, exactly like every other admin-override path in this
  /// file (e.g. `unmuteMember`/`unbanMember` above).
  Future<void> _liftCreditRestriction(String uid, String adminUid) async {
    final logRef =
        _db.collection('users').doc(uid).collection('credit_moderation').doc();
    final batch = _db.batch();
    batch.set(logRef, {
      'action': 'lift',
      'reason': 'appeal_upheld',
      'issued_by': adminUid,
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.set(
      _db.collection('credit_restrictions').doc(uid),
      {
        'is_shadow_restricted': false,
        'flag_count': 0,
        'lifted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
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
    debugPrint('AdminService: removed ${report.targetType} ${report.targetId}');
  }

  // ── Approve Coach ──────────────────────────────────────────────────────────

  Future<void> approveCoachApplication(CoachApplicationModel app) async {
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
    batch.set(_db.collection('coach_profiles').doc(app.applicantUid),
        profile.toFirestore());

    // 3. Update user roles (additive — preserves existing roles)
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_roles': FieldValue.arrayUnion(['coach']),
      'user_role': 'coach',
    });

    await batch.commit();
    debugPrint('AdminService: coach application ${app.id} approved');

    // 4. Notify the applicant — server-authored (BLK-03/SEC-06)
    await _sendAdminNotification(
      targetUid: app.applicantUid,
      type: 'coachApplicationApproved',
      relatedId: app.id,
    );
  }

  // ── Approve Gym ─────────────────────────────────────────────────────────────

  Future<void> approveGymApplication(GymApplicationModel app) async {
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
      // Faz 0 §0.7: photoUrls is [businessDocUrl, idDocUrl] — private
      // verification documents submitted for admin review
      // (application_review_screen.dart), never a logo image. Using
      // photoUrls.first here put a business license (or, if none was
      // submitted, the applicant's ID document) into the gym's PUBLIC
      // logo field. The real logo path already exists and is correct:
      // gym_setup_screen.dart's Edit Gym Profile → StorageUploadService
      // .uploadGymLogo() → gyms/{gymId}/logo.jpg → logo_url. So a
      // freshly-approved gym simply starts with no logo; the owner sets
      // one afterward via that existing flow.
      logoUrl: null,
      tags: app.tags,
      isPublic: true,
      memberCount: 1,
      subscriptionTier: GymSubscriptionTier.free,
      createdAt: gymNow,
      updatedAt: gymNow,
      latitude: app.latitude,
      longitude: app.longitude,
      brandColor: app.brandColor,
      // Faz 1.1: contactPhone genuinely exists on GymApplicationModel (it's
      // required there) and was simply never carried over to the approved
      // GymModel — fixed here. district/checkInRadius/openingHours/capacity/
      // geofenceEnabled are NOT set below because GymApplicationModel has no
      // fields for them (see gym_application_model.dart) — the application
      // flow never collects a district or a custom radius, so there is
      // nothing to carry over yet. Same precedent as logoUrl above: a
      // freshly-approved gym starts with GymModel's defaults (checkInRadius
      // 100, district/openingHours/capacity unset, geofenceEnabled false) and
      // the owner sets real values afterward via gym_setup_screen.dart's Edit
      // Gym Profile flow.
      contactPhone: app.contactPhone,
    );
    batch.set(_db.collection('gyms').doc(gymId), gym.toFirestore());

    // 2a. Add owner as first member
    batch.set(
      _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(app.applicantUid),
      {
        'uid': app.applicantUid,
        'joined_at': FieldValue.serverTimestamp(),
        'tier': 'premium',
      },
    );

    // 2b. Faz 2 §2.3 — auto-create the gym's community group (kind:'gym',
    // owner = gym owner, gym_id back-reference). Uses the SAME gymId as the
    // doc id — a gym and its group are 1:1, created together, and never
    // exist independently, so reusing the id avoids a second lookup
    // anywhere that already has one of them. isPublic:false keeps it out of
    // the general discovery carousel (CommunityGroupModel.kind doc comment)
    // — members reach it from the gym's own screen, not groups discovery.
    // The community_groups create rule's `owner_uid == auth.uid || isAdmin()`
    // branch is what makes this legal: this batch runs under the APPROVING
    // ADMIN's auth context, not the gym owner's, so owner_uid (the gym
    // owner) necessarily differs from request.auth.uid (the admin) here.
    final group = CommunityGroupModel(
      id: gymId,
      name: app.gymName,
      description: app.description,
      city: app.city,
      ownerUid: app.applicantUid,
      isPublic: false,
      tags: app.tags,
      createdAt: gymNow,
      updatedAt: gymNow,
      lastActivityAt: gymNow,
      chatId: gymId,
      kind: GroupKind.gym,
      gymId: gymId,
    );
    batch.set(
        _db.collection('community_groups').doc(gymId), group.toFirestore());
    batch.set(
      _db
          .collection('community_groups')
          .doc(gymId)
          .collection('members')
          .doc(app.applicantUid),
      CommunityGroupMemberModel(
        uid: app.applicantUid,
        joinedAt: gymNow,
        role: GroupMemberRole.owner,
      ).toFirestore(),
    );

    // 2c. Paired chat doc (chatId == gymId) — makes ChatType.gym real.
    // `participants` holds only the owner (chats/{chatId}'s create rule
    // needs SOME initial participant; the whole group's membership gets
    // access via `groupId` → firestore.rules' `canAccessGroupChat()`, not
    // this array — see ChatModel.groupId's doc comment).
    final gymChat = ChatModel(
      id: gymId,
      participants: [app.applicantUid],
      unreadCounts: {app.applicantUid: 0},
      type: ChatType.gym,
      updatedAt: gymNow,
      name: app.gymName,
      groupId: gymId,
    );
    batch.set(_db.collection('chats').doc(gymId), gymChat.toJson());

    // 3. Update user roles (additive — preserves existing roles) and record
    // the owner's own gym on their own user doc — matches the exact
    // gym_memberships arrayUnion mechanism GymService.joinGym already uses
    // for regular joining members; previously only non-owner joiners got
    // this, so an owner's own gym never appeared in their own "your gyms"
    // list.
    batch.update(_db.collection('users').doc(app.applicantUid), {
      'user_roles': FieldValue.arrayUnion(['gym_owner']),
      'user_role': 'gym_owner',
      'gym_memberships': FieldValue.arrayUnion([gymId]),
    });

    await batch.commit();
    debugPrint('AdminService: gym application ${app.id} approved');

    // 4. Notify the applicant — server-authored (BLK-03/SEC-06)
    await _sendAdminNotification(
      targetUid: app.applicantUid,
      type: 'gymApplicationApproved',
      relatedId: app.id,
    );
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

    await batch.commit();
    debugPrint('AdminService: coach application ${app.id} rejected');

    await _sendAdminNotification(
      targetUid: app.applicantUid,
      type: 'coachApplicationRejected',
      relatedId: app.id,
      notes: notes,
    );
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

    await batch.commit();

    await _sendAdminNotification(
      targetUid: app.applicantUid,
      type: 'gymApplicationRejected',
      relatedId: app.id,
      notes: notes,
    );
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
    if (TestModeService().isActive) {
      final lower = query.toLowerCase();
      return TestDataLibrary.adminUsers()
          .where((u) =>
              query.isEmpty ||
              (u['displayName'] as String? ?? '')
                  .toLowerCase()
                  .contains(lower) ||
              (u['email'] as String? ?? '').toLowerCase().contains(lower))
          .toList();
    }
    // Prefix range search on displayName (\uf8ff is the high-codepoint cap).
    final end = query.isEmpty ? query : '$query\uf8ff';
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: end)
        .limit(20)
        .get();
    final users = snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    return _enrichWithPrivateAccount(users);
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    if (TestModeService().isActive) {
      return Stream.value(TestDataLibrary.adminUsers());
    }
    // NOTE: user docs store the snake_case `created_at` \u2014 ordering by
    // `createdAt` (camelCase) silently returned ZERO docs (Firestore excludes
    // docs missing the orderBy field), which is why the list looked empty.
    return _db
        .collection('users')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((s) async {
      final users = s.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
      return _enrichWithPrivateAccount(users);
    });
  }

  /// Enriches each admin-visible user row with `email` from the owner-(+
  /// admin-)only `private/account` subcollection (audit N1 \u2014 email no longer
  /// lives on the world-readable main doc, so it's absent from a plain
  /// `...d.data()` spread). Bounded to admin-screen result sizes (\u226450, an
  /// admin support tool rather than a hot path) so the extra per-row read is
  /// an acceptable trade for closing the leak.
  Future<List<Map<String, dynamic>>> _enrichWithPrivateAccount(
      List<Map<String, dynamic>> users) {
    return Future.wait(users.map((u) async {
      final uid = u['uid'] as String?;
      if (uid == null) return u;
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('account')
          .get();
      final email = snap.data()?['email'];
      if (email != null) return {...u, 'email': email};
      return u;
    }));
  }

  Future<void> banUser(String uid, String reason) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('AdminService: not authenticated');

    debugPrint('AdminService: banUser uid=$uid reason="$reason"');

    final batch = _db.batch();
    batch.set(
        _db.collection('admin').doc('status').collection(uid).doc('flags'),
        {
          'is_banned': true,
          'ban_reason': reason,
          'banned_at': FieldValue.serverTimestamp(),
          'banned_by': adminUid,
        },
        SetOptions(merge: true));
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
    batch.set(
        _db.collection('admin').doc('status').collection(uid).doc('flags'),
        {
          'is_banned': false,
        },
        SetOptions(merge: true));
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

  /// Server-authored application-decision notification (BLK-03/SEC-06). Fired
  /// after the review batch above already committed the status/role change —
  /// a best-effort follow-up, not part of that transaction: if this throws,
  /// the approval/rejection itself has already succeeded, so we log and swallow
  /// rather than surface a false failure to the admin.
  Future<void> _sendAdminNotification({
    required String targetUid,
    required String type,
    String? relatedId,
    String? notes,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendAdminNotification')
          .call({
        'targetUid': targetUid,
        'type': type,
        if (relatedId != null) 'relatedId': relatedId,
        if (notes != null) 'notes': notes,
      });
    } catch (e, st) {
      debugPrint('AdminService: _sendAdminNotification failed type=$type: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'AdminService._sendAdminNotification type=$type targetUid=$targetUid'));
    }
  }

  /// Sends a direct (admin → single user) free-text notification. Server-
  /// authored (BLK-03/SEC-06) via the same admin-only callable, using its
  /// legacy title/body branch so `NotificationPresenter` shows the message
  /// verbatim.
  Future<void> sendNotificationToUser({
    required String uid,
    required String title,
    required String body,
  }) async {
    debugPrint('AdminService: sendNotificationToUser uid=$uid');
    await FirebaseFunctions.instance
        .httpsCallable('sendAdminNotification')
        .call({
      'targetUid': uid,
      'type': 'system',
      'title': title,
      'body': body,
    });

    // Audit doc is written server-side (sendAdminNotification's 'system'
    // branch); the analytics event stays client-side since Cloud Functions
    // can't emit to this device's Firebase Analytics SDK.
    unawaited(AnalyticsService().logEvent(
      name: 'admin_action',
      parameters: {'action': 'send_notification', 'target_uid': uid},
    ));
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

  /// Reads the current remote app config, merged from `app_config/critical`
  /// + `client` + `server` — Faz A Faz 4. Replaces the old direct read
  /// against the now-frozen legacy `app_config/global` doc: Faz 3 seeded
  /// real values into the three schema-driven docs, and nothing writes
  /// `global` anymore, so reading it here would show stale data. An admin's
  /// own Firestore read permissions already cover all three (critical/
  /// client: broader; server: `isAdmin()`), so no callable is needed for
  /// the read side — only writes are gated (see [updateAppConfig] below).
  Future<Map<String, dynamic>> getAppConfig() async {
    final snaps = await Future.wait([
      _db.collection('app_config').doc('critical').get(),
      _db.collection('app_config').doc('client').get(),
      _db.collection('app_config').doc('server').get(),
    ]);
    return deepMergeMaps(snaps.map((s) => s.data() ?? <String, dynamic>{}).toList());
  }

  /// Splits [patch] — the screen's flat, nested shape (`{'ai': {...},
  /// 'version': {...}, ...}`, matching `config_schema.json`'s own dotted-key
  /// sections) — into per-key dotted entries, routes each to its
  /// schema-declared doc via [kConfigSchema], and issues one
  /// `updateAppConfig` callable call per doc that has at least one changed
  /// key. Faz A Faz 4: replaces the old direct `app_config/global`
  /// merge-write — firestore.rules denies that unconditionally as of the
  /// Faz 2 callable lockdown (`app_config/*` is `write: if false` for
  /// everyone, admin included); `updateAppConfig`
  /// (functions/app_config_admin.js) is the only remaining write path.
  ///
  /// [reason] is required and forwarded as-is (the callable enforces
  /// >=10 chars for any `sensitive` field). `confirm`/`force` are passed
  /// unconditionally on every call rather than trying to detect per-field
  /// sensitivity or change-size client-side — this screen has no UI for
  /// either, and the real safety net here is the audit trail + version
  /// history the callable itself writes on every call, not a client-side
  /// confirmation dialog (that richer UX belongs to the real web admin
  /// panel, DECISIONS.md ADR-024 — this screen is a stopgap Faz B7 slates for
  /// full deletion once that panel ships, not a rebuild target).
  ///
  /// A per-doc call failing (schema validation, a cross-field invariant)
  /// throws and stops there — any doc already written in this same
  /// invocation stays written; this is a deliberate, accepted change from
  /// the old single-doc atomic write, since splitting across 3
  /// independently-validated docs has no atomic multi-doc callable to lean
  /// on without a materially larger change than this fix's scope.
  Future<void> updateAppConfig(
    Map<String, dynamic> patch, {
    required String reason,
  }) async {
    final keyToDoc = {for (final f in kConfigSchema) f.key: f.doc.name};
    final byDoc = <String, Map<String, dynamic>>{
      'critical': {},
      'client': {},
      'server': {},
    };

    void flatten(String prefix, Map<String, dynamic> node) {
      for (final entry in node.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        final value = entry.value;
        final doc = keyToDoc[key];
        if (doc != null) {
          // A known schema leaf — even if its own value happens to be a Map
          // (e.g. version.update_message: {en, tr}), it's the VALUE for
          // this one dotted key, not a section to recurse into further.
          byDoc[doc]![key] = value;
        } else if (value is Map) {
          flatten(key, Map<String, dynamic>.from(value));
        }
        // Neither a known key nor a Map to descend into — not a real
        // schema field (shouldn't happen from this screen's own
        // schema-shaped patch); silently dropped rather than sent to a
        // callable that would reject it anyway.
      }
    }

    flatten('', patch);

    for (final entry in byDoc.entries) {
      if (entry.value.isEmpty) continue;
      await FirebaseFunctions.instance.httpsCallable('updateAppConfig').call({
        'doc': entry.key,
        'patch': entry.value,
        'reason': reason,
        'confirm': true,
        'force': true,
      });
    }
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
  // Faz A §A9 — `adminConfigStream()`/`updateAdminConfig()` deleted: zero
  // callers anywhere in lib/ (re-confirmed directly before deletion), and
  // `admin_config/global` was an orphaned second config surface next to
  // app_config/*. Its one real, live effect — mirroring `blocked_keywords`
  // into the PUBLIC `settings/content_filter` doc that
  // community_service.dart actually reads — moved to a working writer:
  // the `updateContentFilter` callable (functions/app_config_admin.js),
  // on the same admin/audit/rate-limit path as the rest of app_config's
  // write side, rather than through this now-deleted, never-called method.

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
    // Bonus credits live in the server-authoritative ledger ai_credits/{uid}
    // (not the user doc). Admins may write it (rule allows isAdmin()).
    await _db.collection('ai_credits').doc(uid).set({
      'bonus': FieldValue.increment(count),
    }, SetOptions(merge: true));
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
        // Faz 0 §0.7: real docs only ever write created_at (snake_case —
        // see ReferralService.getOrCreateCode / functions/economy.js).
        // orderBy('createdAt') excluded every doc (Firestore drops docs
        // missing the ordered-on field), so this list was permanently
        // empty.
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((Object e) {
      debugPrint('AdminService: referralsStream error — $e');
    });
  }

  Future<void> voidReferralCode(String code) async {
    debugPrint('AdminService: voidReferralCode code=$code');
    // Faz 0 §0.7: applyReferral (functions/economy.js) only ever reads
    // ref.max_uses (snake_case). Writing 'maxUses' added a dead sibling
    // field that nothing checks — a voided code kept working server-side.
    await _db.collection('referrals').doc(code).update({'max_uses': 0});
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
        _db
            .collection('users')
            .where('subscription_tier', whereIn: ['premium', 'pro'])
            .count()
            .get(),
        _db
            .collection('users')
            .where('user_role', isEqualTo: 'coach')
            .count()
            .get(),
        _db
            .collection('users')
            .where('user_role', isEqualTo: 'gymOwner')
            .count()
            .get(),
        _db.collection('posts').count().get(),
        _db
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
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
          batch.delete(_db
              .collection('posts')
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
