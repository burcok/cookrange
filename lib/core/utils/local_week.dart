/// Monday-anchored local-week helpers (Faz 5 §5.3) — the CLIENT-side twin of
/// `functions/engagement_credit_logic.js`'s `startOfLocalWeekMs`/
/// `localWeekKey`. Both key the SAME weekly documents
/// (`community_weekly_xp/{weekKey}`, `community_groups/{id}/
/// weekly_contributions|weekly_leaderboard/{weekKey}`), so the date-string
/// format must stay byte-identical between the two.
///
/// The server derives "local" (Turkey, UTC+3) by shifting its own UTC clock,
/// because Cloud Functions always run in UTC (see that file's header
/// comment). This class does NOT do that shift — `DateTime.now()` on-device
/// is already in the device's own local timezone, exactly the same
/// reasoning `GymLeaderboardService._currentWeekStart()` has always relied
/// on for its (pre-existing, unchanged) weekly check-in reset. A device set
/// to a non-Turkey timezone can therefore compute a different week boundary
/// than the server's fixed-offset clock right at the Monday-midnight edge —
/// a pre-existing, accepted class of skew (the weekly leaderboard has always
/// had it), not a new one introduced here.
class LocalWeek {
  const LocalWeek._();

  /// Monday 00:00 local of the week containing [now].
  static DateTime startOfWeek(DateTime now) {
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  /// `YYYY-MM-DD` key for [now]'s week (that Monday's own calendar date) —
  /// MUST stay byte-identical to the server's `localWeekKey` output.
  static String key(DateTime now) {
    final monday = startOfWeek(now);
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
