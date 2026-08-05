/// A ranked row in `GymLeaderboardService`'s weekly leaderboard.
///
/// Faz 5 §5.3: `xp` (this week's XP total, not a lifetime count) replaces
/// the old `checkInCount` field — the underlying source moved from raw
/// check-in counts to weekly XP (`community_weekly_xp/{weekKey}`, bumped by
/// `functions/progress.js`'s `awardXp`), which reflects a member's FULL
/// weekly engagement (meals logged, posts, check-ins, ...), not just gym
/// visits. Renamed rather than repurposed under the old name — a
/// `checkInCount` that no longer counts check-ins would read as a defect to
/// the next person touching this file.
class LeaderboardEntryModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final int xp;
  final int streak;
  final int rank;

  const LeaderboardEntryModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.xp,
    this.streak = 0,
    required this.rank,
  });

  LeaderboardEntryModel copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    int? xp,
    int? streak,
    int? rank,
  }) =>
      LeaderboardEntryModel(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        rank: rank ?? this.rank,
      );
}
