import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only view over `gym_attributions/{uid}` (Faz 6 §6.5) — a server-
/// written, immutable record of which gym's invite code a user signed up
/// through. Written exclusively by `applyReferral`'s `type == 'gym'` branch
/// and later `maybeAwardGymCommission` (both `functions/economy.js`, Admin
/// SDK); `firestore.rules` denies every client create/update/delete on this
/// path (see that rule's own comment for why the record itself is never
/// deletable — the gym's already-earned commission must survive a user's
/// own "disconnect" action, which is display-only, see
/// `ReferralService.setAttributionHidden`).
///
/// A user has at most one of these, ever — `applyReferral`'s existing
/// `referral_used` one-code-per-account gate (personal or gym, whichever
/// came first) means this doc can never be overwritten by a second
/// redemption.
class GymAttributionModel {
  final String uid;
  final String gymId;
  final String code;
  final String? coachUid;
  final String? campaign;
  final DateTime? attributedAt;
  final String source; // 'deep_link' | 'manual_entry' | 'in_app'
  final DateTime? firstPremiumAt;
  final double lifetimeCommissionTry;

  const GymAttributionModel({
    required this.uid,
    required this.gymId,
    required this.code,
    this.coachUid,
    this.campaign,
    this.attributedAt,
    required this.source,
    this.firstPremiumAt,
    required this.lifetimeCommissionTry,
  });

  bool get hasConverted => firstPremiumAt != null;

  factory GymAttributionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return GymAttributionModel(
      uid: doc.id,
      gymId: d['gym_id'] as String? ?? '',
      code: d['code'] as String? ?? '',
      coachUid: d['coach_uid'] as String?,
      campaign: d['campaign'] as String?,
      attributedAt: ts(d['attributed_at']),
      source: d['source'] as String? ?? 'in_app',
      firstPremiumAt: ts(d['first_premium_at']),
      lifetimeCommissionTry:
          (d['lifetime_commission_try'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
