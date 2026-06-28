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

  // Members with no check-in in 14+ days
  final List<GymMemberModel> atRiskMembers;

  // Top 5 members by check-in count this month
  final List<({GymMemberModel member, int count})> topMembers;

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
