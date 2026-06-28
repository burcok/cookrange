import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks **daily** AI usage for a user.
///
/// Free tier: [freeDailyLimit] new AI generations per day.
/// Premium/Pro: [premiumDailyLimit] per day.
/// Cached/saved data reads never consume a credit.
/// The counter resets at local midnight each day.
class AiCreditModel {
  static const int freeDailyLimit = 2;
  static const int premiumDailyLimit = 20;

  final int used;
  final bool isPremium;
  final DateTime resetAt;

  /// Bonus credits from consumable top-up purchases (stack on top of daily limit).
  final int bonus;

  const AiCreditModel({
    required this.used,
    required this.isPremium,
    required this.resetAt,
    this.bonus = 0,
  });

  int get _limit => isPremium ? premiumDailyLimit : freeDailyLimit;

  /// Remaining new generations today (clamped to [0, limit]).
  int get remaining => (_limit + bonus - used).clamp(0, _limit + bonus);

  /// True when the user has no generations left today.
  bool get isExhausted => used >= _limit + bonus;

  /// Fraction of daily quota consumed — [0.0, 1.0].
  double get usagePercent => (_limit > 0 ? used / _limit : 1.0).clamp(0.0, 1.0);

  /// How many minutes until the daily reset.
  int get minutesUntilReset =>
      resetAt.difference(DateTime.now()).inMinutes.clamp(0, 1440);

  factory AiCreditModel.fresh({bool isPremium = false}) {
    return AiCreditModel(
      used: 0,
      isPremium: isPremium,
      resetAt: _nextMidnight(),
    );
  }

  factory AiCreditModel.fromFirestore(Map<String, dynamic> data,
      {bool isPremium = false}) {
    final resetAtRaw = data['ai_credits_reset_at'];
    final resetAt =
        resetAtRaw is Timestamp ? resetAtRaw.toDate() : _nextMidnight();
    return AiCreditModel(
      used: data['ai_credits_used'] as int? ?? 0,
      isPremium: isPremium,
      resetAt: resetAt,
      bonus: data['ai_credits_bonus'] as int? ?? 0,
    );
  }

  static DateTime _nextMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }
}
