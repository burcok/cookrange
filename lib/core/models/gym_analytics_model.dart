import 'gym_member_model.dart';

/// Value object holding all computed analytics for a single gym.
class GymAnalyticsModel {
  // Overview
  final int totalMembers;
  final int activeThisWeek;
  final int activeThisMonth;
  final double retentionRate;
  final double engagementScore;

  // Heatmap: [dayOfWeek 0=Mon..6=Sun][timeSlot 0=Morning..3=Night] = count
  final Map<int, Map<int, int>> checkInHeatmap;

  // Weekly trend: last 8 weeks; index 0 = 8 weeks ago, 7 = current week
  final List<int> weeklyTrend;

  // Members with no check-in in 14+ days — Faz 4 §4.3: scoped to members who
  // have granted progress_sharing tier>=1 for this gym (was ungated —
  // showed every at-risk member's NAME with zero permission check, audit
  // finding). Filtered inside GymAnalyticsService.computeAnalytics itself,
  // never by a caller, so there is no code path that forgets the filter.
  final List<GymMemberModel> atRiskMembers;

  // Top 5 members by check-in count this month
  final List<({GymMemberModel member, int count})> topMembers;

  // Faz 4 §4.3 — k-anonymity-gated aggregate ("toplulaştırılmış salon
  // görünümü") among tier>=1 consenting members only. [sharingIncludedCount]
  // also explains an empty [atRiskMembers] list honestly: 0 means "nobody
  // has shared yet" (a DIFFERENT state from "shared, but nobody's at risk"),
  // which the screen renders as a distinct empty state rather than nothing.
  //
  // All four fields below now come directly from
  // `getGymSharingAggregate`'s callable response (`functions/summaries.js`,
  // via GymSharingAggregateResult) — GymAnalyticsService no longer computes
  // them itself from raw check-in data. This closed a gap where the k≥5
  // gate was enforced only by the app choosing not to render a number, not
  // by the server withholding one; see GymSharingAggregateResult's doc
  // comment in progress_sharing_model.dart for the full story.
  final int sharingIncludedCount;

  // True below the k-anonymity floor (§4.3: "≥5 üye" — under 5, show
  // NOTHING rather than a small-sample-size number that could de-anonymize
  // someone). The two averages below are meaningless (left at 0) when true.
  final bool sharingAggregateGated;
  final double sharingAvgCheckInFrequencyPerWeek;
  final double sharingAvgStreakWeeks;

  // Reference value only — matches
  // GYM_SHARING_K_ANONYMITY_THRESHOLD in functions/summaries.js, which is
  // what actually enforces the gate now. Kept here for any UI copy that
  // wants to say "under 5 members" without a round-trip; changing this
  // constant does NOT change the server's behavior — the two must be
  // updated together (a TODO in that server-side constant's own comment
  // notes migrating both to `functions/config_schema.json`'s
  // `privacy.k_anonymity_threshold` once DECISIONS.md ADR-023's config read
  // path exists, which will end this hand-sync obligation).
  static const int kAnonymityThreshold = 5;

  const GymAnalyticsModel({
    required this.totalMembers,
    required this.activeThisWeek,
    required this.activeThisMonth,
    required this.retentionRate,
    required this.engagementScore,
    required this.checkInHeatmap,
    required this.weeklyTrend,
    required this.atRiskMembers,
    required this.topMembers,
    this.sharingIncludedCount = 0,
    this.sharingAggregateGated = true,
    this.sharingAvgCheckInFrequencyPerWeek = 0,
    this.sharingAvgStreakWeeks = 0,
  });

  int get heatmapMax => checkInHeatmap.values.fold(
        0,
        (prev, row) => row.values.fold(prev, (p, v) => p > v ? p : v),
      );

  static const empty = GymAnalyticsModel(
    totalMembers: 0,
    activeThisWeek: 0,
    activeThisMonth: 0,
    retentionRate: 0,
    engagementScore: 0,
    checkInHeatmap: {},
    weeklyTrend: [],
    atRiskMembers: [],
    topMembers: [],
  );
}
