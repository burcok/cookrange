import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/coach_profile_model.dart';
import '../models/program_content_model.dart';
import '../models/program_enrollment_model.dart';
import '../models/program_model.dart';

class ProgramService {
  static final ProgramService _i = ProgramService._();
  factory ProgramService() => _i;
  ProgramService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _programs =>
      _db.collection('programs');

  CollectionReference<Map<String, dynamic>> _enrollments(String userId) =>
      _db.collection('users').doc(userId).collection('program_enrollments');

  // ─── Coach CRUD ────────────────────────────────────────────────────────────

  Future<ProgramModel> createProgram(
    CoachProfileModel coach, {
    required String title,
    required String description,
    required ProgramDifficulty difficulty,
    required ProgramCategory category,
    required int durationWeeks,
    required int sessionsPerWeek,
    double price = 0.0,
    String? coverImageUrl,
    List<String> tags = const [],
    List<String> highlights = const [],
  }) async {
    debugPrint('ProgramService: creating program "$title" for coach ${coach.uid}');
    final now = DateTime.now();
    final ref = _programs.doc();
    final program = ProgramModel(
      id: ref.id,
      coachUid: coach.uid,
      coachName: coach.displayName,
      coachPhotoUrl: coach.photoURL,
      title: title,
      description: description,
      difficulty: difficulty,
      category: category,
      durationWeeks: durationWeeks,
      sessionsPerWeek: sessionsPerWeek,
      price: price,
      coverImageUrl: coverImageUrl,
      tags: tags,
      highlights: highlights,
      isPublished: false,
      status: 'draft',
      enrollmentCount: 0,
      rating: 0.0,
      ratingCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(program.toFirestore());
    debugPrint('ProgramService: created program ${ref.id}');
    return program;
  }

  Future<void> updateProgram(
      String programId, Map<String, dynamic> data) async {
    debugPrint('ProgramService: updating program $programId');
    await _programs.doc(programId).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> publishProgram(String programId) async {
    debugPrint('ProgramService: publishing program $programId');
    await _programs.doc(programId).update({
      'is_published': true,
      'status': 'pending',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ─── Streams ───────────────────────────────────────────────────────────────

  Stream<List<ProgramModel>> getCoachProgramsStream(String coachUid) {
    return _programs
        .where('coach_uid', isEqualTo: coachUid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProgramModel.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList())
        .handleError((Object e) {
      debugPrint('ProgramService: getCoachProgramsStream error — $e');
    });
  }

  Stream<List<ProgramModel>> getPublishedProgramsStream({
    ProgramCategory? category,
    ProgramDifficulty? difficulty,
  }) {
    Query<Map<String, dynamic>> q = _programs
        .where('is_published', isEqualTo: true)
        .where('status', isEqualTo: 'approved');

    if (category != null) {
      q = q.where('category', isEqualTo: category.firestoreValue);
    }

    q = q.orderBy('enrollment_count', descending: true).limit(50);

    return q.snapshots().map((snap) => snap.docs
        .map((d) => ProgramModel.fromFirestore(
            d as DocumentSnapshot<Map<String, dynamic>>))
        .toList())
        .handleError((Object e) {
      debugPrint('ProgramService: getPublishedProgramsStream error — $e');
    });
  }

  // ─── Enrollment ────────────────────────────────────────────────────────────

  Future<void> enrollInProgram(
      String userId, ProgramModel program) async {
    debugPrint(
        'ProgramService: enrolling user $userId in program ${program.id}');
    final enrollmentRef = _enrollments(userId).doc(program.id);
    final programRef = _programs.doc(program.id);

    final enrollment = ProgramEnrollmentModel(
      id: program.id,
      userUid: userId,
      programId: program.id,
      programTitle: program.title,
      coachUid: program.coachUid,
      status: EnrollmentStatus.active,
      currentWeek: 1,
      currentSession: 1,
      totalWeeks: program.durationWeeks,
      enrolledAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(enrollmentRef, enrollment.toFirestore());
    batch.update(programRef, {
      'enrollment_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    debugPrint(
        'ProgramService: enrollment committed for ${program.id}');
  }

  Stream<List<ProgramEnrollmentModel>> getEnrollmentsStream(String userId) {
    return _enrollments(userId)
        .orderBy('enrolled_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ProgramEnrollmentModel.fromFirestore).toList())
        .handleError((Object e) {
      debugPrint('ProgramService: getEnrollmentsStream error — $e');
    });
  }

  Future<bool> isEnrolled(String userId, String programId) async {
    final doc = await _enrollments(userId).doc(programId).get();
    return doc.exists;
  }

  Future<ProgramEnrollmentModel?> getEnrollment(
      String userId, String programId) async {
    final doc = await _enrollments(userId).doc(programId).get();
    if (!doc.exists) return null;
    return ProgramEnrollmentModel.fromFirestore(doc);
  }

  // ─── Program content ───────────────────────────────────────────────────────

  Stream<List<ProgramWeekModel>> getWeeksStream(String programId) {
    return _programs
        .doc(programId)
        .collection('weeks')
        .orderBy('week_number')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProgramWeekModel.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList())
        .handleError((Object e) {
      debugPrint('ProgramService: getWeeksStream error for $programId — $e');
    });
  }

  /// Returns enrolled programs paired with a fresh [ProgramModel] fetch.
  /// Useful for My Programs screen — emits on enrollment changes.
  Stream<List<({ProgramEnrollmentModel enrollment, ProgramModel? program})>>
      getEnrolledProgramsStream(String userId) {
    return _enrollments(userId)
        .where('status', isEqualTo: 'active')
        .orderBy('enrolled_at', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final enrollments =
          snap.docs.map(ProgramEnrollmentModel.fromFirestore).toList();
      final pairs = await Future.wait(enrollments.map((e) async {
        try {
          final programDoc = await _programs.doc(e.programId).get();
          final program = programDoc.exists
              ? ProgramModel.fromFirestore(programDoc)
              : null;
          return (enrollment: e, program: program);
        } catch (_) {
          return (enrollment: e, program: null);
        }
      }));
      return pairs.toList();
    }).handleError((Object e) {
      debugPrint('ProgramService: getEnrolledProgramsStream error — $e');
    });
  }

  Future<void> updateProgress(
      String userId, String programId, int currentWeek, int currentSession) async {
    debugPrint(
        'ProgramService: updateProgress $programId week=$currentWeek session=$currentSession');
    await _enrollments(userId).doc(programId).update({
      'current_week': currentWeek,
      'current_session': currentSession,
    });
  }
}
