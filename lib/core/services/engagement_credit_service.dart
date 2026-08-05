import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/credit_restriction_model.dart';

/// Read-only view over Faz 5 §5.2's received-engagement credit system.
///
/// ALL logic — distinct-account thresholds, reciprocity-ring/duplicate-
/// content anti-abuse weighting, the premium 2x multiplier, and shadow-
/// restriction — is server-computed (`functions/engagement_credit.js`) and
/// lands as bonus units in the EXISTING `ai_credits/{uid}.bonus` pool
/// (already surfaced by `AiCreditService`/`AiCreditModel` — there is no
/// separate spendable balance to show here). This service exists only to
/// show the ONE piece of state that isn't already covered by
/// `AiCreditService`: whether this account is currently shadow-restricted,
/// so the app can offer the appeal path (see `CreditRestrictionScreen`).
class EngagementCreditService {
  static final EngagementCreditService _instance =
      EngagementCreditService._internal();
  factory EngagementCreditService() => _instance;
  EngagementCreditService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live shadow-restriction state for [uid].
  Stream<CreditRestrictionModel> watchRestrictionState(String uid) {
    return _db
        .collection('credit_restrictions')
        .doc(uid)
        .snapshots()
        .map((snap) => CreditRestrictionModel.fromFirestore(snap.data()));
  }
}
