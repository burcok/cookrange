import 'package:cloud_firestore/cloud_firestore.dart';
import 'gym_presence_model.dart' show PresenceSource, PresenceSourceX;

/// Why a presence session was closed.
enum PresenceEndReason { exit, timeout, manual }

extension PresenceEndReasonX on PresenceEndReason {
  String get firestoreValue => name;

  static PresenceEndReason fromString(String? v) => switch (v) {
        'timeout' => PresenceEndReason.timeout,
        'manual' => PresenceEndReason.manual,
        _ => PresenceEndReason.exit,
      };
}

/// `gyms/{gymId}/presence_sessions/{autoId}` — a closed, immutable record of
/// one visit. Faz 1 §1.4/1.5: written once by the `recordPresenceEvent`
/// Cloud Function when a live [GymPresenceModel] doc closes (exit debounce
/// elapsed, or a stale dwell timed out); firestore.rules denies
/// create/update/delete from every client, so this is read-only here too.
/// Backs the leaderboard, gym wars, and analytics with server-verified
/// visits instead of client-claimed ones.
class PresenceSessionModel {
  final String id;
  final String uid;
  final DateTime enteredAt;
  final DateTime exitedAt;
  final int durationMinutes;
  final PresenceSource source;
  final PresenceEndReason endedBy;

  const PresenceSessionModel({
    required this.id,
    required this.uid,
    required this.enteredAt,
    required this.exitedAt,
    required this.durationMinutes,
    required this.source,
    required this.endedBy,
  });

  factory PresenceSessionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime toDate(dynamic ts) =>
        ts is Timestamp ? ts.toDate() : DateTime.now();
    return PresenceSessionModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      enteredAt: toDate(d['entered_at']),
      exitedAt: toDate(d['exited_at']),
      durationMinutes: d['duration_minutes'] as int? ?? 0,
      source: PresenceSourceX.fromString(d['source'] as String?),
      endedBy: PresenceEndReasonX.fromString(d['ended_by'] as String?),
    );
  }
}
