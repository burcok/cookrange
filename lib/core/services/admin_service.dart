import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/coach_application_model.dart';
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
}
