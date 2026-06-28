import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_credit_model.dart';
import 'analytics_service.dart';

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
  /// Bonus credits (from consumable IAP top-ups) are consumed first before the
  /// daily quota. Premium users still check the daily limit but have a higher
  /// cap. Only call this for genuine NEW AI generations — never for cache reads.
  Future<bool> checkAndConsume(String uid, bool isPremium) async {
    final credits = await getCredits(uid, isPremium: isPremium);

    if (credits.isExhausted) {
      debugPrint(
          '[AiCreditService] uid=$uid — limit reached '
          '(used=${credits.used}, bonus=${credits.bonus}, '
          'isPremium=$isPremium)');
      unawaited(AnalyticsService().logEvent(
        name: 'credit_exhausted',
        parameters: {'uid': uid, 'is_premium': isPremium},
      ));
      return false;
    }

    // Consume bonus credit first, then daily quota.
    if (credits.bonus > 0) {
      await _consumeBonusCredit(uid);
    } else {
      await consumeCredit(uid);
    }

    unawaited(AnalyticsService().logEvent(
      name: 'credit_consumed',
      parameters: {
        'uid': uid,
        'is_premium': isPremium,
        'from_bonus': credits.bonus > 0,
      },
    ));
    return true;
  }

  /// Rolls back a previously consumed daily credit (call when the AI request
  /// that consumed the credit fails or returns empty). Floors at 0.
  Future<void> rollbackCredit(String uid) async {
    try {
      await _users.doc(uid).update({
        'ai_credits_used': FieldValue.increment(-1),
      });
      debugPrint('[AiCreditService] rolled back 1 daily credit for uid=$uid');
    } catch (e) {
      debugPrint('[AiCreditService] rollbackCredit error: $e');
    }
  }

  /// Rolls back a previously consumed bonus credit (call when the AI request
  /// fails and the credit came from the bonus pool). Floors at 0.
  Future<void> rollbackBonusCredit(String uid) async {
    try {
      await _users.doc(uid).update({
        'ai_credits_bonus': FieldValue.increment(1),
      });
      debugPrint('[AiCreditService] rolled back 1 bonus credit for uid=$uid');
    } catch (e) {
      debugPrint('[AiCreditService] rollbackBonusCredit error: $e');
    }
  }

  /// Grants [count] bonus credits to [uid] from a consumable IAP top-up.
  /// Bonus credits stack on top of the daily limit and never reset at midnight.
  Future<void> addBonusCredits(String uid, int count) async {
    try {
      await _users.doc(uid).set(
        {'ai_credits_bonus': FieldValue.increment(count)},
        SetOptions(merge: true),
      );
      debugPrint('[AiCreditService] added $count bonus credits to uid=$uid');
      unawaited(AnalyticsService().logEvent(
        name: 'ai_credits_purchased',
        parameters: {'count': count, 'uid': uid},
      ));
    } catch (e) {
      debugPrint('[AiCreditService] addBonusCredits error: $e');
    }
  }

  /// Increments `ai_credits_used` by 1. Fire-and-forget safe.
  Future<void> consumeCredit(String uid) async {
    debugPrint('[AiCreditService] consuming daily credit for uid=$uid');
    await _users.doc(uid).set(
      {'ai_credits_used': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Decrements `ai_credits_bonus` by 1. Internal use only.
  Future<void> _consumeBonusCredit(String uid) async {
    debugPrint('[AiCreditService] consuming bonus credit for uid=$uid');
    await _users.doc(uid).set(
      {'ai_credits_bonus': FieldValue.increment(-1)},
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
