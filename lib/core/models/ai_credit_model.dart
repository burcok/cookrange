import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks monthly AI usage for a user.
///
/// Free tier is capped at [freeMonthlyLimit] calls/month across all AI features
/// (food scan, AI chat, fitness twin, recipe generation).
/// Premium/Pro users are unlimited — [checkAndConsume] skips the gate for them.
class AiCreditModel {
  static const int freeMonthlyLimit = 20;

  final int used;
  final DateTime resetAt;

  const AiCreditModel({required this.used, required this.resetAt});

  /// Remaining calls this month (clamped to [0, freeMonthlyLimit]).
  int get remaining => (freeMonthlyLimit - used).clamp(0, freeMonthlyLimit);

  /// True when the user has consumed all free calls for this month.
  bool get isExhausted => used >= freeMonthlyLimit;

  /// Fraction of free quota consumed — [0.0, 1.0].
  double get usagePercent => (used / freeMonthlyLimit).clamp(0.0, 1.0);

  /// Fresh model for a new or reset user — zeroed out, resets on 1st of next month.
  factory AiCreditModel.fresh() {
    final now = DateTime.now();
    return AiCreditModel(
      used: 0,
      resetAt: DateTime(now.year, now.month + 1),
    );
  }

  factory AiCreditModel.fromFirestore(Map<String, dynamic> data) {
    final now = DateTime.now();
    final resetAt = data['ai_credits_reset_at'] is Timestamp
        ? (data['ai_credits_reset_at'] as Timestamp).toDate()
        : DateTime(now.year, now.month + 1);
    return AiCreditModel(
      used: data['ai_credits_used'] as int? ?? 0,
      resetAt: resetAt,
    );
  }
}
