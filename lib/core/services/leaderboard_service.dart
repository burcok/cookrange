import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/local_week.dart';
import 'friend_service.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? photoURL;
  final int streak;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.streak,
    required this.rank,
  });

  factory LeaderboardEntry.fromUser(UserModel user, int rank) {
    return LeaderboardEntry(
      uid: user.uid,
      displayName: user.displayName ?? 'User',
      photoURL: user.photoURL,
      streak: (user.onboardingData?['streak'] as num?)?.toInt() ?? 0,
      rank: rank,
    );
  }
}

/// A ranked row in the WEEKLY, XP-based community leaderboard (Faz 5 §5.3)
/// — a distinct metric/window from [LeaderboardEntry] above (all-time
/// streak, never resets). Deliberately a separate small class rather than
/// adding an `xp` field to [LeaderboardEntry]: that class is keyed to
/// `UserModel.fromUser`/`onboarding_data.streak` specifically, and this
/// entry is parsed straight off the denormalized `community_weekly_xp`
/// rollup doc instead (no `UserModel` round-trip needed).
class XpLeaderboardEntry {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final int xp;
  final int rank;

  const XpLeaderboardEntry({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.xp,
    required this.rank,
  });
}

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<LeaderboardEntry>> getGlobalLeaderboardStream({int limit = 50}) {
    return _db
        .collection('users')
        .orderBy('onboarding_data.streak', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < snap.docs.length; i++) {
        try {
          final user = UserModel.fromFirestore(snap.docs[i]);
          entries.add(LeaderboardEntry.fromUser(user, i + 1));
        } catch (e) {
          debugPrint('LeaderboardService: skip doc ${snap.docs[i].id}: $e');
        }
      }
      return entries;
    });
  }

  /// Faz 5 §5.3 — weekly, XP-based community ranking (resets Monday 00:00
  /// local — see [LocalWeek]). Distinct from [getGlobalLeaderboardStream]
  /// above (all-time streak, a different metric with no reset); reads the
  /// denormalized `community_weekly_xp/{weekKey}/members` collection
  /// (bumped transactionally by `awardXp`, `functions/progress.js`) rather
  /// than any client-side aggregation over `users` — XP itself is already a
  /// PUBLIC field on `users/{uid}` (Faz 0 §0.2's field-allowlist), so this
  /// weekly rollup carries no additional sensitivity and needs no narrower
  /// read rule than a flat authenticated read.
  Stream<List<XpLeaderboardEntry>> getWeeklyXpLeaderboardStream(
      {int limit = 50}) {
    final weekKey = LocalWeek.key(DateTime.now());
    return _db
        .collection('community_weekly_xp')
        .doc(weekKey)
        .collection('members')
        .orderBy('xp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final entries = <XpLeaderboardEntry>[];
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        entries.add(XpLeaderboardEntry(
          uid: snap.docs[i].id,
          displayName: d['display_name'] as String?,
          photoURL: d['photo_url'] as String?,
          xp: (d['xp'] as num?)?.toInt() ?? 0,
          rank: i + 1,
        ));
      }
      return entries;
    });
  }

  Future<List<LeaderboardEntry>> getFriendsLeaderboard() async {
    final friendIds = await FriendService().getFriendIds();
    if (friendIds.isEmpty) return [];

    // Firestore whereIn supports up to 30 values
    final batch = friendIds.take(30).toList();
    try {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      final entries = snap.docs.map((doc) {
        final user = UserModel.fromFirestore(doc);
        return LeaderboardEntry.fromUser(user, 0);
      }).toList();

      // Sort by streak descending, assign ranks
      entries.sort((a, b) => b.streak.compareTo(a.streak));
      return List.generate(entries.length, (i) {
        final e = entries[i];
        return LeaderboardEntry(
          uid: e.uid,
          displayName: e.displayName,
          photoURL: e.photoURL,
          streak: e.streak,
          rank: i + 1,
        );
      });
    } catch (e) {
      debugPrint('LeaderboardService.getFriendsLeaderboard error: $e');
      return [];
    }
  }
}
