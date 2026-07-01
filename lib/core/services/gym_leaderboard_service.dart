import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/test_data_library.dart';
import '../models/gym_war_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/checkin_model.dart';
import '../models/gym_member_model.dart';
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
  /// Combines real-time check-in counts (this week) with member list.
  Stream<List<LeaderboardEntryModel>> getWeeklyLeaderboardStream(String gymId) {
    if (TestModeService().isActive) {
      return Stream.value(TestDataLibrary.gymLeaderboard());
    }

    final weekStart = _currentWeekStart();

    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .snapshots()
        .asyncMap((checkinSnap) async {
      // Build uid → count map from this week's check-ins
      final counts = <String, int>{};
      for (final doc in checkinSnap.docs) {
        final m = CheckInModel.fromFirestore(doc);
        counts[m.uid] = (counts[m.uid] ?? 0) + 1;
      }

      // Fetch the member list (single read per checkins emission), capped.
      final membersSnap = await _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .limit(200)
          .get();

      final members =
          membersSnap.docs.map(GymMemberModel.fromFirestore).toList();

      // Build entries for all members, even those with 0 check-ins
      final entries = members
          .map((m) => LeaderboardEntryModel(
                uid: m.uid,
                displayName: m.displayName,
                photoURL: m.photoURL,
                checkInCount: counts[m.uid] ?? 0,
                rank: 0,
              ))
          .toList();

      // Sort descending by count
      entries.sort((a, b) => b.checkInCount.compareTo(a.checkInCount));

      // Assign ranks — ties share the same rank
      final ranked = <LeaderboardEntryModel>[];
      for (int i = 0; i < entries.length; i++) {
        final rank =
            (i > 0 && entries[i].checkInCount == entries[i - 1].checkInCount)
                ? ranked[i - 1].rank
                : i + 1;
        ranked.add(entries[i].copyWith(rank: rank));
      }

      debugPrint(
          '[GymLeaderboardService] Leaderboard for $gymId: ${ranked.length} entries');
      return ranked;
    });
  }

  /// Returns the Monday of the current week at 00:00:00 local time.
  DateTime _currentWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
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
