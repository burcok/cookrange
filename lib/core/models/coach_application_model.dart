import 'package:cloud_firestore/cloud_firestore.dart';

enum CoachApplicationStatus {
  pending,
  approved,
  rejected,
  needsMoreInfo;

  static CoachApplicationStatus fromString(String? s) => switch (s) {
        'approved' => approved,
        'rejected' => rejected,
        'needs_more_info' => needsMoreInfo,
        _ => pending,
      };

  String get value => switch (this) {
        CoachApplicationStatus.pending => 'pending',
        CoachApplicationStatus.approved => 'approved',
        CoachApplicationStatus.rejected => 'rejected',
        CoachApplicationStatus.needsMoreInfo => 'needs_more_info',
      };
}

class CoachApplicationModel {
  final String id;
  final String applicantUid;
  final String displayName;
  final CoachApplicationStatus status;
  final String bio;
  final List<String> specializations;
  final int experienceYears;
  final int hourlyRate;
  final List<String> evidenceUrls;
  final List<String> evidenceLabels;
  final List<Map<String, String>> references;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerNotes;
  final String? reviewerUid;

  const CoachApplicationModel({
    required this.id,
    required this.applicantUid,
    required this.displayName,
    required this.status,
    required this.bio,
    required this.specializations,
    required this.experienceYears,
    required this.hourlyRate,
    required this.evidenceUrls,
    required this.evidenceLabels,
    required this.references,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerNotes,
    this.reviewerUid,
  });

  bool get isPending => status == CoachApplicationStatus.pending;
  bool get isApproved => status == CoachApplicationStatus.approved;
  bool get isRejected => status == CoachApplicationStatus.rejected;
  bool get needsMoreInfo => status == CoachApplicationStatus.needsMoreInfo;

  factory CoachApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CoachApplicationModel(
      id: doc.id,
      applicantUid: d['applicantUid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      status: CoachApplicationStatus.fromString(d['status'] as String?),
      bio: d['bio'] as String? ?? '',
      specializations: List<String>.from(d['specializations'] as List? ?? []),
      experienceYears: (d['experienceYears'] as num?)?.toInt() ?? 0,
      hourlyRate: (d['hourlyRate'] as num?)?.toInt() ?? 0,
      evidenceUrls: List<String>.from(d['evidenceUrls'] as List? ?? []),
      evidenceLabels: List<String>.from(d['evidenceLabels'] as List? ?? []),
      references: (d['references'] as List? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerNotes: d['reviewerNotes'] as String?,
      reviewerUid: d['reviewerUid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'applicantUid': applicantUid,
        'displayName': displayName,
        'status': status.value,
        'bio': bio,
        'specializations': specializations,
        'experienceYears': experienceYears,
        'hourlyRate': hourlyRate,
        'evidenceUrls': evidenceUrls,
        'evidenceLabels': evidenceLabels,
        'references': references,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
        'reviewerNotes': reviewerNotes,
        'reviewerUid': reviewerUid,
      };
}
