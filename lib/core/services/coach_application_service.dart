import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/coach_application_model.dart';

/// Manages coach applications — submit, read, and stream status.
/// Separate from [CoachService] so approval logic stays isolated.
class CoachApplicationService {
  static final CoachApplicationService _instance =
      CoachApplicationService._internal();
  factory CoachApplicationService() => _instance;
  CoachApplicationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _col = 'coach_applications';

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<String> submitApplication({
    required String applicantUid,
    required String displayName,
    required String bio,
    required List<String> specializations,
    required int experienceYears,
    required int hourlyRate,
    required List<File> evidenceFiles,
    required List<String> evidenceLabels,
    required List<Map<String, String>> references,
    String contactPhone = '',
    String? certDocUrl,
    String? idDocUrl,
  }) async {
    // Upload evidence files first
    final evidenceUrls = <String>[];
    for (var i = 0; i < evidenceFiles.length; i++) {
      final url = await _uploadEvidence(
          applicantUid, evidenceFiles[i], 'evidence_$i');
      evidenceUrls.add(url);
    }

    final ref = _db.collection(_col).doc();
    final model = CoachApplicationModel(
      id: ref.id,
      applicantUid: applicantUid,
      displayName: displayName,
      status: CoachApplicationStatus.pending,
      bio: bio,
      specializations: specializations,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      evidenceUrls: evidenceUrls,
      evidenceLabels: evidenceLabels,
      references: references,
      contactPhone: contactPhone,
      certDocUrl: certDocUrl,
      idDocUrl: idDocUrl,
      submittedAt: DateTime.now(),
    );
    await ref.set(model.toFirestore());
    debugPrint('CoachApplicationService: submitted application ${ref.id}');
    return ref.id;
  }

  Future<String> _uploadEvidence(
      String uid, File file, String name) async {
    final ref = _storage
        .ref('coach_applications/$uid/$name.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<CoachApplicationModel?> getMyApplication(String uid) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('applicantUid', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return CoachApplicationModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('CoachApplicationService.getMyApplication error: $e');
      return null;
    }
  }

  Stream<CoachApplicationModel?> getMyApplicationStream(String uid) {
    return _db
        .collection(_col)
        .where('applicantUid', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) =>
            s.docs.isEmpty ? null : CoachApplicationModel.fromFirestore(s.docs.first));
  }

  // ── Admin streams ──────────────────────────────────────────────────────────

  Stream<List<CoachApplicationModel>> getPendingApplicationsStream() {
    return _db
        .collection(_col)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map(CoachApplicationModel.fromFirestore)
            .toList());
  }

  Stream<List<CoachApplicationModel>> getAllApplicationsStream() {
    return _db
        .collection(_col)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map(CoachApplicationModel.fromFirestore)
            .toList());
  }
}
