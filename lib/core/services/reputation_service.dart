import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/xp_level_curve.dart';

enum ReputationTier { newcomer, active, contributor, expert, legend }

class ReputationData {
  /// XP total (Faz 5 §5.1). Named `score` — not `xp` — for source
  /// compatibility with every existing call site (`_buildReputationBadge`
  /// et al. read `rep.score`); the MEANING moved from the old
  /// `streak*2 + postCount*5` reputation formula onto plain XP, but nothing
  /// display-facing needed to change to pick that up.
  final int score;
  final ReputationTier tier;

  /// Faz 5 §5.1 addition — the XP level `score` falls into. Defaults to
  /// deriving it from [score] via [XpLevelCurve] when a caller doesn't have
  /// the server's own `level` field handy (e.g. [fromCachedScore]).
  final int level;

  ReputationData({
    required this.score,
    required this.tier,
    int? level,
  }) : level = level ?? XpLevelCurve.levelForXp(score);

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
/// client writes to `reputation_score`/`reputation_updated_at`/`xp`/`level`
/// unconditionally, closing a self-grant hole (any user could previously
/// write their own score directly via `_cacheScore`).
///
/// **Faz 5 §5.1 migration**: the tier is no longer derived from the old
/// `streak × 2 + postCount × 5` formula — that formula is deleted server-side
/// too ("no two parallel score systems survive this task"). `score` now
/// carries plain XP, and [_tierFromLevel] bands the XP LEVEL it maps to
/// (via [XpLevelCurve]) into one of the same 5 tiers, mirroring
/// `functions/progress.js`'s `tierFromLevel` exactly: newcomer below level 5,
/// active 5-9, contributor 10-19, expert 20-34, legend 35+. Nothing
/// display-facing needed to change for this — [ReputationData] still exposes
/// `score`/`tier` with the same types, so `profile_screen.dart`'s existing
/// tier chip renders correctly with zero changes, same as it would for any
/// user whose reputation predates this migration (their old
/// `reputation_score` is seeded as their starting XP server-side on first
/// touch — see `progress.js`'s `awardXp` — so standing carries over rather
/// than visibly resetting).
class ReputationService {
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  static ReputationTier _tierFromLevel(int level) {
    if (level >= 35) return ReputationTier.legend;
    if (level >= 20) return ReputationTier.expert;
    if (level >= 10) return ReputationTier.contributor;
    if (level >= 5) return ReputationTier.active;
    return ReputationTier.newcomer;
  }

  /// Triggers a server-side re-sync for [uid] (any signed-in caller may
  /// refresh another user's cached reputation this way — e.g. viewing their
  /// profile — since streak/tier badges and XP-level-derived tier are
  /// intrinsic to the target, not something the caller can influence; the
  /// server never grants CLIENT-reported event-flag badges or xp events on
  /// someone else's behalf, only ones derived from the target's own stored
  /// truth) and returns the freshly computed score(=xp)/level/tier.
  /// [streak] and [postCount] are accepted for source compatibility with
  /// existing call sites but are no longer sent — the server always
  /// re-derives everything itself.
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
    final level =
        (data['level'] as num?)?.toInt() ?? XpLevelCurve.levelForXp(score);
    final tierName = data['tier'] as String?;
    final tier = ReputationTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => _tierFromLevel(level),
    );
    // Note: no separate AchievementService().checkAndGrant call needed here
    // (unlike the pre-N2 version) — syncProgress already grants tier-based
    // badges (and, as of Faz 5 §5.1, XP for them) as part of every runSync,
    // so a second round-trip would just repeat the same idempotent work.
    return ReputationData(score: score, tier: tier, level: level);
  }

  /// Quick compute without a network call (e.g. for post cards from a
  /// cached score already present on a fetched document). [score] is
  /// treated as XP (see class doc) — the level and tier are both derived
  /// from it via [XpLevelCurve].
  static ReputationData fromCachedScore(int score) {
    final level = XpLevelCurve.levelForXp(score);
    return ReputationData(
        score: score, tier: _tierFromLevel(level), level: level);
  }

  /// Read cached reputation from the user doc (fast, no computation).
  /// Prefers the server-written `xp`/`level` fields directly; falls back to
  /// the legacy `reputation_score` mirror (still written by `runSync` for
  /// exactly this reason) for any doc read before those fields existed —
  /// see `progress.js`'s "first-touch migration" comment in `awardXp`.
  static ReputationData? fromUserData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final xp = (data['xp'] as num?)?.toInt() ??
        (data['reputation_score'] as num?)?.toInt();
    if (xp == null) return null;
    final level =
        (data['level'] as num?)?.toInt() ?? XpLevelCurve.levelForXp(xp);
    return ReputationData(score: xp, tier: _tierFromLevel(level), level: level);
  }

  /// Is this the current user?
  static bool isCurrentUser(String uid) =>
      FirebaseAuth.instance.currentUser?.uid == uid;
}
