import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/commission_model.dart';
import '../models/earnings_summary_model.dart';

class CommissionService {
  static final CommissionService _i = CommissionService._();
  factory CommissionService() => _i;
  CommissionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _commissions(String uid) =>
      _db.collection('users').doc(uid).collection('commissions');

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Streams the most recent 50 commissions for the given user, newest first.
  ///
  /// [types], when non-null, scopes the stream to only those commission
  /// types (Faz 6 §6.6 — `GymEarningsScreen` passes `[CommissionType.
  /// gymPremiumShare]` so a gym owner's panel shows only gym-sourced revenue,
  /// never any personal referral/coaching commissions mixed into the same
  /// `users/{uid}/commissions` wallet). Filtered client-side after the same
  /// bounded `.limit(50)` fetch, not via an extra Firestore `where` — this
  /// collection is a single user's own commission history (never large
  /// enough to need a composite index for this), and every existing caller
  /// (personal `AffiliateEarningsScreen`) keeps working unfiltered.
  Stream<List<CommissionModel>> getCommissionsStream(String uid,
      {List<CommissionType>? types}) {
    return _commissions(uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommissionModel.fromFirestore(doc))
            .where((c) => types == null || types.contains(c.type))
            .toList());
  }

  /// Computes earnings aggregates for the given user, optionally scoped to
  /// [types] (see [getCommissionsStream]'s doc comment).
  Future<EarningsSummaryModel> getEarningsSummary(String uid,
      {List<CommissionType>? types}) async {
    try {
      final snap = await _commissions(uid).get();
      final commissions = snap.docs
          .map((doc) => CommissionModel.fromFirestore(doc))
          .where((c) => types == null || types.contains(c.type))
          .toList();

      double totalEarned = 0;
      double pendingAmount = 0;
      double paidAmount = 0;
      int referralCount = 0;
      int coachSessionCount = 0;

      for (final c in commissions) {
        if (c.status != CommissionStatus.rejected) {
          totalEarned += c.amount;
        }
        if (c.isPending || c.status == CommissionStatus.approved) {
          pendingAmount += c.amount;
        }
        if (c.isPaid) {
          paidAmount += c.amount;
        }
        if (c.type == CommissionType.referral) referralCount++;
        if (c.type == CommissionType.coachSession) coachSessionCount++;
      }

      debugPrint(
          '[CommissionService] Summary for $uid: total=₺$totalEarned pending=₺$pendingAmount paid=₺$paidAmount');
      return EarningsSummaryModel(
        totalEarned: totalEarned,
        pendingAmount: pendingAmount,
        paidAmount: paidAmount,
        referralCount: referralCount,
        coachSessionCount: coachSessionCount,
      );
    } catch (e) {
      debugPrint('[CommissionService] Failed to compute earnings summary: $e');
      return EarningsSummaryModel.empty;
    }
  }

  // ── Payout request ─────────────────────────────────────────────────────────

  /// Placeholder — records a payout request. No actual payment is processed.
  Future<void> requestPayout(String uid) async {
    try {
      final summary = await getEarningsSummary(uid);
      await _db.collection('users').doc(uid).collection('payout_requests').add({
        'requested_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'total': summary.pendingAmount,
      });
      debugPrint('[CommissionService] Payout requested for $uid '
          '(amount: ₺${summary.pendingAmount})');
    } catch (e) {
      debugPrint('[CommissionService] Failed to record payout request: $e');
    }
  }
}
