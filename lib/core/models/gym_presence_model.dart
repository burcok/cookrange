import 'package:cloud_firestore/cloud_firestore.dart';

/// How a presence record was established.
enum PresenceSource { geofence, manualConfirm, qr }

extension PresenceSourceX on PresenceSource {
  String get firestoreValue => switch (this) {
        PresenceSource.geofence => 'geofence',
        PresenceSource.manualConfirm => 'manual_confirm',
        PresenceSource.qr => 'qr',
      };

  static PresenceSource fromString(String? v) => switch (v) {
        'manual_confirm' => PresenceSource.manualConfirm,
        'qr' => PresenceSource.qr,
        _ => PresenceSource.geofence,
      };
}

/// `gyms/{gymId}/presence/{uid}` — a member's live "currently inside" record.
/// Faz 1 §1.4/1.5: only exists while the member is inside; written solely by
/// the `recordPresenceEvent` Cloud Function (Admin SDK) on enter and removed
/// on exit/timeout — firestore.rules denies every client write on this path.
/// No raw latitude/longitude ever — the audit specifically praised
/// [CheckInModel] for never carrying coordinates, and this model preserves
/// that: only the gym-relative facts (when, how, still-here-as-of) exist.
class GymPresenceModel {
  final String uid;
  final DateTime enteredAt;
  final PresenceSource source;
  final DateTime lastSeenAt;
  final DateTime expiresAt;
  final String? displayName;
  final String? photoURL;

  const GymPresenceModel({
    required this.uid,
    required this.enteredAt,
    required this.source,
    required this.lastSeenAt,
    required this.expiresAt,
    this.displayName,
    this.photoURL,
  });

  factory GymPresenceModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime toDate(dynamic ts) =>
        ts is Timestamp ? ts.toDate() : DateTime.now();
    return GymPresenceModel(
      uid: doc.id,
      enteredAt: toDate(d['entered_at']),
      source: PresenceSourceX.fromString(d['source'] as String?),
      lastSeenAt: toDate(d['last_seen_at']),
      expiresAt: toDate(d['expires_at']),
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
    );
  }

  bool get isExpired => expiresAt.isBefore(DateTime.now());
}
