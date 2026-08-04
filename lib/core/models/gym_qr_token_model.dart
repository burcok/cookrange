import 'package:cloud_firestore/cloud_firestore.dart';

/// The gym's current QR check-in token — `gyms/{gymId}/private/qr_token`.
///
/// Faz 0 §0.7: split out of [GymModel] (which used to carry `qrToken`/
/// `qrTokenExpiresAt` straight off the public `gyms/{gymId}` doc — readable
/// by any authenticated user, defeating the "you must scan the printed QR"
/// premise). This doc is owner/admin-read-only (firestore.rules); members
/// never read it, they obtain the token by scanning the rendered image, and
/// `validateGymCheckin` (Cloud Function) is the only thing that checks a
/// scanned value against it.
class GymQrToken {
  final String? token;
  final DateTime? expiresAt;

  const GymQrToken({this.token, this.expiresAt});

  static const empty = GymQrToken();

  factory GymQrToken.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return empty;
    final d = doc.data() ?? {};
    return GymQrToken(
      token: d['token'] as String?,
      expiresAt: d['expires_at'] is Timestamp
          ? (d['expires_at'] as Timestamp).toDate()
          : null,
    );
  }

  bool get isValid =>
      token != null && expiresAt != null && expiresAt!.isAfter(DateTime.now());
}
