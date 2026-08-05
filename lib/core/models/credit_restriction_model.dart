import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only view of `credit_restrictions/{uid}` (Faz 5 §5.2 — "gölge
/// kısıtlama"). All writes are server/admin-only
/// (`functions/engagement_credit.js`'s `bumpSuspicionFlag`, or an admin
/// upholding an appeal — see `AdminService.resolveModerationAppeal`);
/// firestore.rules denies every other client write. The client only ever
/// DISPLAYS this state and offers the appeal path — it can never set or
/// clear the flag itself, exactly like `AiCreditModel`'s relationship to
/// the server-only `ai_credits/{uid}` ledger.
///
/// Being shadow-restricted has NO effect on this account's own content
/// visibility to others — only on whether IT keeps accumulating received-
/// engagement credit. `latestEntryId` is the matching
/// `users/{uid}/credit_moderation/{autoId}` log entry id, used as the
/// appeal doc's own id (see `ModerationAppealService.fileCreditRestrictionAppeal`).
class CreditRestrictionModel {
  final bool isShadowRestricted;
  final String? reason;
  final String? latestEntryId;
  final DateTime? restrictedAt;

  const CreditRestrictionModel({
    this.isShadowRestricted = false,
    this.reason,
    this.latestEntryId,
    this.restrictedAt,
  });

  factory CreditRestrictionModel.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const CreditRestrictionModel();
    final restrictedAtRaw = data['restricted_at'];
    return CreditRestrictionModel(
      isShadowRestricted: data['is_shadow_restricted'] == true,
      reason: data['reason'] as String?,
      latestEntryId: data['latest_entry_id'] as String?,
      restrictedAt:
          restrictedAtRaw is Timestamp ? restrictedAtRaw.toDate() : null,
    );
  }
}
