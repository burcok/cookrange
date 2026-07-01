import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_analytics_model.dart';
import '../../core/models/gym_member_model.dart';
import '../../core/models/gym_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/gym_analytics_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/ds/ds.dart';

class GymAnalyticsScreen extends StatefulWidget {
  final String? gymId;
  final String? gymName;
  final Color? brandColor;

  const GymAnalyticsScreen({
    super.key,
    this.gymId,
    this.gymName,
    this.brandColor,
  });

  @override
  State<GymAnalyticsScreen> createState() => _GymAnalyticsScreenState();
}

class _GymAnalyticsScreenState extends State<GymAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  GymAnalyticsModel? _analytics;
  List<GymMemberModel> _allMembers = [];
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  String _resolvedGymId = '';
  String _resolvedGymName = '';
  StreamSubscription<GymModel?>? _gymSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.emphasized,
    );
    if (widget.gymId != null && widget.gymId!.isNotEmpty) {
      _resolvedGymId = widget.gymId!;
      _resolvedGymName = widget.gymName ?? '';
      _loadAnalytics();
    }
    // else resolved in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedGymId.isEmpty && _gymSub == null) {
      final uid = context.read<UserProvider>().user?.uid;
      if (uid == null) return;
      _gymSub = GymService().getOwnerGymStream(uid).listen((gym) {
        if (gym == null || !mounted) return;
        _gymSub?.cancel();
        _gymSub = null;
        _resolvedGymId = gym.id;
        _resolvedGymName = gym.name;
        _loadAnalytics();
      });
    }
  }

  @override
  void dispose() {
    _gymSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final membersSnap = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(_resolvedGymId)
          .collection('members')
          .limit(500)
          .get();
      _allMembers = membersSnap.docs.map(GymMemberModel.fromFirestore).toList();

      final analytics =
          await GymAnalyticsService().computeAnalytics(_resolvedGymId);

      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _loading = false;
      });
      unawaited(_animController.forward(from: 0));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final l10n = AppLocalizations.of(context);
    try {
      unawaited(HapticFeedback.mediumImpact());
      final csv =
          await GymAnalyticsService().exportCsv(_resolvedGymId, _allMembers);
      if (!mounted) return;
      await Share.share(
        csv,
        subject: '$_resolvedGymName — Analytics Export',
      );
      if (mounted)
        AppSnackBar.success(
            context, l10n.translate('gym.analytics_export_success'));
    } catch (e) {
      if (mounted)
        AppSnackBar.error(
            context, l10n.translate('gym.analytics_export_error'));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _resolvedGymName,
              style: AppText.of(context).titleM.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.translate('gym.analytics_title'),
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textSecondary),
            ),
          ],
        ),
        actions: [
          if (!_loading && _analytics != null)
            _exporting
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: palette.textSecondary),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.file_download_outlined,
                        color: palette.textSecondary, size: 22),
                    onPressed: _export,
                    tooltip: l10n.translate('gym.analytics_export_csv'),
                  ),
        ],
      ),
      body: _buildBody(context, palette, l10n),
    );
  }

  Widget _buildBody(
      BuildContext context, AppPalette palette, AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: AppSkeletonList(itemCount: 5),
      );
    }

    if (_error != null) {
      return Center(
        child: AppErrorState(
          title: l10n.translate('gym.analytics_loading_error'),
          message: _error,
          retryLabel: 'Retry',
          onRetry: _loadAnalytics,
        ),
      );
    }

    final analytics = _analytics!;
    final primary = widget.brandColor ?? Theme.of(context).primaryColor;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Overview stats grid
            _OverviewGrid(
                analytics: analytics,
                palette: palette,
                primary: primary,
                l10n: l10n),
            const SizedBox(height: 16),

            // 2. Weekly trend
            _WeeklyTrendCard(
                analytics: analytics,
                palette: palette,
                primary: primary,
                l10n: l10n),
            const SizedBox(height: 16),

            // 3. Heatmap
            _HeatmapCard(
                analytics: analytics,
                palette: palette,
                primary: primary,
                l10n: l10n),
            const SizedBox(height: 16),

            // 4. At-risk members
            if (analytics.atRiskMembers.isNotEmpty) ...[
              _AtRiskSection(
                  analytics: analytics, palette: palette, l10n: l10n),
              const SizedBox(height: 16),
            ],

            // 5. Top performers
            if (analytics.topMembers.isNotEmpty) ...[
              _TopPerformersSection(
                  analytics: analytics,
                  palette: palette,
                  primary: primary,
                  l10n: l10n),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Overview grid ─────────────────────────────────────────────────────────────

class _OverviewGrid extends StatelessWidget {
  final GymAnalyticsModel analytics;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _OverviewGrid({
    required this.analytics,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        icon: Icons.people_rounded,
        color: const Color(0xFF3B82F6),
        label: l10n.translate('gym.analytics_total_members'),
        value: '${analytics.totalMembers}',
      ),
      (
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF10B981),
        label: l10n.translate('gym.analytics_active_week'),
        value: '${analytics.activeThisWeek}',
      ),
      (
        icon: Icons.repeat_rounded,
        color: const Color(0xFFF97316),
        label: l10n.translate('gym.analytics_retention'),
        value: '${analytics.retentionRate.toStringAsFixed(0)}%',
      ),
      (
        icon: Icons.bolt_rounded,
        color: const Color(0xFF8B5CF6),
        label: l10n.translate('gym.analytics_engagement'),
        value: '${analytics.engagementScore.toStringAsFixed(0)}/100',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: stats
          .map((s) => _StatCard(
                icon: s.icon,
                color: s.color,
                label: s.label,
                value: s.value,
                palette: palette,
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final AppPalette palette;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            builder: (ctx, t, _) {
              return Text(
                value,
                style: AppText.of(ctx).headlineS.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.of(context).labelS.copyWith(
                  color: palette.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly trend chart ────────────────────────────────────────────────────────

class _WeeklyTrendCard extends StatelessWidget {
  final GymAnalyticsModel analytics;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _WeeklyTrendCard({
    required this.analytics,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.analytics_weekly_trend').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          _BarChart(
            data: analytics.weeklyTrend,
            primary: primary,
            palette: palette,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<int> data;
  final Color primary;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _BarChart({
    required this.data,
    required this.primary,
    required this.palette,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 64.0;
    final maxVal = data.fold(0, (a, b) => a > b ? a : b);
    final weeksAgoLabel = l10n.translate('gym.analytics_weeks_ago');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (i) {
        final count = data[i];
        final barHeight = maxVal == 0
            ? 4.0
            : (count / maxVal * maxBarHeight).clamp(4.0, maxBarHeight);
        final age = data.length - 1 - i; // 0 = newest
        final opacity = 0.4 + (1.0 - age / (data.length - 1)) * 0.6;
        final label = i == data.length - 1 ? '0w' : '$age$weeksAgoLabel';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              )
            else
              const SizedBox(height: 13),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.emphasized,
              width: 28,
              height: barHeight,
              decoration: BoxDecoration(
                color: count > 0
                    ? primary.withValues(alpha: opacity)
                    : palette.border.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: palette.textTertiary,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final GymAnalyticsModel analytics;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _HeatmapCard({
    required this.analytics,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final timeSlots = [
      l10n.translate('gym.analytics_heatmap_morning'),
      l10n.translate('gym.analytics_heatmap_afternoon'),
      l10n.translate('gym.analytics_heatmap_evening'),
      l10n.translate('gym.analytics_heatmap_night'),
    ];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = analytics.heatmapMax;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.analytics_heatmap_title').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Header row: time-slot labels
          Row(
            children: [
              const SizedBox(width: 36), // day label column
              ...List.generate(
                  4,
                  (s) => Expanded(
                        child: Text(
                          timeSlots[s],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: palette.textTertiary,
                          ),
                        ),
                      )),
            ],
          ),
          const SizedBox(height: 8),
          // Grid rows
          ...List.generate(7, (d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      dayLabels[d],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  ...List.generate(4, (s) {
                    final count = analytics.checkInHeatmap[d]?[s] ?? 0;
                    final intensity =
                        maxVal == 0 ? 0.0 : (count / maxVal).clamp(0.0, 1.0);
                    final cellColor = Color.lerp(
                      palette.surfaceVariant,
                      primary,
                      intensity,
                    )!;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Tooltip(
                          message: '$count check-ins',
                          child: AnimatedContainer(
                            duration: AppMotion.normal,
                            curve: AppMotion.emphasized,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── At-risk members ───────────────────────────────────────────────────────────

class _AtRiskSection extends StatefulWidget {
  final GymAnalyticsModel analytics;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _AtRiskSection({
    required this.analytics,
    required this.palette,
    required this.l10n,
  });

  @override
  State<_AtRiskSection> createState() => _AtRiskSectionState();
}

class _AtRiskSectionState extends State<_AtRiskSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final members = widget.analytics.atRiskMembers;
    final displayed = _showAll ? members : members.take(5).toList();
    final hasMore = members.length > 5;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: widget.palette.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.l10n.translate('gym.analytics_at_risk_title'),
                  style: AppText.of(context).titleM.copyWith(
                        color: widget.palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.palette.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${members.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.palette.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...displayed.map((m) => _AtRiskTile(
                member: m,
                palette: widget.palette,
                l10n: widget.l10n,
              )),
          if (hasMore) ...[
            const SizedBox(height: 8),
            Center(
              child: AppButton(
                label: _showAll
                    ? 'Show less'
                    : '${widget.l10n.translate('gym.analytics_see_all')} ${members.length}',
                onPressed: () => setState(() => _showAll = !_showAll),
                size: AppButtonSize.small,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AtRiskTile extends StatelessWidget {
  final GymMemberModel member;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _AtRiskTile({
    required this.member,
    required this.palette,
    required this.l10n,
  });

  String _daysAgoText(DateTime? lastCheckIn, AppLocalizations l10n) {
    if (lastCheckIn == null) return 'Never checked in';
    final days = DateTime.now().difference(lastCheckIn).inDays;
    return '$days ${l10n.translate('gym.analytics_at_risk_days')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => openUserProfile(context, userId: member.uid),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: palette.surfaceVariant,
              backgroundImage: member.photoURL != null
                  ? CachedNetworkImageProvider(member.photoURL!)
                  : null,
              child: member.photoURL == null
                  ? Text(
                      (member.displayName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName ?? l10n.translate('gym.member_no_name'),
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    _daysAgoText(member.lastCheckIn, l10n),
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.warning,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: palette.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Top performers ────────────────────────────────────────────────────────────

class _TopPerformersSection extends StatelessWidget {
  final GymAnalyticsModel analytics;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _TopPerformersSection({
    required this.analytics,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.translate('gym.analytics_top_performers'),
                style: AppText.of(context).titleM.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...analytics.topMembers.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final e = entry.value;
            return _TopMemberTile(
              rank: rank,
              member: e.member,
              count: e.count,
              palette: palette,
              primary: primary,
              l10n: l10n,
            );
          }),
        ],
      ),
    );
  }
}

class _TopMemberTile extends StatelessWidget {
  final int rank;
  final GymMemberModel member;
  final int count;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _TopMemberTile({
    required this.rank,
    required this.member,
    required this.count,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  Color _rankColor(int rank) => switch (rank) {
        1 => const Color(0xFFFFD700), // gold
        2 => const Color(0xFFC0C0C0), // silver
        3 => const Color(0xFFCD7F32), // bronze
        _ => const Color(0xFF6B7280),
      };

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(rank);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => openUserProfile(context, userId: member.uid),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Rank circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: palette.surfaceVariant,
              backgroundImage: member.photoURL != null
                  ? CachedNetworkImageProvider(member.photoURL!)
                  : null,
              child: member.photoURL == null
                  ? Text(
                      (member.displayName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName ?? l10n.translate('gym.member_no_name'),
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '$count ${l10n.translate('gym.analytics_checkins_month')}',
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: palette.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
