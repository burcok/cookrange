import 'package:cloud_firestore/cloud_firestore.dart';

/// A gym-issued referral/invite code — `referrals/{code}` with `type: 'gym'`
/// (Faz 6 §6.1).
///
/// Distinct from [GymQrToken] (`gyms/{gymId}/private/qr_token`), which is a
/// rotating check-in secret scanned in-app by people who ALREADY have
/// Cookrange installed and are physically at the gym. This code is for
/// acquiring NEW app users: it's printed on a poster or shared on social
/// media, scanned by a bare camera app (no in-app scanner involved), and
/// resolves to `https://cookrangeapp.com/invite/{code}` — the same link
/// format `SharingService.shareReferral` already shares for personal codes.
/// The page behind that link is separate work in another repo (Faz 6 §6.2);
/// this model only needs the code to be valid and generatable.
class GymInviteCodeModel {
  final String code;
  final String gymId;
  final String ownerUid;
  final String? campaign;
  final String? locationNote;
  final DateTime? printedAt;
  final DateTime createdAt;
  final int maxUses;
  final int usedCount;

  const GymInviteCodeModel({
    required this.code,
    required this.gymId,
    required this.ownerUid,
    this.campaign,
    this.locationNote,
    this.printedAt,
    required this.createdAt,
    required this.maxUses,
    required this.usedCount,
  });

  factory GymInviteCodeModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final usedBy = d['used_by_uids'] as List? ?? const [];
    return GymInviteCodeModel(
      code: doc.id,
      gymId: d['gym_id'] as String? ?? '',
      ownerUid: d['owner_uid'] as String? ?? '',
      campaign: d['campaign'] as String?,
      locationNote: d['location_note'] as String?,
      printedAt: d['printed_at'] is Timestamp
          ? (d['printed_at'] as Timestamp).toDate()
          : null,
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      maxUses: d['max_uses'] as int? ?? 0,
      usedCount: usedBy.length,
    );
  }

  /// The exact link format `SharingService.shareReferral` uses for personal
  /// codes — kept in sync manually (that default lives in a private param
  /// default in sharing_service.dart, not a shared constant).
  String get inviteUrl => 'https://cookrangeapp.com/invite/$code';

  bool get isPrinted => printedAt != null;

  /// Distinguishes "front desk QR" from "Coach Ahmet's Instagram code" from
  /// "March campaign" in the management list — falls back to the raw code so
  /// a code created with both fields blank still reads as something.
  String displayLabel() {
    final parts = [campaign, locationNote]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim());
    return parts.isEmpty ? code : parts.join(' · ');
  }
}
