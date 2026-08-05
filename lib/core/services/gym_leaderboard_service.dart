import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/test_data_library.dart';
import '../models/gym_war_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/gym_member_model.dart';
import '../utils/local_week.dart';
import 'test_mode_service.dart';

class GymLeaderboardService {
  static final GymLeaderboardService _instance =
      GymLeaderboardService._internal();
  factory GymLeaderboardService() => _instance;
  GymLeaderboardService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Leaderboard ──────────────────────────────────────────────────────────────

  /// Streams the weekly leaderboard for [gymId].
  ///
  /// Faz 5 §5.3: sourced from THIS WEEK'S XP (`community_weekly_xp/
  /// {weekKey}`), not raw check-in counts — `functions/progress.js`'s
  /// `awardXp` bumps that rollup inside the SAME transaction that awards XP
  /// for ANY kind (meal logs, posts, check-ins, template acceptances, ...),
  /// so this now reflects a member's full weekly engagement, not just gym
  /// visits. The weekly reset boundary is unchanged (`LocalWeek`, same
  /// Monday-00:00-local math `_currentWeekStart()` always used).
  ///
  /// Live trigger: the gym's OWN member roster (`.snapshots()`) — reacts
  /// immediately to joins/leaves, exactly like every other gym-scoped
  /// listener in this file. The per-member XP figures are refetched
  /// (one-shot, chunked `whereIn` reads — never a `.snapshots()` per member,
  /// which would mean up to 7 concurrent listeners for a 200-member gym)
  /// on every roster emission. Documented trade-off, not silently accepted:
  /// this is not sub-second-live the way the old checkins listener was —
  /// XP now accrues from many action types across the whole app, not just
  /// visible-in-gym check-ins, so a member re-opening this screen (which
  /// resubscribes) is the realistic refresh path, not a number ticking up
  /// while they watch.
  Stream<List<LeaderboardEntryModel>> getWeeklyLeaderboardStream(String gymId) {
    if (TestModeService().isActive) {
      return Stream.value(TestDataLibrary.gymLeaderboard());
    }

    final weekKey = LocalWeek.key(DateTime.now());

    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .limit(200)
        .snapshots()
        .asyncMap((membersSnap) async {
      final members =
          membersSnap.docs.map(GymMemberModel.fromFirestore).toList();
      final xpByUid = await _fetchWeeklyXp(
        members.map((m) => m.uid).toList(),
        weekKey,
      );

      // Build entries for all members, even those with 0 XP this week.
      final entries = members
          .map((m) => LeaderboardEntryModel(
                uid: m.uid,
                displayName: m.displayName,
                photoURL: m.photoURL,
                xp: xpByUid[m.uid] ?? 0,
                rank: 0,
              ))
          .toList();

      // Sort descending by XP
      entries.sort((a, b) => b.xp.compareTo(a.xp));

      // Assign ranks — ties share the same rank
      final ranked = <LeaderboardEntryModel>[];
      for (int i = 0; i < entries.length; i++) {
        final rank = (i > 0 && entries[i].xp == entries[i - 1].xp)
            ? ranked[i - 1].rank
            : i + 1;
        ranked.add(entries[i].copyWith(rank: rank));
      }

      debugPrint(
          '[GymLeaderboardService] Leaderboard for $gymId: ${ranked.length} entries');
      return ranked;
    });
  }

  /// Chunked (`whereIn` caps at 30 — mirrors the same 30-value limit this
  /// codebase's `LeaderboardService.getFriendsLeaderboard`/the "friend at
  /// gym" notification fan-out already rely on) lookup of this week's XP
  /// for a bounded set of member uids. One-shot `.get()` per chunk, not a
  /// live listener — see this method's caller doc comment for why.
  Future<Map<String, int>> _fetchWeeklyXp(
      List<String> uids, String weekKey) async {
    if (uids.isEmpty) return {};
    final result = <String, int>{};
    final col = _db
        .collection('community_weekly_xp')
        .doc(weekKey)
        .collection('members');
    for (var i = 0; i < uids.length; i += 30) {
      final end = (i + 30 > uids.length) ? uids.length : i + 30;
      final chunk = uids.sublist(i, end);
      final snap = await col.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        result[doc.id] = (doc.data()['xp'] as num?)?.toInt() ?? 0;
      }
    }
    return result;
  }

  // ── Gym Wars ─────────────────────────────────────────────────────────────────

  /// Creates a new war between [gymAId] and [opponentGymId].
  Future<GymWarModel> createWar({
    required String gymAId,
    required String gymAName,
    required String opponentGymId,
    required String opponentGymName,
    int durationDays = 7,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final doc = _db.collection('gym_wars').doc();

    final war = GymWarModel(
      id: doc.id,
      gymAId: gymAId,
      gymBId: opponentGymId,
      gymAName: gymAName,
      gymBName: opponentGymName,
      challengerUid: uid,
      status: GymWarStatus.active,
      metric: GymWarMetric.checkins,
      startDate: now,
      endDate: now.add(Duration(days: durationDays)),
      createdAt: now,
    );

    await doc.set(war.toFirestore());
    debugPrint(
        '[GymLeaderboardService] War created: ${doc.id} ($gymAName vs $opponentGymName, ${durationDays}d)');
    return war;
  }

  /// Returns all active wars involving [gymId].
  /// Uses two parallel queries (Firestore has no OR across different fields).
  Future<List<GymWarModel>> getActiveWars(String gymId) async {
    final results = await Future.wait([
      _db
          .collection('gym_wars')
          .where('gym_a_id', isEqualTo: gymId)
          .where('status', isEqualTo: 'active')
          .get(),
      _db
          .collection('gym_wars')
          .where('gym_b_id', isEqualTo: gymId)
          .where('status', isEqualTo: 'active')
          .get(),
    ]);

    final all = [
      ...results[0].docs,
      ...results[1].docs,
    ].map(GymWarModel.fromFirestore).toList();

    // De-duplicate by id in case a war somehow appears in both result sets
    final seen = <String>{};
    final deduped = all.where((w) => seen.add(w.id)).toList();

    debugPrint(
        '[GymLeaderboardService] Active wars for $gymId: ${deduped.length}');
    return deduped;
  }

  /// Counts check-ins for [gymId] within the war's time window.
  Future<int> getWarScore(GymWarModel war, String gymId) async {
    final endDate = war.hasEnded ? war.endDate : DateTime.now();
    try {
      final snap = await _db
          .collection('gyms')
          .doc(gymId)
          .collection('checkins')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(war.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint(
          '[GymLeaderboardService] getWarScore error for $gymId in war ${war.id}: $e');
      return 0;
    }
  }

  /// Ends a war by setting its status to 'ended'.
  Future<void> endWar(String warId) async {
    await _db
        .collection('gym_wars')
        .doc(warId)
        .update({'status': GymWarStatus.ended.firestoreValue});
    debugPrint('[GymLeaderboardService] War $warId ended');
  }
}
