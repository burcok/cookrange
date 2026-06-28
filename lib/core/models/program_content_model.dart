import 'package:cloud_firestore/cloud_firestore.dart';

enum ProgramSessionType { workout, rest, meal, video, article }

extension ProgramSessionTypeX on ProgramSessionType {
  String get firestoreValue => name;
  String get locKey => 'program.session_type.$name';
  String get emoji => switch (this) {
        ProgramSessionType.workout => '🏋️',
        ProgramSessionType.rest => '😴',
        ProgramSessionType.meal => '🥗',
        ProgramSessionType.video => '▶️',
        ProgramSessionType.article => '📖',
      };

  static ProgramSessionType fromString(String? v) => switch (v) {
        'rest' => ProgramSessionType.rest,
        'meal' => ProgramSessionType.meal,
        'video' => ProgramSessionType.video,
        'article' => ProgramSessionType.article,
        _ => ProgramSessionType.workout,
      };
}

class ProgramSessionModel {
  final String title;
  final ProgramSessionType type;
  final int? durationMinutes;
  final String? description;

  const ProgramSessionModel({
    required this.title,
    required this.type,
    this.durationMinutes,
    this.description,
  });

  factory ProgramSessionModel.fromMap(Map<String, dynamic> m) =>
      ProgramSessionModel(
        title: m['title'] as String? ?? '',
        type: ProgramSessionTypeX.fromString(m['type'] as String?),
        durationMinutes: m['duration_minutes'] as int?,
        description: m['description'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.firestoreValue,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (description != null) 'description': description,
      };
}

class ProgramDayModel {
  final int dayNumber;
  final String title;
  final List<ProgramSessionModel> sessions;

  const ProgramDayModel({
    required this.dayNumber,
    required this.title,
    required this.sessions,
  });

  factory ProgramDayModel.fromMap(Map<String, dynamic> m) => ProgramDayModel(
        dayNumber: m['day_number'] as int? ?? 1,
        title: m['title'] as String? ?? '',
        sessions: (m['sessions'] as List? ?? [])
            .map((s) =>
                ProgramSessionModel.fromMap(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'day_number': dayNumber,
        'title': title,
        'sessions': sessions.map((s) => s.toMap()).toList(),
      };
}

/// Stored at `programs/{id}/weeks/{weekId}`.
class ProgramWeekModel {
  final String id;
  final int weekNumber;
  final String title;
  final String? description;
  final List<ProgramDayModel> days;

  const ProgramWeekModel({
    required this.id,
    required this.weekNumber,
    required this.title,
    this.description,
    required this.days,
  });

  factory ProgramWeekModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ProgramWeekModel(
      id: doc.id,
      weekNumber: d['week_number'] as int? ?? 1,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      days: (d['days'] as List? ?? [])
          .map((day) =>
              ProgramDayModel.fromMap(day as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'week_number': weekNumber,
        'title': title,
        if (description != null) 'description': description,
        'days': days.map((d) => d.toMap()).toList(),
      };
}
