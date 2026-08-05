import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gym_analytics_model.dart';
import '../models/gym_member_model.dart';
import '../models/checkin_model.dart';
import '../models/progress_sharing_model.dart';
import 'progress_sharing_service.dart';

/// Singleton service — computes all gym analytics from Firestore in two
/// parallel reads (members + check-ins), then derives every metric locally.
class GymAnalyticsService {
  static final GymAnalyticsService _i = GymAnalyticsService._internal();
  factory GymAnalyticsService() => _i;
  GymAnalyticsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Time-slot helper ────────────────────────────────────────────────────────

  int _timeSlot(int hour) {
    if (hour >= 6 && hour < 12) return 0; // Morning
    if (hour >= 12 && hour < 18) return 1; // Afternoon
    if (hour >= 18 && hour < 22) return 2; // Evening
    return 3; // Night (22–5)
  }

  // ── Main analytics computation ──────────────────────────────────────────────

  Future<GymAnalyticsModel> computeAnalytics(String gymId) async {
    debugPrint('[GymAnalyticsService] computeAnalytics start: $gymId');

    final now = DateTime.now();
    final since60 = now.subtract(const Duration(days: 60));
    final since30 = now.subtract(const Duration(days: 30));
    final since14 = now.subtract(const Duration(days: 14));
    final since7 = now.subtract(const Duration(days: 7));

    // Faz 0 §0.5 fix: both reads were unbounded `.get()` calls — the entire
    // members subcollection and the entire 60-day check-in window, on every
    // dashboard open (cost + performance risk on any gym past a trivial
    // size). `totalMembers` now comes from a cheap, always-accurate
    // `.count()` aggregation regardless of scale; the detailed member list
    // (needed for the atRisk/top-5 breakdowns below, which need real
    // records, not just a count) and the check-in window are capped at
    // generous limits and logged — not silently truncated — if ever hit.
    const memberCap = 500;
    const checkinCap = 5000;
    final countFuture =
        _db.collection('gyms').doc(gymId).collection('members').count().get();
    final membersFuture = _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .limit(memberCap)
        .get();
    final checkinsFuture = _db
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since60))
        .orderBy('timestamp')
        .limit(checkinCap)
        .get();
    // Faz 4 §4.3 — the uids of members who granted progress_sharing tier>=1
    // for THIS gym. A client can never read another member's
    // progress_sharing doc directly (owner-only rule); this is the only
    // legitimate way to scope the at-risk list / aggregate below. Fetched
    // in parallel with the reads above, not sequenced after — same R1
    // discipline as everything else in this method.
    final consentingFuture = ProgressSharingService()
        .getConsentingMemberUids(ProgressSharingScope.gym(gymId));

    final totalCountSnap = await countFuture;
    final membersSnap = await membersFuture;
    final checkinsSnap = await checkinsFuture;
    final consentingUids = await consentingFuture;

    final members = membersSnap.docs.map(GymMemberModel.fromFirestore).toList();
    final checkins = checkinsSnap.docs.map(CheckInModel.fromFirestore).toList();

    if (members.length >= memberCap) {
      debugPrint(
          '[GymAnalyticsService] member list capped at $memberCap for $gymId — atRisk/top5 may be incomplete');
    }
    if (checkins.length >= checkinCap) {
      debugPrint(
          '[GymAnalyticsService] checkin list capped at $checkinCap for $gymId (60d window) — heatmap/trend may undercount');
    }

    debugPrint(
        '[GymAnalyticsService] members=${members.length} checkins=${checkins.length}');

    final total = totalCountSnap.count ?? members.length;

    // Active sets
    final uidsThisWeek = checkins
        .where((c) => c.timestamp.isAfter(since7))
        .map((c) => c.uid)
        .toSet();
    final uidsThisMonth = checkins
        .where((c) => c.timestamp.isAfter(since30))
        .map((c) => c.uid)
        .toSet();

    // Retention
    final safeTotal = total > 0 ? total : 1;
    final retention = uidsThisMonth.length / safeTotal * 100;

    // Engagement score (0–100 composite)
    final avgCheckinsPerMember =
        checkins.where((c) => c.timestamp.isAfter(since7)).length / safeTotal;
    final engagement = (uidsThisWeek.length / safeTotal * 50) +
        (uidsThisMonth.length / safeTotal * 30) +
        ((avgCheckinsPerMember / 5).clamp(0.0, 1.0) * 20);

    // Heatmap [dayOfWeek 0..6][timeSlot 0..3]
    final heatmap = <int, Map<int, int>>{
      for (var d = 0; d < 7; d++) d: {for (var s = 0; s < 4; s++) s: 0},
    };
    for (final c in checkins) {
      final day = c.timestamp.weekday - 1; // DateTime.weekday: 1=Mon..7=Sun
      final slot = _timeSlot(c.timestamp.hour);
      heatmap[day]![slot] = (heatmap[day]![slot] ?? 0) + 1;
    }

    // Weekly trend: last 8 weeks
    final weeklyTrend = List.filled(8, 0);
    for (final c in checkins) {
      final weeksAgo = now.difference(c.timestamp).inDays ~/ 7;
      if (weeksAgo < 8) weeklyTrend[7 - weeksAgo]++;
    }

    // At-risk: members with no check-in in 14+ days AND who have granted
    // tier>=1 (§4.3 — was ungated before this change: any member's name
    // could show up here regardless of consent).
    final uidsCheckedIn14 = checkins
        .where((c) => c.timestamp.isAfter(since14))
        .map((c) => c.uid)
        .toSet();
    final atRisk = members
        .where((m) =>
            !uidsCheckedIn14.contains(m.uid) && consentingUids.contains(m.uid))
        .toList();

    // k-anonymity-gated aggregate (§4.3) — averaged over the SAME
    // already-fetched 60-day `checkins` (no second query), restricted to
    // the consenting set. Below GymAnalyticsModel.kAnonymityThreshold
    // members, both averages are left at 0 and `sharingAggregateGated`
    // tells the screen to render nothing rather than a number that could
    // de-anonymize a tiny pool.
    final sharingIncludedCount = consentingUids.length;
    final sharingGated =
        sharingIncludedCount < GymAnalyticsModel.kAnonymityThreshold;
    var sharingAvgFreq = 0.0;
    var sharingAvgStreak = 0.0;
    if (!sharingGated) {
      final byUid = <String, List<DateTime>>{};
      for (final c in checkins) {
        if (!consentingUids.contains(c.uid)) continue;
        (byUid[c.uid] ??= []).add(c.timestamp);
      }
      var totalFreq = 0.0;
      var totalStreak = 0.0;
      for (final uid in consentingUids) {
        final times = byUid[uid] ?? const <DateTime>[];
        final last30 = times.where((t) => t.isAfter(since30)).length;
        totalFreq += last30 / 30 * 7;
        // Consecutive-week streak, same walk-backward-while-visited shape
        // as functions/summaries.js's aggregateGymFields — kept in sync
        // deliberately, not shared, since one is Dart and one is Node.
        var streakWeeks = 0;
        for (var w = 0; w < 8; w++) {
          final weekStart = now.subtract(Duration(days: (w + 1) * 7));
          final weekEnd = now.subtract(Duration(days: w * 7));
          final hasVisit =
              times.any((t) => t.isAfter(weekStart) && !t.isAfter(weekEnd));
          if (!hasVisit) break;
          streakWeeks++;
        }
        totalStreak += streakWeeks;
      }
      sharingAvgFreq = totalFreq / sharingIncludedCount;
      sharingAvgStreak = totalStreak / sharingIncludedCount;
    }

    // Top members this month
    final monthCounts = <String, int>{};
    for (final c in checkins.where((c) => c.timestamp.isAfter(since30))) {
      monthCounts[c.uid] = (monthCounts[c.uid] ?? 0) + 1;
    }
    final topEntries = members
        .map((m) => (member: m, count: monthCounts[m.uid] ?? 0))
        .where((e) => e.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final top5 = topEntries.take(5).toList();

    debugPrint(
        '[GymAnalyticsService] retention=${retention.toStringAsFixed(1)}% '
        'engagement=${engagement.toStringAsFixed(1)} atRisk=${atRisk.length}');

    return GymAnalyticsModel(
      totalMembers: total,
      activeThisWeek: uidsThisWeek.length,
      activeThisMonth: uidsThisMonth.length,
      retentionRate: retention,
      engagementScore: engagement.clamp(0.0, 100.0),
      checkInHeatmap: heatmap,
      weeklyTrend: weeklyTrend,
      atRiskMembers: atRisk,
      topMembers: top5,
      sharingIncludedCount: sharingIncludedCount,
      sharingAggregateGated: sharingGated,
      sharingAvgCheckInFrequencyPerWeek: sharingAvgFreq,
      sharingAvgStreakWeeks: sharingAvgStreak,
    );
  }

  // ── CSV export ──────────────────────────────────────────────────────────────

  /// The exact column list `exportCsv` writes — a single source of truth so
  /// the export-config sheet can show the exporter this list BEFORE
  /// exporting (§4.3: "hangi alanların gittiği ekranda yazılı" — which
  /// fields are exported must be shown on screen) without it ever drifting
  /// from what the CSV body actually contains.
  static const csvColumns = [
    'uid',
    'name',
    'joined_at',
    'total_checkins',
    'last_checkin',
    'tier',
  ];

  /// Exports check-in history as CSV, scoped to [since]..[until]. [since] is
  /// now a REQUIRED parameter, not an optional one defaulting to 90 days —
  /// §4.3 calls for a mandatory date range, not merely a generous default a
  /// caller could still bypass by omission (audit S10/C16e: the previous
  /// version was an unbounded read of the entire checkins collection).
  /// [members] is whatever set the CALLER already decided to include — pass
  /// a tier-filtered list (see `ProgressSharingService.
  /// getConsentingMemberUids`) for "only members who share progress"; this
  /// method itself only shapes rows from `checkins`, it does not re-check
  /// consent. [limit] still logs — never silently drops — if hit.
  Future<String> exportCsv(
    String gymId,
    List<GymMemberModel> members, {
    required DateTime since,
    DateTime? until,
    int limit = 20000,
  }) async {
    debugPrint('[GymAnalyticsService] exportCsv start: $gymId');

    final upperBound = until ?? DateTime.now();
    final snap = await _db
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(upperBound))
        .orderBy('timestamp')
        .limit(limit)
        .get();
    final checkins = snap.docs.map(CheckInModel.fromFirestore).toList();
    if (checkins.length >= limit) {
      debugPrint(
          '[GymAnalyticsService] exportCsv capped at $limit rows for $gymId');
    }

    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final c in checkins) {
      counts[c.uid] = (counts[c.uid] ?? 0) + 1;
      final prev = lastSeen[c.uid];
      if (prev == null || c.timestamp.isAfter(prev)) {
        lastSeen[c.uid] = c.timestamp;
      }
    }

    final buf = StringBuffer();
    buf.writeln(csvColumns.join(','));
    for (final m in members) {
      final name = (m.displayName ?? '').replaceAll('"', '""');
      buf.writeln([
        m.uid,
        '"$name"',
        m.joinedAt.toIso8601String(),
        counts[m.uid] ?? 0,
        lastSeen[m.uid]?.toIso8601String() ?? '',
        m.tier.name,
      ].join(','));
    }

    debugPrint('[GymAnalyticsService] exportCsv done: ${members.length} rows');
    return buf.toString();
  }
}
