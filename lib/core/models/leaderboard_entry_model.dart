class LeaderboardEntryModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final int checkInCount;
  final int streak;
  final int rank;

  const LeaderboardEntryModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.checkInCount,
    this.streak = 0,
    required this.rank,
  });

  LeaderboardEntryModel copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    int? checkInCount,
    int? streak,
    int? rank,
  }) =>
      LeaderboardEntryModel(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        checkInCount: checkInCount ?? this.checkInCount,
        streak: streak ?? this.streak,
        rank: rank ?? this.rank,
      );
}
