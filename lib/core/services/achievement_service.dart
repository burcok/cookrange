import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import 'reputation_service.dart';

/// Manages badge/achievement earning for a user.
///
/// Granting is server-authoritative (audit N2/Faz-0 §0.4, `syncProgress` /
/// `backfillProgress` in `functions/progress.js`) — `firestore.rules` denies
/// client writes to `users/{uid}/achievements/*` unconditionally, closing a
/// self-grant hole (any authenticated user could previously write any badge
/// directly, no eligibility check enforced). Every call site still calls
/// [checkAndGrant] the same way as before (fire-and-forget via `unawaited`);
/// the server independently re-derives streak/reputation-tier badges from
/// truth and only honours the four momentary event flags for the caller's
/// own uid — see the doc comment in `functions/progress.js` for the full
/// trust-boundary rationale.
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
  // Grant logic — call unawaited from existing success paths
  // ──────────────────────────────────────────────────────────────────────────

  /// Reports momentary events + triggers a server-side re-sync. [streak] and
  /// [tier] are accepted for source compatibility with existing call sites
  /// but are no longer sent — the server always re-derives both from the
  /// user's own stored data, never a client-supplied number.
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
      final result = await FirebaseFunctions.instance
          .httpsCallable('syncProgress')
          .call<Map<String, dynamic>>({
        if (justLoggedMeal) 'justLoggedMeal': true,
        if (justLoggedPhoto) 'justLoggedPhoto': true,
        if (justPosted) 'justPosted': true,
        if (justCookedAndLogged) 'justCookedAndLogged': true,
      });
      debugPrint(
          'AchievementService: syncProgress for $uid → granted=${result.data['granted']}');
    } catch (e) {
      debugPrint('AchievementService: checkAndGrant error: $e');
    }
  }

  /// Backfill — call once on first app open after the feature ships.
  /// Evaluates all static signals server-side from existing data.
  Future<void> backfillForUser(String uid) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('backfillProgress').call();
    } catch (e) {
      debugPrint('AchievementService: backfill error: $e');
    }
  }
}
