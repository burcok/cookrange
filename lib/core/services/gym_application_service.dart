import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/gym_application_model.dart';

/// Manages gym registration applications — submit, read, and stream status.
class GymApplicationService {
  static final GymApplicationService _instance =
      GymApplicationService._internal();
  factory GymApplicationService() => _instance;
  GymApplicationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _col = 'gym_applications';

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<String> submitApplication({
    required String applicantUid,
    required String gymName,
    required String address,
    required String city,
    required String description,
    required String contactPhone,
    required List<String> tags,
    String? businessDocUrl,
    String? idDocUrl,
    double? latitude,
    double? longitude,
    String? brandColor,
  }) async {
    final ref = _db.collection(_col).doc();
    final model = GymApplicationModel(
      id: ref.id,
      applicantUid: applicantUid,
      gymName: gymName,
      address: address,
      city: city,
      description: description,
      businessDocUrl: businessDocUrl,
      idDocUrl: idDocUrl,
      photoUrls: [
        if (businessDocUrl != null) businessDocUrl,
        if (idDocUrl != null) idDocUrl,
      ],
      contactPhone: contactPhone,
      tags: tags,
      latitude: latitude,
      longitude: longitude,
      brandColor: brandColor,
      status: GymApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );
    await ref.set(model.toFirestore());
    debugPrint(
        'GymApplicationService: submitted application ${ref.id} for $applicantUid');
    return ref.id;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<GymApplicationModel?> getMyApplication(String uid) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('applicantUid', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return GymApplicationModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('GymApplicationService.getMyApplication error: $e');
      return null;
    }
  }

  Stream<GymApplicationModel?> getMyApplicationStream(String uid) {
    return _db
        .collection(_col)
        .where('applicantUid', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : GymApplicationModel.fromFirestore(s.docs.first));
  }

  // ── Admin streams ──────────────────────────────────────────────────────────

  Stream<List<GymApplicationModel>> getPendingApplicationsStream() {
    return _db
        .collection(_col)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(GymApplicationModel.fromFirestore).toList());
  }

  Stream<List<GymApplicationModel>> getAllApplicationsStream() {
    return _db
        .collection(_col)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GymApplicationModel.fromFirestore).toList());
  }
}
