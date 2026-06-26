import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType { steps, calories, workoutDays, custom }

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int goal;
  final String unit;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final List<String> participantIds;
  final Map<String, int> participantProgress;
  final bool isPublic;
  final DateTime createdAt;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.goal,
    required this.unit,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.participantIds,
    required this.participantProgress,
    required this.isPublic,
    required this.createdAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime _ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    final rawType = json['type'] as String? ?? 'custom';
    final type = ChallengeType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => ChallengeType.custom,
    );

    final rawProgress = (json['participantProgress'] as Map?)?.cast<String, dynamic>() ?? {};
    final progress = rawProgress.map((k, v) => MapEntry(k, (v as num).toInt()));

    return ChallengeModel(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: type,
      goal: (json['goal'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? '',
      startDate: _ts(json['startDate']),
      endDate: _ts(json['endDate']),
      createdBy: json['createdBy'] as String? ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantProgress: progress,
      isPublic: json['isPublic'] as bool? ?? true,
      createdAt: _ts(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type.name,
        'goal': goal,
        'unit': unit,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdBy': createdBy,
        'participantIds': participantIds,
        'participantProgress': participantProgress,
        'isPublic': isPublic,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysRemaining => endDate.difference(DateTime.now()).inDays.clamp(0, 9999);

  int progressOf(String uid) => participantProgress[uid] ?? 0;

  double progressPercent(String uid) =>
      (progressOf(uid) / (goal == 0 ? 1 : goal)).clamp(0.0, 1.0);

  ChallengeModel copyWith({
    List<String>? participantIds,
    Map<String, int>? participantProgress,
  }) {
    return ChallengeModel(
      id: id,
      title: title,
      description: description,
      type: type,
      goal: goal,
      unit: unit,
      startDate: startDate,
      endDate: endDate,
      createdBy: createdBy,
      participantIds: participantIds ?? this.participantIds,
      participantProgress: participantProgress ?? this.participantProgress,
      isPublic: isPublic,
      createdAt: createdAt,
    );
  }
}
