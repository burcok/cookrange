import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType { steps, calories, workoutDays, custom }

enum ChallengeDifficulty { easy, medium, hard }

extension ChallengeDifficultyX on ChallengeDifficulty {
  String get locKey => 'challenge.difficulty.$name';
}

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final int goal;
  final String unit;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final List<String> participantIds;
  final Map<String, int> participantProgress;
  final bool isPublic;
  final DateTime createdAt;

  // Sponsor fields (all optional — existing challenges without these work fine)
  final String? sponsorName;
  final String? sponsorLogoUrl;
  final String? sponsorReward;
  final String? sponsorWebUrl;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.difficulty = ChallengeDifficulty.medium,
    required this.goal,
    required this.unit,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.participantIds,
    required this.participantProgress,
    required this.isPublic,
    required this.createdAt,
    this.sponsorName,
    this.sponsorLogoUrl,
    this.sponsorReward,
    this.sponsorWebUrl,
  });

  bool get isSponsored => sponsorName != null && sponsorName!.isNotEmpty;

  factory ChallengeModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    final rawType = json['type'] as String? ?? 'custom';
    final type = ChallengeType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => ChallengeType.custom,
    );

    final rawDifficulty = json['difficulty'] as String? ?? 'medium';
    final difficulty = ChallengeDifficulty.values.firstWhere(
      (d) => d.name == rawDifficulty,
      orElse: () => ChallengeDifficulty.medium,
    );

    final rawProgress = (json['participantProgress'] as Map?)?.cast<String, dynamic>() ?? {};
    final progress = rawProgress.map((k, v) => MapEntry(k, (v as num).toInt()));

    return ChallengeModel(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: type,
      difficulty: difficulty,
      goal: (json['goal'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? '',
      startDate: ts(json['startDate']),
      endDate: ts(json['endDate']),
      createdBy: json['createdBy'] as String? ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantProgress: progress,
      isPublic: json['isPublic'] as bool? ?? true,
      createdAt: ts(json['createdAt']),
      sponsorName: json['sponsor_name'] as String?,
      sponsorLogoUrl: json['sponsor_logo_url'] as String?,
      sponsorReward: json['sponsor_reward'] as String?,
      sponsorWebUrl: json['sponsor_web_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type.name,
        'difficulty': difficulty.name,
        'goal': goal,
        'unit': unit,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdBy': createdBy,
        'participantIds': participantIds,
        'participantProgress': participantProgress,
        'isPublic': isPublic,
        'createdAt': Timestamp.fromDate(createdAt),
        if (sponsorName != null) 'sponsor_name': sponsorName,
        if (sponsorLogoUrl != null) 'sponsor_logo_url': sponsorLogoUrl,
        if (sponsorReward != null) 'sponsor_reward': sponsorReward,
        if (sponsorWebUrl != null) 'sponsor_web_url': sponsorWebUrl,
      };

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysRemaining => endDate.difference(DateTime.now()).inDays.clamp(0, 9999);

  int progressOf(String uid) => participantProgress[uid] ?? 0;

  double progressPercent(String uid) =>
      (progressOf(uid) / (goal == 0 ? 1 : goal)).clamp(0.0, 1.0);

  ChallengeModel copyWith({
    List<String>? participantIds,
    Map<String, int>? participantProgress,
    String? sponsorName,
    String? sponsorLogoUrl,
    String? sponsorReward,
    String? sponsorWebUrl,
  }) {
    return ChallengeModel(
      id: id,
      title: title,
      description: description,
      type: type,
      difficulty: difficulty,
      goal: goal,
      unit: unit,
      startDate: startDate,
      endDate: endDate,
      createdBy: createdBy,
      participantIds: participantIds ?? this.participantIds,
      participantProgress: participantProgress ?? this.participantProgress,
      isPublic: isPublic,
      createdAt: createdAt,
      sponsorName: sponsorName ?? this.sponsorName,
      sponsorLogoUrl: sponsorLogoUrl ?? this.sponsorLogoUrl,
      sponsorReward: sponsorReward ?? this.sponsorReward,
      sponsorWebUrl: sponsorWebUrl ?? this.sponsorWebUrl,
    );
  }
}
