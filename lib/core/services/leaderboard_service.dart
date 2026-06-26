import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
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

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<LeaderboardEntry>> getGlobalLeaderboardStream(
      {int limit = 50}) {
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
