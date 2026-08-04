import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ReputationTier { newcomer, active, contributor, expert, legend }

class ReputationData {
  final int score;
  final ReputationTier tier;

  const ReputationData({required this.score, required this.tier});

  String get tierEmoji {
    switch (tier) {
      case ReputationTier.newcomer:
        return '🌱';
      case ReputationTier.active:
        return '💪';
      case ReputationTier.contributor:
        return '🌟';
      case ReputationTier.expert:
        return '🏆';
      case ReputationTier.legend:
        return '👑';
    }
  }

  String get tierName {
    switch (tier) {
      case ReputationTier.newcomer:
        return 'Newcomer';
      case ReputationTier.active:
        return 'Active';
      case ReputationTier.contributor:
        return 'Contributor';
      case ReputationTier.expert:
        return 'Expert';
      case ReputationTier.legend:
        return 'Legend';
    }
  }
}

/// Reputation is server-computed and server-cached (audit N2/Faz-0 §0.4,
/// `syncProgress` in `functions/progress.js`) — `firestore.rules` denies
/// client writes to `reputation_score`/`reputation_updated_at`
/// unconditionally, closing a self-grant hole (any user could previously
/// write their own score directly via `_cacheScore`). The formula itself
/// (`streak × 2 + postCount × 5`) is unchanged and still lives here too
/// ([_tierFromScore], used by the pure/no-network helpers below); the
/// server independently re-derives the same formula from the target's own
/// stored streak and a real post-count aggregation, never a client number.
class ReputationService {
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  static ReputationTier _tierFromScore(int score) {
    if (score >= 700) return ReputationTier.legend;
    if (score >= 350) return ReputationTier.expert;
    if (score >= 150) return ReputationTier.contributor;
    if (score >= 50) return ReputationTier.active;
    return ReputationTier.newcomer;
  }

  /// Triggers a server-side re-sync for [uid] (any signed-in caller may
  /// refresh another user's cached reputation this way — e.g. viewing their
  /// profile — since it's derived entirely from that user's own already-
  /// public streak + post count; the server never grants event-flag
  /// badges on their behalf, only tier/streak badges intrinsic to them) and
  /// returns the freshly computed score/tier. [streak] and [postCount] are
  /// accepted for source compatibility with existing call sites but are no
  /// longer sent — the server always re-derives both itself.
  Future<ReputationData> computeReputation({
    required String uid,
    required int streak,
    required int postCount,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('syncProgress')
        .call<Map<String, dynamic>>({'targetUid': uid});
    final data = result.data;
    final score = (data['score'] as num).toInt();
    final tierName = data['tier'] as String;
    final tier = ReputationTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => _tierFromScore(score),
    );
    // Note: no separate AchievementService().checkAndGrant call needed here
    // (unlike the pre-N2 version) — syncProgress already grants tier-based
    // badges as part of every runSync, so a second round-trip would just
    // repeat the same idempotent work.
    return ReputationData(score: score, tier: tier);
  }

  /// Quick compute without a network call (e.g. for post cards from a
  /// cached score already present on a fetched document).
  static ReputationData fromCachedScore(int score) {
    return ReputationData(score: score, tier: _tierFromScore(score));
  }

  /// Read cached reputation from user doc (fast, no computation).
  static ReputationData? fromUserData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final score = (data['reputation_score'] as num?)?.toInt();
    if (score == null) return null;
    return ReputationData(score: score, tier: _tierFromScore(score));
  }

  /// Is this the current user?
  static bool isCurrentUser(String uid) =>
      FirebaseAuth.instance.currentUser?.uid == uid;
}
