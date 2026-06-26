import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

class ReputationService {
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _pointsPerStreakDay = 2;
  static const int _pointsPerPost = 5;
  static const int _pointsPerChallenge = 10;

  static ReputationTier _tierFromScore(int score) {
    if (score >= 700) return ReputationTier.legend;
    if (score >= 350) return ReputationTier.expert;
    if (score >= 150) return ReputationTier.contributor;
    if (score >= 50) return ReputationTier.active;
    return ReputationTier.newcomer;
  }

  /// Compute reputation for a user given their streak and post count.
  /// Also fetches challenge participation count from Firestore.
  Future<ReputationData> computeReputation({
    required String uid,
    required int streak,
    required int postCount,
  }) async {
    int challengeCount = 0;
    try {
      final snap = await _db
          .collection('challenges')
          .where('participantIds', arrayContains: uid)
          .count()
          .get();
      challengeCount = snap.count ?? 0;
    } catch (e) {
      debugPrint('ReputationService: challenge count error: $e');
    }

    final score = streak * _pointsPerStreakDay +
        postCount * _pointsPerPost +
        challengeCount * _pointsPerChallenge;

    final tier = _tierFromScore(score);
    await _cacheScore(uid, score);
    return ReputationData(score: score, tier: tier);
  }

  /// Quick compute without Firestore calls (e.g. for post cards from cached score).
  static ReputationData fromCachedScore(int score) {
    return ReputationData(score: score, tier: _tierFromScore(score));
  }

  Future<void> _cacheScore(String uid, int score) async {
    try {
      await _db.collection('users').doc(uid).update({
        'reputation_score': score,
        'reputation_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReputationService: cache write error: $e');
    }
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
