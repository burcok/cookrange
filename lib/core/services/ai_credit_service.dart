import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_credit_model.dart';

/// Singleton service that tracks and gates monthly AI usage per user.
///
/// Free users get [AiCreditModel.freeMonthlyLimit] calls/month.
/// Premium/Pro users are unlimited — pass `isPremium: true` to [checkAndConsume].
///
/// Firestore fields on `users/{uid}`:
///   - `ai_credits_used`     — int, count of calls this period
///   - `ai_credits_reset_at` — Timestamp, when the counter resets
class AiCreditService {
  static final AiCreditService _i = AiCreditService._();
  factory AiCreditService() => _i;
  AiCreditService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Reads the current credit state for [uid], auto-resetting if the period
  /// has expired.
  Future<AiCreditModel> getCredits(String uid) async {
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null) {
      await _resetCredits(uid);
      return AiCreditModel.fresh();
    }

    final resetAtRaw = data['ai_credits_reset_at'];
    if (resetAtRaw == null) {
      await _resetCredits(uid);
      return AiCreditModel.fresh();
    }

    final resetAt = resetAtRaw is Timestamp
        ? resetAtRaw.toDate()
        : DateTime.now().subtract(const Duration(seconds: 1));

    if (DateTime.now().isAfter(resetAt)) {
      await _resetCredits(uid);
      return AiCreditModel.fresh();
    }

    return AiCreditModel.fromFirestore(data);
  }

  /// Checks whether the user can make an AI call and, if allowed, consumes one
  /// credit atomically.
  ///
  /// Returns `true` when the call is permitted (and the credit is consumed).
  /// Returns `false` when the free quota is exhausted.
  ///
  /// Premium/Pro users always get `true` but still have their usage tracked.
  Future<bool> checkAndConsume(String uid, bool isPremium) async {
    if (isPremium) {
      await consumeCredit(uid);
      return true;
    }

    final credits = await getCredits(uid);
    if (credits.isExhausted) {
      debugPrint(
          '[AiCreditService] uid=$uid — quota exhausted '
          '(${credits.used}/${AiCreditModel.freeMonthlyLimit})');
      return false;
    }

    await consumeCredit(uid);
    return true;
  }

  /// Increments `ai_credits_used` by 1. Fire-and-forget safe.
  Future<void> consumeCredit(String uid) async {
    debugPrint('[AiCreditService] consuming credit for uid=$uid');
    await _users.doc(uid).set(
      {'ai_credits_used': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Live stream of the user's credit state — used by [AiCreditBadge].
  Stream<AiCreditModel> getCreditsStream(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null ||
          !data.containsKey('ai_credits_used') ||
          !data.containsKey('ai_credits_reset_at')) {
        return AiCreditModel.fresh();
      }
      return AiCreditModel.fromFirestore(data);
    });
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _resetCredits(String uid) async {
    final now = DateTime.now();
    final nextReset = DateTime(now.year, now.month + 1);
    debugPrint(
        '[AiCreditService] resetting credits for uid=$uid; '
        'next reset at $nextReset');
    await _users.doc(uid).set(
      {
        'ai_credits_used': 0,
        'ai_credits_reset_at': Timestamp.fromDate(nextReset),
      },
      SetOptions(merge: true),
    );
  }
}
