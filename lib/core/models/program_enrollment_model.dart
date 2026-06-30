import 'package:cloud_firestore/cloud_firestore.dart';

enum EnrollmentStatus { active, completed, abandoned }

extension EnrollmentStatusX on EnrollmentStatus {
  String get firestoreValue => name;

  static EnrollmentStatus fromString(String? v) => switch (v) {
        'completed' => EnrollmentStatus.completed,
        'abandoned' => EnrollmentStatus.abandoned,
        _ => EnrollmentStatus.active,
      };
}

/// Stored at `users/{uid}/program_enrollments/{programId}`.
class ProgramEnrollmentModel {
  final String id;
  final String userUid;
  final String programId;
  final String programTitle;
  final String coachUid;
  final EnrollmentStatus status;
  final int currentWeek;
  final int currentSession;
  final int totalWeeks;
  final DateTime enrolledAt;
  final DateTime? completedAt;

  const ProgramEnrollmentModel({
    required this.id,
    required this.userUid,
    required this.programId,
    required this.programTitle,
    required this.coachUid,
    required this.status,
    required this.currentWeek,
    required this.currentSession,
    required this.totalWeeks,
    required this.enrolledAt,
    this.completedAt,
  });

  /// 0.0–1.0. Clamped so it never overflows past completion.
  double get progressPercent {
    if (totalWeeks <= 0) return 0.0;
    return (currentWeek / totalWeeks).clamp(0.0, 1.0);
  }

  factory ProgramEnrollmentModel.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return ProgramEnrollmentModel(
      id: doc.id,
      userUid: d['user_uid'] as String? ?? '',
      programId: d['program_id'] as String? ?? doc.id,
      programTitle: d['program_title'] as String? ?? '',
      coachUid: d['coach_uid'] as String? ?? '',
      status: EnrollmentStatusX.fromString(d['status'] as String?),
      currentWeek: d['current_week'] as int? ?? 1,
      currentSession: d['current_session'] as int? ?? 1,
      totalWeeks: d['total_weeks'] as int? ?? 4,
      enrolledAt: ts(d['enrolled_at']),
      completedAt: d['completed_at'] != null ? ts(d['completed_at']) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'user_uid': userUid,
        'program_id': programId,
        'program_title': programTitle,
        'coach_uid': coachUid,
        'status': status.firestoreValue,
        'current_week': currentWeek,
        'current_session': currentSession,
        'total_weeks': totalWeeks,
        'enrolled_at': Timestamp.fromDate(enrolledAt),
        if (completedAt != null)
          'completed_at': Timestamp.fromDate(completedAt!),
      };

  ProgramEnrollmentModel copyWith({
    EnrollmentStatus? status,
    int? currentWeek,
    int? currentSession,
    DateTime? completedAt,
  }) =>
      ProgramEnrollmentModel(
        id: id,
        userUid: userUid,
        programId: programId,
        programTitle: programTitle,
        coachUid: coachUid,
        status: status ?? this.status,
        currentWeek: currentWeek ?? this.currentWeek,
        currentSession: currentSession ?? this.currentSession,
        totalWeeks: totalWeeks,
        enrolledAt: enrolledAt,
        completedAt: completedAt ?? this.completedAt,
      );
}
