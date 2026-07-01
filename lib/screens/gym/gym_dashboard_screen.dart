import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/models/gym_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/gym_application_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../../core/widgets/gym_share_card.dart';
import 'gym_application_pending_screen.dart';
import 'gym_community_screen.dart';
import 'gym_discovery_screen.dart';
import 'gym_members_screen.dart';
import 'gym_qr_screen.dart';
import 'gym_leaderboard_screen.dart';
import 'gym_analytics_screen.dart';
import 'gym_setup_screen.dart';

/// Gym owner dashboard — shows real gym data when gym is set up,
/// or a setup CTA when the owner hasn't created their gym yet.
class GymDashboardScreen extends StatefulWidget {
  const GymDashboardScreen({super.key});

  @override
  State<GymDashboardScreen> createState() => _GymDashboardScreenState();
}

class _GymDashboardScreenState extends State<GymDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  StreamSubscription<GymModel?>? _gymSub;
  GymModel? _gym;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.emphasized,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: AppMotion.emphasized,
    ));
    _initGym();
  }

  void _initGym() {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    _gymSub = GymService().getOwnerGymStream(uid).listen((gym) {
      if (!mounted) return;
      setState(() {
        _gym = gym;
        _loading = false;
      });
      if (!_animController.isCompleted) _animController.forward();
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _gymSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _goSetup() async {
    final result = await Navigator.of(context).push<dynamic>(
      AppTransitions.slideUp(GymSetupScreen(existingGym: _gym)),
    );
    if (result is GymModel && mounted) {
      // Dashboard will update via stream
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _gym?.resolvedBrandColor ?? Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, palette, primary, isDark, l10n),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: AppSkeletonList(itemCount: 4),
              ),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: _gym == null
                      ? _buildSetupState(
                          context, palette, primary, isDark, l10n)
                      : _buildDashboard(
                          context, palette, primary, isDark, l10n),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(
    BuildContext context,
    AppPalette palette,
    Color primary,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      stretch: true,
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded,
            color: palette.textPrimary, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (_gym != null) ...[
          IconButton(
            icon: Icon(Icons.share_rounded,
                color: palette.textSecondary, size: 22),
            tooltip: l10n.translate('share.share_gym'),
            onPressed: () => GymShareCard.share(context, _gym!),
          ),
          IconButton(
            icon: Icon(Icons.people_rounded,
                color: palette.textSecondary, size: 22),
            onPressed: () => Navigator.of(context).push(
              AppTransitions.slideUp(GymMembersScreen(
                gymId: _gym!.id,
                brandColor: _gym?.resolvedBrandColor,
              )),
            ),
            tooltip: l10n.translate('gym.members_title'),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: palette.textSecondary, size: 22),
            onPressed: _goSetup,
            tooltip: l10n.translate('gym.edit_title'),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          _gym?.name ?? l10n.translate('gym.dashboard_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: isDark ? 0.18 : 0.08),
                    palette.background,
                  ],
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: isDark ? 0.08 : 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Setup state (no gym yet) ────────────────────────────────────────────────

  Widget _buildSetupState(
    BuildContext context,
    AppPalette palette,
    Color primary,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final uid = context.read<UserProvider>().user?.uid ?? '';
    return StreamBuilder<GymApplicationModel?>(
      stream: GymApplicationService().getMyApplicationStream(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: AppSkeletonList(itemCount: 3),
          );
        }
        final app = snap.data;

        // Pending or rejected → show status screen body
        if (app != null) {
          return GymApplicationPendingScreen(
            showBackButton: false,
            status: app.status,
            reviewerNotes: app.reviewerNotes,
          );
        }

        // No application → show setup CTA
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            children: [
              _SetupCard(
                palette: palette,
                primary: primary,
                isDark: isDark,
                l10n: l10n,
                onSetup: _goSetup,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Active dashboard ────────────────────────────────────────────────────────

  Widget _buildDashboard(
    BuildContext context,
    AppPalette palette,
    Color primary,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final gym = _gym!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_rounded,
                  color: primary,
                  label: l10n.translate('gym.stat_members'),
                  value: '${gym.memberCount}',
                  palette: palette,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.location_on_rounded,
                  color: palette.success,
                  label: l10n.translate('gym.stat_location'),
                  value: gym.city?.isNotEmpty == true ? gym.city! : '--',
                  palette: palette,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.public_rounded,
                  color: palette.info,
                  label: l10n.translate('gym.stat_visibility'),
                  value: gym.isPublic
                      ? l10n.translate('gym.visibility_public')
                      : l10n.translate('gym.visibility_private'),
                  palette: palette,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.people_rounded,
                  color: const Color(0xFF6366F1),
                  label: l10n.translate('gym.action_members'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(GymMembersScreen(
                      gymId: gym.id,
                      brandColor: gym.resolvedBrandColor,
                    )),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.search_rounded,
                  color: const Color(0xFF10B981),
                  label: l10n.translate('gym.action_discover'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(const GymDiscoveryScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.forum_rounded,
                  color: const Color(0xFFF59E0B),
                  label: l10n.translate('gym.community_title'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(GymCommunityScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      isOwner: true,
                      brandColor: gym.resolvedBrandColor,
                    )),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.qr_code_rounded,
                  color: const Color(0xFF6366F1),
                  label: l10n.translate('gym.checkin_qr_title'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(GymQrScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      brandColor: gym.resolvedBrandColor,
                    )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.emoji_events_rounded,
                  color: const Color(0xFFEC4899),
                  label: l10n.translate('gym.action_leaderboard'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(GymLeaderboardScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      isOwner: true,
                      brandColor: gym.resolvedBrandColor,
                    )),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFFF59E0B),
                  label: l10n.translate('gym.analytics_title'),
                  palette: palette,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    AppTransitions.slideUp(GymAnalyticsScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      brandColor: gym.resolvedBrandColor,
                    )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly attendance chart
          _AttendanceChartSection(
            gymId: gym.id,
            palette: palette,
            primary: primary,
            isDark: isDark,
            l10n: l10n,
          ),
          const SizedBox(height: 16),

          // Gym info card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Gym logo / initials
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: gym.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: AppImage(
                                imageUrl: gym.logoUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                gym.name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gym.name,
                            style: AppText.of(context).titleM.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (gym.locationDisplay.isNotEmpty)
                            Text(
                              gym.locationDisplay,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        gym.subscriptionTier.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (gym.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    gym.description!,
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                  ),
                ],
                if (gym.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: gym.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setup card ────────────────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  final AppPalette palette;
  final Color primary;
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback onSetup;

  const _SetupCard({
    required this.palette,
    required this.primary,
    required this.isDark,
    required this.l10n,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('gym.setup_title'),
                      style: AppText.of(context).titleM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.translate('gym.setup_status'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: palette.warning,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.translate('gym.setup_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.translate('gym.setup_cta'),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onSetup();
            },
            icon: Icons.add_business_rounded,
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final AppPalette palette;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppText.of(context).titleM.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.of(context).labelS.copyWith(
                  color: palette.textSecondary,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Quick action tile ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final AppPalette palette;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.palette,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppText.of(context).bodyM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: palette.textSecondary),
        ],
      ),
    );
  }
}

// ── Attendance chart section ──────────────────────────────────────────────────

class _AttendanceChartSection extends StatelessWidget {
  final String gymId;
  final AppPalette palette;
  final Color primary;
  final bool isDark;
  final AppLocalizations l10n;

  const _AttendanceChartSection({
    required this.gymId,
    required this.palette,
    required this.primary,
    required this.isDark,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<int, int>>(
      stream: GymService().getWeeklyAttendanceStream(gymId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppCard(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppSkeletonList(itemCount: 1),
          );
        }
        final counts = snap.data ?? {for (var i = 0; i < 7; i++) i: 0};
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('gym.checkin_weekly_chart').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.textSecondary.withValues(alpha: 0.6),
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              _AttendanceChart(
                counts: counts,
                primary: primary,
                palette: palette,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  final Map<int, int> counts;
  final Color primary;
  final AppPalette palette;

  const _AttendanceChart({
    required this.counts,
    required this.primary,
    required this.palette,
  });

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    const maxHeight = 48.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final count = counts[i] ?? 0;
        final barHeight = maxCount == 0 ? 4.0 : (count / maxCount) * maxHeight;
        return _DayBar(
          label: _labels[i],
          count: count,
          barHeight: barHeight.clamp(4.0, maxHeight),
          primary: primary,
          palette: palette,
        );
      }),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String label;
  final int count;
  final double barHeight;
  final Color primary;
  final AppPalette palette;

  const _DayBar({
    required this.label,
    required this.count,
    required this.barHeight,
    required this.primary,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0)
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          )
        else
          const SizedBox(height: 14),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.emphasized,
          width: 28,
          height: barHeight,
          decoration: BoxDecoration(
            color: count > 0 ? primary : palette.border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }
}
