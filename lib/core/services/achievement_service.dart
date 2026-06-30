import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import 'reputation_service.dart';

/// Manages badge/achievement earning for a user.
///
/// Calling [checkAndGrant] is idempotent — every path (logRecipe, createPost,
/// streak update, tier change) calls it fire-and-forget via [unawaited]; if the
/// user already earned a badge, the Firestore write is a no-op.
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('achievements');

  // ──────────────────────────────────────────────────────────────────────────
  // Read
  // ──────────────────────────────────────────────────────────────────────────

  Stream<List<AchievementRecord>> getAchievementsStream(String uid) {
    return _col(uid).snapshots().map((snap) => snap.docs
        .map((d) => AchievementRecord.fromFirestore(d.id, d.data()))
        .toList());
  }

  Future<Set<AchievementKey>> getEarnedKeys(String uid) async {
    final snap = await _col(uid).get();
    final keys = <AchievementKey>{};
    for (final doc in snap.docs) {
      try {
        keys.add(AchievementKey.values.firstWhere((k) => k.name == doc.id));
      } catch (_) {}
    }
    return keys;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Write
  // ──────────────────────────────────────────────────────────────────────────

  /// Idempotent — does nothing if [key] already earned.
  Future<void> earn(String uid, AchievementKey key) async {
    final ref = _col(uid).doc(key.name);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return; // already earned
        tx.set(
            ref,
            AchievementRecord(key: key, earnedAt: DateTime.now())
                .toFirestore());
      });
      debugPrint('AchievementService: earned ${key.name} for $uid');
    } catch (e) {
      debugPrint('AchievementService: earn error for ${key.name}: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Grant logic — call unawaited from existing success paths
  // ──────────────────────────────────────────────────────────────────────────

  /// Evaluates eligibility based on supplied signals and grants any newly
  /// earned badges. All parameters are optional — supply only what changed.
  Future<void> checkAndGrant(
    String uid, {
    int? streak,
    ReputationTier? tier,
    bool justLoggedMeal = false,
    bool justLoggedPhoto = false,
    bool justPosted = false,
    bool justCookedAndLogged = false,
  }) async {
    try {
      final earned = await getEarnedKeys(uid);

      final toGrant = <AchievementKey>[];

      if (justLoggedMeal && !earned.contains(AchievementKey.firstMealLogged)) {
        toGrant.add(AchievementKey.firstMealLogged);
      }
      if (justLoggedPhoto && !earned.contains(AchievementKey.firstPhotoLog)) {
        toGrant.add(AchievementKey.firstPhotoLog);
      }
      if (justPosted && !earned.contains(AchievementKey.firstPost)) {
        toGrant.add(AchievementKey.firstPost);
      }
      if (justCookedAndLogged && !earned.contains(AchievementKey.firstCook)) {
        toGrant.add(AchievementKey.firstCook);
      }

      if (streak != null) {
        if (streak >= 7 && !earned.contains(AchievementKey.streak7)) {
          toGrant.add(AchievementKey.streak7);
        }
        if (streak >= 30 && !earned.contains(AchievementKey.streak30)) {
          toGrant.add(AchievementKey.streak30);
        }
        if (streak >= 100 && !earned.contains(AchievementKey.streak100)) {
          toGrant.add(AchievementKey.streak100);
        }
      }

      if (tier != null) {
        if (tier.index >= ReputationTier.active.index &&
            !earned.contains(AchievementKey.tierActive)) {
          toGrant.add(AchievementKey.tierActive);
        }
        if (tier.index >= ReputationTier.contributor.index &&
            !earned.contains(AchievementKey.tierContributor)) {
          toGrant.add(AchievementKey.tierContributor);
        }
        if (tier.index >= ReputationTier.expert.index &&
            !earned.contains(AchievementKey.tierExpert)) {
          toGrant.add(AchievementKey.tierExpert);
        }
        if (tier == ReputationTier.legend &&
            !earned.contains(AchievementKey.tierLegend)) {
          toGrant.add(AchievementKey.tierLegend);
        }
      }

      for (final key in toGrant) {
        await earn(uid, key);
      }
    } catch (e) {
      debugPrint('AchievementService: checkAndGrant error: $e');
    }
  }

  /// Backfill — call once on first app open after the feature ships.
  /// Evaluates all static signals from the existing user doc.
  Future<void> backfillForUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final streak = (data['onboarding_data']?['streak'] as num?)?.toInt() ?? 0;
      final repScore = (data['reputation_score'] as num?)?.toInt() ?? 0;
      final tier = ReputationService.fromCachedScore(repScore).tier;

      // Check if user has ever logged a meal
      final logsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .limit(1)
          .get();
      final hasMealLog = logsSnap.docs.isNotEmpty;

      // Check if user has ever posted
      final postsSnap = await _db
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .limit(1)
          .get();
      final hasPost = postsSnap.docs.isNotEmpty;

      await checkAndGrant(
        uid,
        streak: streak,
        tier: tier,
        justLoggedMeal: hasMealLog,
        justPosted: hasPost,
      );
    } catch (e) {
      debugPrint('AchievementService: backfill error: $e');
    }
  }
}
