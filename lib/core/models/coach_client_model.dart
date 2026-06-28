import 'package:cloud_firestore/cloud_firestore.dart';

enum CoachClientStatus { pending, active, ended }

extension CoachClientStatusX on CoachClientStatus {
  String get firestoreValue => switch (this) {
        CoachClientStatus.pending => 'pending',
        CoachClientStatus.active => 'active',
        CoachClientStatus.ended => 'ended',
      };

  static CoachClientStatus fromString(String? value) => switch (value) {
        'active' => CoachClientStatus.active,
        'ended' => CoachClientStatus.ended,
        _ => CoachClientStatus.pending,
      };
}

class CoachClientModel {
  final String id;
  final String coachUid;
  final String clientUid;
  final String? clientDisplayName;
  final String? clientPhotoURL;
  final CoachClientStatus status;
  final DateTime linkedAt;
  final DateTime? endedAt;
  final int? clientStreak;
  final DateTime? lastLoggedAt;

  const CoachClientModel({
    required this.id,
    required this.coachUid,
    required this.clientUid,
    this.clientDisplayName,
    this.clientPhotoURL,
    required this.status,
    required this.linkedAt,
    this.endedAt,
    this.clientStreak,
    this.lastLoggedAt,
  });

  bool get isActive => status == CoachClientStatus.active;

  int get daysSinceLastLog => lastLoggedAt == null
      ? 999
      : DateTime.now().difference(lastLoggedAt!).inDays;

  bool get isAtRisk => isActive && daysSinceLastLog >= 3;

  factory CoachClientModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CoachClientModel(
      id: doc.id,
      coachUid: data['coach_uid'] as String? ?? '',
      clientUid: data['client_uid'] as String? ?? '',
      clientDisplayName: data['client_display_name'] as String?,
      clientPhotoURL: data['client_photo_url'] as String?,
      status: CoachClientStatusX.fromString(data['status'] as String?),
      linkedAt: (data['linked_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['ended_at'] as Timestamp?)?.toDate(),
      clientStreak: data['client_streak'] as int?,
      lastLoggedAt: (data['last_logged_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coach_uid': coachUid,
        'client_uid': clientUid,
        'client_display_name': clientDisplayName,
        'client_photo_url': clientPhotoURL,
        'status': status.firestoreValue,
        'linked_at': Timestamp.fromDate(linkedAt),
        'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'client_streak': clientStreak,
        'last_logged_at':
            lastLoggedAt != null ? Timestamp.fromDate(lastLoggedAt!) : null,
      };

  CoachClientModel copyWith({
    String? id,
    String? coachUid,
    String? clientUid,
    String? clientDisplayName,
    String? clientPhotoURL,
    CoachClientStatus? status,
    DateTime? linkedAt,
    DateTime? endedAt,
    int? clientStreak,
    DateTime? lastLoggedAt,
  }) =>
      CoachClientModel(
        id: id ?? this.id,
        coachUid: coachUid ?? this.coachUid,
        clientUid: clientUid ?? this.clientUid,
        clientDisplayName: clientDisplayName ?? this.clientDisplayName,
        clientPhotoURL: clientPhotoURL ?? this.clientPhotoURL,
        status: status ?? this.status,
        linkedAt: linkedAt ?? this.linkedAt,
        endedAt: endedAt ?? this.endedAt,
        clientStreak: clientStreak ?? this.clientStreak,
        lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
      );
}
