import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a Streak Squad — a small friend group sharing a streak goal.
///
/// Stored at: `squads/{squadId}`
class StreakSquadModel {
  final String squadId;
  final String name;
  final String creatorUid;
  final List<String> memberUids;
  final int streakGoal;
  final String inviteCode;
  final Timestamp createdAt;

  const StreakSquadModel({
    required this.squadId,
    required this.name,
    required this.creatorUid,
    required this.memberUids,
    required this.streakGoal,
    required this.inviteCode,
    required this.createdAt,
  });

  factory StreakSquadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StreakSquadModel(
      squadId: doc.id,
      name: data['name'] as String? ?? '',
      creatorUid: data['creatorUid'] as String? ?? '',
      memberUids: List<String>.from(data['memberUids'] as List? ?? []),
      streakGoal: (data['streakGoal'] as num?)?.toInt() ?? 7,
      inviteCode: data['inviteCode'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'creatorUid': creatorUid,
        'memberUids': memberUids,
        'streakGoal': streakGoal,
        'inviteCode': inviteCode,
        'createdAt': createdAt,
      };

  StreakSquadModel copyWith({
    String? squadId,
    String? name,
    String? creatorUid,
    List<String>? memberUids,
    int? streakGoal,
    String? inviteCode,
    Timestamp? createdAt,
  }) =>
      StreakSquadModel(
        squadId: squadId ?? this.squadId,
        name: name ?? this.name,
        creatorUid: creatorUid ?? this.creatorUid,
        memberUids: memberUids ?? this.memberUids,
        streakGoal: streakGoal ?? this.streakGoal,
        inviteCode: inviteCode ?? this.inviteCode,
        createdAt: createdAt ?? this.createdAt,
      );
}
