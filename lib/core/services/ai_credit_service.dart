import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_credit_model.dart';

/// Singleton service that tracks and gates **daily** AI usage per user.
///
/// Free users get [AiCreditModel.freeDailyLimit] new AI generations per day.
/// Premium users get [AiCreditModel.premiumDailyLimit] per day.
/// Reading cached/saved projections must NEVER call [checkAndConsume].
/// The counter resets at local midnight each day.
///
/// Firestore fields on `users/{uid}`:
///   - `ai_credits_used`     — int, count of new generations today
///   - `ai_credits_reset_at` — Timestamp, next local midnight
///   - `ai_credits_bonus`    — int, consumable top-up pool (not reset at midnight)
class AiCreditService {
  static final AiCreditService _i = AiCreditService._();
  factory AiCreditService() => _i;
  AiCreditService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Reads the current credit state for [uid], auto-resetting if the day
  /// has rolled over. Callers can pass [isPremium] for correct limit display.
  Future<AiCreditModel> getCredits(String uid, {bool isPremium = false}) async {
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null || !data.containsKey('ai_credits_reset_at')) {
      await _resetCredits(uid);
      return AiCreditModel.fresh(isPremium: isPremium);
    }

    final resetAtRaw = data['ai_credits_reset_at'];
    final resetAt = resetAtRaw is Timestamp
        ? resetAtRaw.toDate()
        : DateTime.now().subtract(const Duration(seconds: 1));

    if (DateTime.now().isAfter(resetAt)) {
      await _resetCredits(uid);
      return AiCreditModel.fresh(isPremium: isPremium);
    }

    return AiCreditModel.fromFirestore(data, isPremium: isPremium);
  }

  /// Checks whether [uid] can make a new AI generation and, if so, consumes
  /// one credit atomically. Returns `true` when permitted.
  ///
  /// Premium users are always permitted; their count is still tracked for analytics.
  /// Only call this for genuine NEW AI generations — never for cache reads.
  Future<bool> checkAndConsume(String uid, bool isPremium) async {
    if (isPremium) {
      final credits = await getCredits(uid, isPremium: true);
      if (credits.isExhausted) {
        debugPrint(
            '[AiCreditService] uid=$uid — premium daily limit reached '
            '(${credits.used}/${AiCreditModel.premiumDailyLimit})');
        return false;
      }
      unawaited(consumeCredit(uid));
      return true;
    }

    final credits = await getCredits(uid);
    if (credits.isExhausted) {
      debugPrint(
          '[AiCreditService] uid=$uid — free daily limit reached '
          '(${credits.used}/${AiCreditModel.freeDailyLimit})');
      return false;
    }

    await consumeCredit(uid);
    return true;
  }

  /// Increments `ai_credits_used` by 1. Fire-and-forget safe.
  Future<void> consumeCredit(String uid) async {
    debugPrint('[AiCreditService] consuming daily credit for uid=$uid');
    await _users.doc(uid).set(
      {'ai_credits_used': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Live stream of the user's credit state — used by [AiCreditBadge].
  Stream<AiCreditModel> getCreditsStream(String uid, {bool isPremium = false}) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null ||
          !data.containsKey('ai_credits_used') ||
          !data.containsKey('ai_credits_reset_at')) {
        return AiCreditModel.fresh(isPremium: isPremium);
      }
      return AiCreditModel.fromFirestore(data, isPremium: isPremium);
    });
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _resetCredits(String uid) async {
    final nextMidnight = _nextMidnight();
    debugPrint(
        '[AiCreditService] resetting daily credits for uid=$uid; '
        'next reset at $nextMidnight');
    await _users.doc(uid).set(
      {
        'ai_credits_used': 0,
        'ai_credits_reset_at': Timestamp.fromDate(nextMidnight),
      },
      SetOptions(merge: true),
    );
  }

  DateTime _nextMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }
}
