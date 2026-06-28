import 'package:cloud_firestore/cloud_firestore.dart';

enum GymApplicationStatus {
  pending,
  approved,
  rejected;

  static GymApplicationStatus fromString(String? s) => switch (s) {
        'approved' => approved,
        'rejected' => rejected,
        _ => pending,
      };

  String get value => switch (this) {
        GymApplicationStatus.pending => 'pending',
        GymApplicationStatus.approved => 'approved',
        GymApplicationStatus.rejected => 'rejected',
      };
}

class GymApplicationModel {
  final String id;
  final String applicantUid;
  final String gymName;
  final String address;
  final String city;
  final String description;
  final String? businessDocUrl;
  final List<String> photoUrls;
  final String contactPhone;
  final List<String> tags;
  final GymApplicationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerNotes;
  final String? reviewerUid;

  const GymApplicationModel({
    required this.id,
    required this.applicantUid,
    required this.gymName,
    required this.address,
    required this.city,
    required this.description,
    this.businessDocUrl,
    required this.photoUrls,
    required this.contactPhone,
    required this.tags,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerNotes,
    this.reviewerUid,
  });

  bool get isPending => status == GymApplicationStatus.pending;
  bool get isApproved => status == GymApplicationStatus.approved;
  bool get isRejected => status == GymApplicationStatus.rejected;

  factory GymApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GymApplicationModel(
      id: doc.id,
      applicantUid: d['applicantUid'] as String? ?? '',
      gymName: d['gymName'] as String? ?? '',
      address: d['address'] as String? ?? '',
      city: d['city'] as String? ?? '',
      description: d['description'] as String? ?? '',
      businessDocUrl: d['businessDocUrl'] as String?,
      photoUrls: List<String>.from(d['photoUrls'] as List? ?? []),
      contactPhone: d['contactPhone'] as String? ?? '',
      tags: List<String>.from(d['tags'] as List? ?? []),
      status: GymApplicationStatus.fromString(d['status'] as String?),
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerNotes: d['reviewerNotes'] as String?,
      reviewerUid: d['reviewerUid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'applicantUid': applicantUid,
        'gymName': gymName,
        'address': address,
        'city': city,
        'description': description,
        'businessDocUrl': businessDocUrl,
        'photoUrls': photoUrls,
        'contactPhone': contactPhone,
        'tags': tags,
        'status': status.value,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
        'reviewerNotes': reviewerNotes,
        'reviewerUid': reviewerUid,
      };
}
