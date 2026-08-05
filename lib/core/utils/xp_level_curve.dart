/// Pure, Firebase-independent XP → level curve (Faz 5 §5.1).
///
/// Server-authoritative: `functions/progress.js`'s `awardXp` is the ONLY
/// writer of `users/{uid}.xp`/`.level` (`firestore.rules` denies both to
/// every client). This class never decides what a user's level IS — it only
/// mirrors the SAME formula so the client can render a "how close to the
/// next level" progress bar from an already-trusted, already-server-written
/// `xp` number without a network round-trip, exactly the same role
/// `ReputationService`'s pure helpers already played for the pre-XP
/// reputation score. If this ever drifts from the server's copy, the
/// server's write is still what's actually stored — this class only affects
/// what a stale/cached client briefly *displays*.
///
/// ### Curve — "artan aralıklı" (increasing intervals), per the plan
/// The step from level `n` to `n + 1` costs `100 * n` XP — strictly
/// increasing by construction, not by a hand-tuned table. Summing that
/// arithmetic series gives a closed form for the CUMULATIVE xp needed to
/// *reach* level `n`:
/// ```
/// threshold(n) = 50 * n * (n - 1)      (n >= 1; threshold(1) == 0)
/// ```
/// Chosen because: (a) triangular-number growth is the simplest curve that
/// is increasing-interval by definition, no per-level tuning required;
/// (b) integer-only — no floating-point rounding risk at exact boundaries;
/// (c) at a realistic engaged-user pace (~50 XP/day from meal logs + streak
/// + occasional posts/comments) it reaches level 5 in ~3 weeks and level 20
/// in ~a year — fast early dopamine, slow late-game, the standard shape for
/// this kind of ladder — while a maximally-capped power user (~200 XP/day,
/// hitting every daily cap in the §5.1 table) reaches level 20 in ~3 months
/// and level 35 (the "legend" reputation band's entry point — see
/// `ReputationService`) in under a year. Retuning later only ever means
/// changing the single [_coefficient] below, never the shape of the curve.
class XpLevelCurve {
  const XpLevelCurve._();

  /// See the class doc for the derivation. Keep in sync with
  /// `functions/progress.js`'s `LEVEL_CURVE_COEFFICIENT` — the server is the
  /// authority; this constant only needs to match closely enough that a
  /// client-rendered progress bar doesn't visibly disagree with what the
  /// next `syncProgress` response reports.
  static const int _coefficient = 50;

  /// Defensive upper bound on the search in [levelForXp] — no real account
  /// will ever reach it (`xpThresholdForLevel(999)` is ~49 million XP); it
  /// only guarantees termination for a corrupted/absurd input.
  static const int _maxLevel = 999;

  /// Cumulative XP required to REACH [level] (level 1 == 0 XP).
  static int xpThresholdForLevel(int level) {
    final n = level < 1 ? 1 : level;
    return _coefficient * n * (n - 1);
  }

  /// The level a total of [xp] falls into.
  ///
  /// A linear scan, not a closed-form sqrt inversion — `n(n-1) <= xp / C`
  /// solved via the quadratic formula would need a floating-point
  /// correction step anyway to avoid landing one level off exactly AT a
  /// threshold boundary, and realistic levels stay in the low double digits
  /// for years of engaged use (see the class doc's pacing math), so the
  /// loop's cost is not a real concern — correctness and auditability win.
  static int levelForXp(int xp) {
    if (xp <= 0) return 1;
    var level = 1;
    while (level < _maxLevel && xpThresholdForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// XP already earned within the CURRENT level — the numerator for a
  /// "progress to next level" bar.
  static int xpIntoCurrentLevel(int xp) {
    return xp - xpThresholdForLevel(levelForXp(xp));
  }

  /// XP needed in total to go from the current level to the next one — the
  /// denominator for a "progress to next level" bar.
  static int xpForNextLevel(int xp) {
    final level = levelForXp(xp);
    return xpThresholdForLevel(level + 1) - xpThresholdForLevel(level);
  }
}
