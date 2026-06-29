import 'package:cloud_firestore/cloud_firestore.dart';

class CoachReviewModel {
  final String coachUid;
  final String reviewerUid;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final int rating;
  final String text;
  final DateTime createdAt;

  const CoachReviewModel({
    required this.coachUid,
    required this.reviewerUid,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory CoachReviewModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CoachReviewModel(
      coachUid: data['coach_uid'] as String? ?? '',
      reviewerUid: doc.id,
      reviewerName: data['reviewer_name'] as String? ?? '',
      reviewerPhotoUrl: data['reviewer_photo_url'] as String?,
      rating: data['rating'] as int? ?? 0,
      text: data['text'] as String? ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coach_uid': coachUid,
        'reviewer_uid': reviewerUid,
        'reviewer_name': reviewerName,
        if (reviewerPhotoUrl != null) 'reviewer_photo_url': reviewerPhotoUrl,
        'rating': rating,
        'text': text,
        'created_at': Timestamp.fromDate(createdAt),
      };

  CoachReviewModel copyWith({
    String? coachUid,
    String? reviewerUid,
    String? reviewerName,
    String? reviewerPhotoUrl,
    int? rating,
    String? text,
    DateTime? createdAt,
  }) =>
      CoachReviewModel(
        coachUid: coachUid ?? this.coachUid,
        reviewerUid: reviewerUid ?? this.reviewerUid,
        reviewerName: reviewerName ?? this.reviewerName,
        reviewerPhotoUrl: reviewerPhotoUrl ?? this.reviewerPhotoUrl,
        rating: rating ?? this.rating,
        text: text ?? this.text,
        createdAt: createdAt ?? this.createdAt,
      );
}
