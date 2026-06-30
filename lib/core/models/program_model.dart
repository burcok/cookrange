import 'package:cloud_firestore/cloud_firestore.dart';

enum ProgramDifficulty { beginner, intermediate, advanced }

enum ProgramCategory {
  weightLoss,
  muscleGain,
  endurance,
  flexibility,
  nutrition,
  lifestyle,
}

extension ProgramDifficultyX on ProgramDifficulty {
  String get firestoreValue => name;
  String get locKey => 'program.difficulty.$name';

  static ProgramDifficulty fromString(String? v) => switch (v) {
        'intermediate' => ProgramDifficulty.intermediate,
        'advanced' => ProgramDifficulty.advanced,
        _ => ProgramDifficulty.beginner,
      };
}

extension ProgramCategoryX on ProgramCategory {
  String get firestoreValue => name;
  String get locKey => 'program.category.$name';

  static ProgramCategory fromString(String? v) => switch (v) {
        'muscleGain' => ProgramCategory.muscleGain,
        'endurance' => ProgramCategory.endurance,
        'flexibility' => ProgramCategory.flexibility,
        'nutrition' => ProgramCategory.nutrition,
        'lifestyle' => ProgramCategory.lifestyle,
        _ => ProgramCategory.weightLoss,
      };
}

class ProgramModel {
  final String id;
  final String coachUid;
  final String coachName;
  final String? coachPhotoUrl;
  final String title;
  final String description;
  final ProgramDifficulty difficulty;
  final ProgramCategory category;
  final int durationWeeks;
  final int sessionsPerWeek;
  final double price;
  final String? coverImageUrl;
  final List<String> tags;
  final List<String> highlights;
  final bool isPublished;
  // 'draft' | 'pending' | 'approved' | 'rejected'
  final String status;
  final int enrollmentCount;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProgramModel({
    required this.id,
    required this.coachUid,
    required this.coachName,
    this.coachPhotoUrl,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.category,
    required this.durationWeeks,
    required this.sessionsPerWeek,
    required this.price,
    this.coverImageUrl,
    required this.tags,
    required this.highlights,
    required this.isPublished,
    this.status = 'approved',
    required this.enrollmentCount,
    required this.rating,
    required this.ratingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFree => price == 0.0;
  bool get isPaid => price > 0.0;
  String get priceDisplay => isFree ? 'Free' : '₺${price.toStringAsFixed(0)}';

  factory ProgramModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return ProgramModel(
      id: doc.id,
      coachUid: d['coach_uid'] as String? ?? '',
      coachName: d['coach_name'] as String? ?? '',
      coachPhotoUrl: d['coach_photo_url'] as String?,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      difficulty: ProgramDifficultyX.fromString(d['difficulty'] as String?),
      category: ProgramCategoryX.fromString(d['category'] as String?),
      durationWeeks: d['duration_weeks'] as int? ?? 4,
      sessionsPerWeek: d['sessions_per_week'] as int? ?? 3,
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      coverImageUrl: d['cover_image_url'] as String?,
      tags: List<String>.from(d['tags'] as List? ?? []),
      highlights: List<String>.from(d['highlights'] as List? ?? []),
      isPublished: d['is_published'] as bool? ?? false,
      status: d['status'] as String? ?? 'approved',
      enrollmentCount: d['enrollment_count'] as int? ?? 0,
      rating: (d['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: d['rating_count'] as int? ?? 0,
      createdAt: ts(d['created_at']),
      updatedAt: ts(d['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coach_uid': coachUid,
        'coach_name': coachName,
        if (coachPhotoUrl != null) 'coach_photo_url': coachPhotoUrl,
        'title': title,
        'description': description,
        'difficulty': difficulty.firestoreValue,
        'category': category.firestoreValue,
        'duration_weeks': durationWeeks,
        'sessions_per_week': sessionsPerWeek,
        'price': price,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        'tags': tags,
        'highlights': highlights,
        'is_published': isPublished,
        'status': status,
        'enrollment_count': enrollmentCount,
        'rating': rating,
        'rating_count': ratingCount,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  ProgramModel copyWith({
    bool? isPublished,
    String? status,
    int? enrollmentCount,
    String? coverImageUrl,
  }) =>
      ProgramModel(
        id: id,
        coachUid: coachUid,
        coachName: coachName,
        coachPhotoUrl: coachPhotoUrl,
        title: title,
        description: description,
        difficulty: difficulty,
        category: category,
        durationWeeks: durationWeeks,
        sessionsPerWeek: sessionsPerWeek,
        price: price,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        tags: tags,
        highlights: highlights,
        isPublished: isPublished ?? this.isPublished,
        status: status ?? this.status,
        enrollmentCount: enrollmentCount ?? this.enrollmentCount,
        rating: rating,
        ratingCount: ratingCount,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
