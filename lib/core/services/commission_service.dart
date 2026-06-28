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

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Records a ₺5 referral commission for the code owner when their code is used.
  Future<void> recordReferralCommission({
    required String ownerUid,
    required String refereeUid,
    required String refereeName,
    double amount = 5.0,
  }) async {
    try {
      final model = CommissionModel(
        id: '',
        ownerUid: ownerUid,
        refereeUid: refereeUid,
        refereeName: refereeName,
        type: CommissionType.referral,
        status: CommissionStatus.pending,
        amount: amount,
        description: 'Premium referral: $refereeName',
        createdAt: DateTime.now(),
      );
      await _commissions(ownerUid).add(model.toFirestore());
      debugPrint(
          '[CommissionService] Referral commission ₺$amount recorded for $ownerUid (referee: $refereeUid)');
    } catch (e) {
      debugPrint('[CommissionService] Failed to record referral commission: $e');
    }
  }

  /// Records a coaching session commission for the coach.
  Future<void> recordCoachSessionCommission({
    required String coachUid,
    required String clientUid,
    required String clientName,
    required double amount,
  }) async {
    try {
      final model = CommissionModel(
        id: '',
        ownerUid: coachUid,
        refereeUid: clientUid,
        refereeName: clientName,
        type: CommissionType.coachSession,
        status: CommissionStatus.pending,
        amount: amount,
        description: 'Coaching session: $clientName',
        createdAt: DateTime.now(),
      );
      await _commissions(coachUid).add(model.toFirestore());
      debugPrint(
          '[CommissionService] Coach session commission ₺$amount recorded for $coachUid (client: $clientUid)');
    } catch (e) {
      debugPrint(
          '[CommissionService] Failed to record coach session commission: $e');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Streams the most recent 50 commissions for the given user, newest first.
  Stream<List<CommissionModel>> getCommissionsStream(String uid) {
    return _commissions(uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommissionModel.fromFirestore(doc))
            .toList());
  }

  /// Computes earnings aggregates for the given user.
  Future<EarningsSummaryModel> getEarningsSummary(String uid) async {
    try {
      final snap = await _commissions(uid).get();
      final commissions =
          snap.docs.map((doc) => CommissionModel.fromFirestore(doc)).toList();

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
      await _db
          .collection('users')
          .doc(uid)
          .collection('payout_requests')
          .add({
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
