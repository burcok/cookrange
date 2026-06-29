import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'admin_dishes_screen.dart';
import 'application_review_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_reports_screen.dart';

/// Admin-only screen for reviewing pending coach/gym applications,
/// managing users, and viewing application history.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 13, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.translate('admin.panel_title'),
              style: t.titleM
                  .copyWith(color: palette.textPrimary, fontWeight: FontWeight.w800),
            ),
            StreamBuilder<int>(
              stream: AdminService().pendingCountStream(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  margin: EdgeInsets.only(left: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.error, palette.error.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    l10n
                        .translate('admin.pending_badge')
                        .replaceFirst('{n}', '$count'),
                    style: t.labelS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight + 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabs,
                labelColor: primary,
                unselectedLabelColor: palette.textSecondary,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelStyle: t.labelM.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: t.labelM.copyWith(fontWeight: FontWeight.w500),
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: primary, width: 3),
                  insets: EdgeInsets.symmetric(horizontal: 8.w),
                ),
                tabs: [
                  Tab(
                    text: l10n.translate('admin.dashboard_title'),
                    icon: Icon(Icons.dashboard_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_coaches'),
                    icon: Icon(Icons.school_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_gyms'),
                    icon: Icon(Icons.business_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_users'),
                    icon: Icon(Icons.people_outline_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_history'),
                    icon: Icon(Icons.history_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_audit'),
                    icon: Icon(Icons.security_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_broadcasts'),
                    icon: Icon(Icons.campaign_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_config'),
                    icon: Icon(Icons.tune_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_credits'),
                    icon: Icon(Icons.bolt_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_programs'),
                    icon: Icon(Icons.library_books_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_billing'),
                    icon: Icon(Icons.credit_card_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_abuse'),
                    icon: Icon(Icons.shield_moon_rounded, size: 16.r),
                  ),
                  Tab(
                    text: l10n.translate('admin.tab_analytics'),
                    icon: Icon(Icons.bar_chart_rounded, size: 16.r),
                  ),
                ],
              ),
              // Subtle brand gradient accent line below tabs
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppPalette.brand.withValues(alpha: 0.4),
                      AppPalette.brand,
                      AppPalette.brand.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AdminOverviewTab(tabs: _tabs, rootContext: context),
          _CoachApplicationsList(palette: palette, l10n: l10n, t: t),
          _GymApplicationsList(palette: palette, l10n: l10n, t: t),
          _UsersTab(palette: palette, l10n: l10n, t: t),
          _HistoryTab(palette: palette, l10n: l10n, t: t),
          _AuditLogTab(palette: palette, l10n: l10n, t: t),
          _BroadcastsTab(palette: palette, l10n: l10n, t: t),
          _ConfigTab(palette: palette, l10n: l10n, t: t),
          _CreditsAndCodesTab(palette: palette, l10n: l10n, t: t),
          _ProgramReviewTab(palette: palette, l10n: l10n, t: t),
          _BillingTab(palette: palette, l10n: l10n, t: t),
          _AbuseTab(palette: palette, l10n: l10n, t: t),
          _AnalyticsTab(palette: palette, l10n: l10n, t: t),
        ],
      ),
    );
  }
}

// ── Admin Overview Tab ─────────────────────────────────────────────────────

class _AdminOverviewTab extends StatelessWidget {
  final TabController tabs;
  final BuildContext rootContext;

  const _AdminOverviewTab({required this.tabs, required this.rootContext});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    final todayLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome header ────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('admin.dashboard_title'),
                        style: t.headlineS.copyWith(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        todayLabel,
                        style: t.bodyM.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppPalette.brand.withValues(alpha: 0.15),
                        AppPalette.brand.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppPalette.brand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded,
                          size: 14.r, color: AppPalette.brand),
                      SizedBox(width: 5.w),
                      Text(
                        'Admin',
                        style: t.labelS.copyWith(
                          color: AppPalette.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── 2×2 stat grid ───────────────────────────────────────
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.95,
            ),
            children: [
              // Pending Coaches
              RepaintBoundary(
                child: _StatCard(
                  label: l10n.translate('admin.dashboard_pending_coaches'),
                  icon: Icons.school_rounded,
                  accentColor: palette.warning,
                  stream: AdminService()
                      .pendingCoachApplicationsStream()
                      .map((list) => list.length),
                  showBadgeWhenNonZero: true,
                  onTap: () => tabs.animateTo(1),
                  palette: palette,
                  t: t,
                ),
              ),
              // Pending Gyms
              RepaintBoundary(
                child: _StatCard(
                  label: l10n.translate('admin.dashboard_pending_gyms'),
                  icon: Icons.fitness_center_rounded,
                  accentColor: palette.info,
                  stream: AdminService()
                      .pendingGymApplicationsStream()
                      .map((list) => list.length),
                  showBadgeWhenNonZero: true,
                  onTap: () => tabs.animateTo(2),
                  palette: palette,
                  t: t,
                ),
              ),
              // Total Users
              RepaintBoundary(
                child: _StatCard(
                  label: l10n.translate('admin.dashboard_total_users'),
                  icon: Icons.people_rounded,
                  accentColor: palette.success,
                  stream: AdminService().userCountStream(),
                  showBadgeWhenNonZero: false,
                  onTap: () => tabs.animateTo(3),
                  palette: palette,
                  t: t,
                ),
              ),
              // Open Reports
              RepaintBoundary(
                child: _StatCard(
                  label: l10n.translate('admin.dashboard_open_reports'),
                  icon: Icons.flag_rounded,
                  accentColor: palette.error,
                  stream: AdminService().openReportCountStream(),
                  showBadgeWhenNonZero: true,
                  onTap: () => Navigator.of(rootContext).push(
                    AppTransitions.slideRight(const AdminReportsScreen()),
                  ),
                  palette: palette,
                  t: t,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // ── Weekly Activity chart ───────────────────────────────
          _WeeklyActivityCard(palette: palette, t: t, l10n: l10n),
          SizedBox(height: 16.h),
          // ── Quick-access row ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickAccessCard(
                  label: l10n.translate('admin.manage_config'),
                  description: 'App flags & AI settings',
                  icon: Icons.tune_rounded,
                  accentColor: palette.info,
                  onTap: () => tabs.animateTo(7),
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _QuickAccessCard(
                  label: l10n.translate('admin.manage_credits'),
                  description: 'Grant & track AI credits',
                  icon: Icons.bolt_rounded,
                  accentColor: palette.warning,
                  onTap: () => tabs.animateTo(8),
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _QuickAccessCard(
                  label: l10n.translate('admin.manage_dishes'),
                  description: 'Edit recipe database',
                  icon: Icons.restaurant_menu_rounded,
                  accentColor: palette.success,
                  onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(const AdminDishesScreen())),
                  palette: palette,
                  t: t,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // ── All-clear banner ────────────────────────────────────
          StreamBuilder<int>(
            stream: AdminService().pendingCountStream(),
            builder: (context, snap) {
              final count = snap.data ?? 1; // default 1 so banner is hidden
              final allClear = count == 0;
              final reduceMotion = MediaQuery.of(context).disableAnimations;
              return AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppMotion.normal,
                curve: AppMotion.standard,
                height: allClear ? null : 0,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: palette.success.withValues(alpha: 0.35),
                  ),
                ),
                padding: allClear
                    ? EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h)
                    : EdgeInsets.zero,
                child: allClear
                    ? Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: palette.success, size: 22.r),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              l10n.translate('admin.dashboard_all_clear'),
                              style: t.bodyM.copyWith(
                                color: palette.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Stream<int> stream;
  final bool showBadgeWhenNonZero;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText t;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.stream,
    required this.showBadgeWhenNonZero,
    required this.onTap,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card.r),
      child: Stack(
        children: [
          AppGlassCard(
            onTap: onTap,
            blur: AppPalette.glassBlurSubtle,
            padding: EdgeInsets.fromLTRB(14.r, 14.r, 14.r, 17.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon + badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient icon box
                    Container(
                      width: 42.r,
                      height: 42.r,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withValues(alpha: 0.25),
                            accentColor.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11.r),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(icon, color: accentColor, size: 20.r),
                    ),
                    // Badge number in top-right
                    StreamBuilder<int>(
                      stream: stream,
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        if (!showBadgeWhenNonZero || count == 0) {
                          return const SizedBox.shrink();
                        }
                        return Semantics(
                          label: '$count pending',
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 7.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                // Count
                StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return AppSkeletonBox(height: 36.h, width: 60.w);
                    }
                    return Text(
                      '${snap.data ?? 0}',
                      style: t.headlineL.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    );
                  },
                ),
                SizedBox(height: 2.h),
                // Label
                Text(
                  label,
                  style: t.labelM.copyWith(color: palette.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                // Tap hint
                Text(
                  'Tap to manage →',
                  style: t.labelS.copyWith(
                    color: accentColor.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Bottom accent bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.6),
                    accentColor,
                    accentColor.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Activity Card & Bar Chart ──────────────────────────────────────

class _WeeklyActivityCard extends StatelessWidget {
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _WeeklyActivityCard({
    required this.palette,
    required this.t,
    required this.l10n,
  });

  // Hardcoded fake data for display purposes — visual trend indicator only
  static const _fakeData = [3.0, 7.0, 5.0, 12.0, 8.0, 15.0, 10.0];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      blur: AppPalette.glassBlurSubtle,
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly Activity',
                  style: t.titleM.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Last 7 days',
                  style: t.labelS.copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 100.h,
            child: CustomPaint(
              painter: _ActivityBarChartPainter(
                data: _fakeData,
                dayLabels: _dayLabels,
                barColorLight: AppPalette.brand.withValues(alpha: 0.5),
                barColorDark: AppPalette.brand,
                labelColor: palette.textTertiary,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> dayLabels;
  final Color barColorLight;
  final Color barColorDark;
  final Color labelColor;

  const _ActivityBarChartPainter({
    required this.data,
    required this.dayLabels,
    required this.barColorLight,
    required this.barColorDark,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final maxVal = data.reduce(math.max);
    if (maxVal <= 0) return;

    final count = data.length;
    final totalWidth = size.width;
    final barGroupWidth = totalWidth / count;
    const barWidthFraction = 0.55;
    final barWidth = barGroupWidth * barWidthFraction;

    final labelPaint = TextPainter(textDirection: ui.TextDirection.ltr);
    final gradientRect = Rect.fromLTWH(0, 0, barWidth, chartHeight);

    for (int i = 0; i < count; i++) {
      final normalised = data[i] / maxVal;
      final barH = normalised * chartHeight * 0.88;
      final left = i * barGroupWidth + (barGroupWidth - barWidth) / 2;
      final top = chartHeight - barH;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      final barGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [barColorDark, barColorLight],
      );

      final paint = Paint()
        ..shader = barGradient.createShader(
          gradientRect.translate(left, top),
        );

      canvas.drawRRect(rrect, paint);

      // Day label
      labelPaint
        ..text = TextSpan(
          text: dayLabels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        )
        ..layout(maxWidth: barGroupWidth);

      labelPaint.paint(
        canvas,
        Offset(
          left + barWidth / 2 - labelPaint.width / 2,
          chartHeight + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityBarChartPainter old) =>
      old.data != data ||
      old.barColorDark != barColorDark ||
      old.labelColor != labelColor;
}

// ── Coach Applications List ────────────────────────────────────────────────

class _CoachApplicationsList extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _CoachApplicationsList({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoachApplicationModel>>(
      stream: AdminService().pendingCoachApplicationsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 4);
        }
        final apps = snap.data ?? [];
        if (apps.isEmpty) {
          return AppEmptyState(
            icon: Icons.check_circle_outline,
            title: l10n.translate('admin.no_pending'),
            message: l10n.translate('admin.no_pending_coaches'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: apps.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            return RepaintBoundary(
              child: _CoachAppCard(
                app: app,
                palette: palette,
                t: t,
                l10n: l10n,
                onTap: () => Navigator.of(ctx).push(
                  AppTransitions.slideRight(
                      ApplicationReviewScreen.forCoach(app)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Gym Applications List ──────────────────────────────────────────────────

class _GymApplicationsList extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _GymApplicationsList({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GymApplicationModel>>(
      stream: AdminService().pendingGymApplicationsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 4);
        }
        final apps = snap.data ?? [];
        if (apps.isEmpty) {
          return AppEmptyState(
            icon: Icons.check_circle_outline,
            title: l10n.translate('admin.no_pending'),
            message: l10n.translate('admin.no_pending_gyms'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: apps.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            return RepaintBoundary(
              child: _GymAppCard(
                app: app,
                palette: palette,
                t: t,
                l10n: l10n,
                onTap: () => Navigator.of(ctx).push(
                  AppTransitions.slideRight(
                      ApplicationReviewScreen.forGym(app)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Users Tab ──────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _UsersTab({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService().getUsersStream(),
        builder: (context, snap) {
          final count = snap.data?.length ?? 0;
          return AppCard(
            onTap: () => Navigator.of(context).push(
              AppTransitions.slideRight(
                  const AdminUserManagementScreen()),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.r,
                  height: 48.r,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .primaryColor
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people_outline_rounded,
                      color: Theme.of(context).primaryColor, size: 24.r),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('admin.users_title'),
                        style: t.titleM
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2.h),
                      if (snap.connectionState == ConnectionState.waiting)
                        _Chip(
                          icon: Icons.hourglass_empty_rounded,
                          label: '…',
                          palette: palette,
                          t: t,
                        )
                      else
                        _Chip(
                          icon: Icons.person_outline,
                          label: '$count users',
                          palette: palette,
                          t: t,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: palette.textSecondary, size: 20.r),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── History Tab ────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _HistoryTab({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  bool _showCoaches = true;
  // null = All, 'approved', 'rejected'
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        // ── Type toggle ──────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
          child: Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: l10n.translate('admin.tab_coaches'),
                  selected: _showCoaches,
                  primary: primary,
                  palette: palette,
                  t: t,
                  onTap: () => setState(() => _showCoaches = true),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _ToggleChip(
                  label: l10n.translate('admin.tab_gyms'),
                  selected: !_showCoaches,
                  primary: primary,
                  palette: palette,
                  t: t,
                  onTap: () => setState(() => _showCoaches = false),
                ),
              ),
            ],
          ),
        ),
        // ── Status filter chips ───────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            children: [
              _FilterChipButton(
                label: l10n.translate('admin.filter_all'),
                selected: _statusFilter == null,
                primary: primary,
                palette: palette,
                t: t,
                onTap: () => setState(() => _statusFilter = null),
              ),
              SizedBox(width: 8.w),
              _FilterChipButton(
                label: l10n.translate('admin.filter_approved'),
                selected: _statusFilter == 'approved',
                primary: primary,
                palette: palette,
                t: t,
                onTap: () => setState(() => _statusFilter = 'approved'),
              ),
              SizedBox(width: 8.w),
              _FilterChipButton(
                label: l10n.translate('admin.filter_rejected'),
                selected: _statusFilter == 'rejected',
                primary: primary,
                palette: palette,
                t: t,
                onTap: () => setState(() => _statusFilter = 'rejected'),
              ),
            ],
          ),
        ),
        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: _showCoaches
              ? _CoachHistoryList(
                  statusFilter: _statusFilter,
                  palette: palette,
                  l10n: l10n,
                  t: t,
                )
              : _GymHistoryList(
                  statusFilter: _statusFilter,
                  palette: palette,
                  l10n: l10n,
                  t: t,
                ),
        ),
      ],
    );
  }
}

class _CoachHistoryList extends StatelessWidget {
  final String? statusFilter;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _CoachHistoryList({
    required this.statusFilter,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoachApplicationModel>>(
      stream: AdminService()
          .coachApplicationHistoryStream(status: statusFilter),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 5);
        }
        final apps = snap.data ?? [];
        if (apps.isEmpty) {
          return AppEmptyState(
            icon: Icons.history_rounded,
            title: l10n.translate('admin.history_title'),
            message: l10n.translate('admin.no_pending_coaches'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          itemCount: apps.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            final isApproved =
                app.status == CoachApplicationStatus.approved;
            return RepaintBoundary(
              child: _HistoryCard(
                name: app.displayName,
                subtitle:
                    '${app.specializations.take(2).join(', ')} · ${app.experienceYears} yrs',
                isApproved: isApproved,
                reviewedAt: app.reviewedAt,
                palette: palette,
                t: t,
                l10n: l10n,
                onTap: () => Navigator.of(ctx).push(
                  AppTransitions.slideRight(
                      ApplicationReviewScreen.forCoach(app)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GymHistoryList extends StatelessWidget {
  final String? statusFilter;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _GymHistoryList({
    required this.statusFilter,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GymApplicationModel>>(
      stream:
          AdminService().gymApplicationHistoryStream(status: statusFilter),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 5);
        }
        final apps = snap.data ?? [];
        if (apps.isEmpty) {
          return AppEmptyState(
            icon: Icons.history_rounded,
            title: l10n.translate('admin.history_title'),
            message: l10n.translate('admin.no_pending_gyms'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          itemCount: apps.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            final isApproved =
                app.status == GymApplicationStatus.approved;
            return RepaintBoundary(
              child: _HistoryCard(
                name: app.gymName,
                subtitle: '${app.city} · ${app.tags.take(2).join(', ')}',
                isApproved: isApproved,
                reviewedAt: app.reviewedAt,
                palette: palette,
                t: t,
                l10n: l10n,
                onTap: () => Navigator.of(ctx).push(
                  AppTransitions.slideRight(
                      ApplicationReviewScreen.forGym(app)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── History Card ───────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isApproved;
  final DateTime? reviewedAt;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.name,
    required this.subtitle,
    required this.isApproved,
    required this.reviewedAt,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isApproved ? palette.success : palette.error;
    final statusLabel = isApproved
        ? l10n.translate('admin.action_approved')
        : l10n.translate('admin.action_rejected');

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: statusColor,
              size: 22.r,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 2.h),
                Text(subtitle,
                    style: t.bodyM.copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        statusLabel,
                        style: t.labelS.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (reviewedAt != null) ...[
                      SizedBox(width: 6.w),
                      _Chip(
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat('MMM d, y').format(reviewedAt!),
                        palette: palette,
                        t: t,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: palette.textSecondary, size: 20.r),
        ],
      ),
    );
  }
}

// ── Toggle Chip ────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.palette,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? primary : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: t.labelM.copyWith(
              color: selected ? Colors.white : palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter Chip Button ─────────────────────────────────────────────────────

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.primary,
    required this.palette,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(20.r),
            border: selected
                ? Border.all(color: primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            label,
            style: t.labelS.copyWith(
              color: selected ? primary : palette.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Coach App Card ─────────────────────────────────────────────────────────

class _CoachAppCard extends StatelessWidget {
  final CoachApplicationModel app;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _CoachAppCard({
    required this.app,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final hasCertDoc = app.certDocUrl != null;
    final hasIdDoc = app.idDocUrl != null;
    final hasAnyDoc = hasCertDoc || hasIdDoc;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, color: primary, size: 22.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      style: t.titleM.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${app.specializations.take(3).join(', ')} · ${app.experienceYears} yrs',
                      style: t.bodyM.copyWith(color: palette.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(Icons.chevron_right_rounded,
                  color: palette.textSecondary, size: 20.r),
            ],
          ),
          // ── Chips row ────────────────────────────────────────────
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('MMM d, y').format(app.submittedAt),
                palette: palette,
                t: t,
              ),
              if (app.contactPhone.isNotEmpty)
                _Chip(
                  icon: Icons.phone_outlined,
                  label: app.contactPhone,
                  palette: palette,
                  t: t,
                ),
              _Chip(
                icon: Icons.attach_file,
                label: '${app.evidenceUrls.length} evidence',
                palette: palette,
                t: t,
              ),
              _Chip(
                icon: Icons.people_outline,
                label: '${app.references.length} refs',
                palette: palette,
                t: t,
              ),
            ],
          ),
          // ── Documents row ─────────────────────────────────────────
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: hasAnyDoc
                ? [
                    if (hasCertDoc)
                      _DocChip(
                        label: l10n.translate('admin.doc_coach_cert'),
                        url: app.certDocUrl!,
                        palette: palette,
                      ),
                    if (hasIdDoc)
                      _DocChip(
                        label: l10n.translate('admin.doc_id'),
                        url: app.idDocUrl!,
                        palette: palette,
                      ),
                  ]
                : [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color: palette.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 12.r, color: palette.warning),
                          SizedBox(width: 4.w),
                          Text(
                            l10n.translate('admin.doc_none'),
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

// ── Gym Application Card ───────────────────────────────────────────────────

class _GymAppCard extends StatelessWidget {
  final GymApplicationModel app;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _GymAppCard({
    required this.app,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.onTap,
  });

  Color? _parseBrandColor() {
    final hex = app.brandColor;
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    if (value == null) return null;
    return Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final brandColor = _parseBrandColor();
    final hasLocation = app.latitude != null && app.longitude != null;
    final hasBusinessDoc = app.businessDocUrl != null;
    final hasIdDoc = app.idDocUrl != null;
    final hasAnyDoc = hasBusinessDoc || hasIdDoc;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: (brandColor ?? primary).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.business_rounded,
                    color: brandColor ?? primary, size: 22.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.gymName,
                            style:
                                t.titleM.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Brand color swatch
                        if (brandColor != null) ...[
                          SizedBox(width: 6.w),
                          Container(
                            width: 16.r,
                            height: 16.r,
                            decoration: BoxDecoration(
                              color: brandColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.border,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    // Location line
                    Text(
                      hasLocation
                          ? '📍 ${app.city} (${app.latitude!.toStringAsFixed(4)}, ${app.longitude!.toStringAsFixed(4)})'
                          : '📍 ${app.city}',
                      style: t.bodyM.copyWith(color: palette.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(Icons.chevron_right_rounded,
                  color: palette.textSecondary, size: 20.r),
            ],
          ),
          // ── Chips row ────────────────────────────────────────────
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              // Submitted date
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('MMM d, y').format(app.submittedAt),
                palette: palette,
                t: t,
              ),
              // Phone
              if (app.contactPhone.isNotEmpty)
                _Chip(
                  icon: Icons.phone_outlined,
                  label: app.contactPhone,
                  palette: palette,
                  t: t,
                ),
              // Tags (up to 3)
              ...app.tags.take(3).map((tag) => _Chip(
                    icon: Icons.label_outline_rounded,
                    label: tag,
                    palette: palette,
                    t: t,
                  )),
            ],
          ),
          // ── Documents row ─────────────────────────────────────────
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: hasAnyDoc
                ? [
                    if (hasBusinessDoc)
                      _DocChip(
                        label: l10n.translate('admin.doc_business_license'),
                        url: app.businessDocUrl!,
                        palette: palette,
                      ),
                    if (hasIdDoc)
                      _DocChip(
                        label: l10n.translate('admin.doc_id'),
                        url: app.idDocUrl!,
                        palette: palette,
                      ),
                  ]
                : [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color: palette.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 12.r, color: palette.warning),
                          SizedBox(width: 4.w),
                          Text(
                            l10n.translate('admin.doc_none'),
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

// ── Audit Log Tab ─────────────────────────────────────────────────────────────

class _AuditLogTab extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _AuditLogTab({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService().auditLogStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppSkeletonList(),
          );
        }
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return AppEmptyState(
            icon: Icons.security_rounded,
            title: l10n.translate('admin.audit_empty_title'),
            message: l10n.translate('admin.audit_empty_msg'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: entries.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (_, i) {
            final e = entries[i];
            final action = e['action'] as String? ?? '?';
            final actorUid = e['actorUid'] as String? ?? '';
            final targetUid = e['targetUid'] as String?;
            final ts = e['createdAt'];
            String timeLabel = '';
            if (ts is Timestamp) {
              final dt = ts.toDate().toLocal();
              timeLabel = DateFormat('MMM d, y · HH:mm').format(dt);
            }
            return RepaintBoundary(child: AppCard(
              elevated: false,
              bordered: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: palette.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          action,
                          style: t.labelS.copyWith(
                            color: palette.info,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(timeLabel,
                          style: t.labelS
                              .copyWith(color: palette.textTertiary)),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${l10n.translate('admin.audit_actor')}: $actorUid',
                    style:
                        t.labelS.copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (targetUid != null && targetUid.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      '${l10n.translate('admin.audit_target')}: $targetUid',
                      style:
                          t.labelS.copyWith(color: palette.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ));
          },
        );
      },
    );
  }
}

// ── Doc Chip (tappable document link) ──────────────────────────────────────

class _DocChip extends StatelessWidget {
  final String label;
  final String url;
  final AppPalette palette;

  const _DocChip({
    required this.label,
    required this.url,
    required this.palette,
  });

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: palette.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: palette.info.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, size: 12.r, color: palette.info),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: palette.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip ───────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;
  final AppText t;

  const _Chip({
    required this.icon,
    required this.label,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: palette.textSecondary),
          SizedBox(width: 3.w),
          Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

// ── Broadcasts Tab ─────────────────────────────────────────────────────────────

class _BroadcastsTab extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _BroadcastsTab({
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Stack(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService().broadcastsStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return AppErrorState(
                title: 'Something went wrong',
                message: snap.error.toString(),
                onRetry: () {},
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: AppSkeletonList(itemCount: 4),
              );
            }

            final broadcasts = snap.data ?? [];

            if (broadcasts.isEmpty) {
              return AppEmptyState(
                icon: Icons.campaign_rounded,
                title: l10n.translate('admin.broadcast_empty'),
                message: l10n.translate('admin.broadcast_empty_msg'),
                actionLabel: l10n.translate('admin.broadcast_compose'),
                onAction: () => _openCompose(context),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
              itemCount: broadcasts.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final b = broadcasts[index];
                return _BroadcastCard(data: b, palette: palette, t: t, l10n: l10n);
              },
            );
          },
        ),

        // Compose FAB
        Positioned(
          right: 16.w,
          bottom: 24.h,
          child: FloatingActionButton.extended(
            onPressed: () => _openCompose(context),
            backgroundColor: primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              l10n.translate('admin.broadcast_compose'),
              style: t.labelM.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  void _openCompose(BuildContext context) {
    AppSheet.show(
      context: context,
      title: l10n.translate('admin.broadcast_compose'),
      child: _ComposeBroadcastSheet(l10n: l10n, t: t, palette: palette),
    );
  }
}

// ── Broadcast Card ──────────────────────────────────────────────────────────

class _BroadcastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _BroadcastCard({
    required this.data,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  Color _statusColor(String? status) {
    switch (status) {
      case 'sent':
        return const Color(0xFF10B981);
      case 'scheduled':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'sent':
        return l10n.translate('admin.broadcast_status_sent');
      case 'scheduled':
        return l10n.translate('admin.broadcast_status_scheduled');
      case 'failed':
        return l10n.translate('admin.broadcast_status_failed');
      default:
        return l10n.translate('admin.broadcast_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String?;
    final title = data['title_en'] as String? ?? '';
    final body = data['body_en'] as String? ?? '';
    final audience = data['audience'] as String? ?? 'all';
    final recipientCount = data['recipient_count'] as int? ?? 0;
    final createdAt = data['created_at'];
    final statusColor = _statusColor(status);

    String timeLabel = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      timeLabel = DateFormat('MMM d, HH:mm').format(dt);
    }

    return AppCard(
      elevated: false,
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '(No title)' : title,
                  style: t.bodyM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(
                  _statusLabel(status),
                  style: t.labelS.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              body,
              style: t.bodyM.copyWith(color: palette.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 12.r, color: palette.textTertiary),
              SizedBox(width: 4.w),
              Text(
                _audienceLabel(audience),
                style: t.labelS.copyWith(color: palette.textTertiary),
              ),
              if (status == 'sent') ...[
                SizedBox(width: 8.w),
                Text('·',
                    style: t.labelS.copyWith(color: palette.textTertiary)),
                SizedBox(width: 8.w),
                Text(
                  l10n
                      .translate('admin.broadcast_recipients')
                      .replaceFirst('{n}', recipientCount.toString()),
                  style: t.labelS.copyWith(color: palette.textTertiary),
                ),
              ],
              const Spacer(),
              Text(
                timeLabel,
                style: t.labelS.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _audienceLabel(String audience) {
    if (audience == 'all') return l10n.translate('admin.broadcast_audience_all');
    if (audience == 'coaches') return l10n.translate('admin.broadcast_audience_coaches');
    if (audience == 'gymOwners') return l10n.translate('admin.broadcast_audience_gym_owners');
    if (audience.startsWith('user:')) return l10n.translate('admin.broadcast_audience_single');
    return audience;
  }
}

// ── Compose Broadcast Sheet ─────────────────────────────────────────────────

class _ComposeBroadcastSheet extends StatefulWidget {
  final AppLocalizations l10n;
  final AppText t;
  final AppPalette palette;

  const _ComposeBroadcastSheet({
    required this.l10n,
    required this.t,
    required this.palette,
  });

  @override
  State<_ComposeBroadcastSheet> createState() => _ComposeBroadcastSheetState();
}

class _ComposeBroadcastSheetState extends State<_ComposeBroadcastSheet> {
  final _titleEnCtrl = TextEditingController();
  final _bodyEnCtrl = TextEditingController();
  final _titleTrCtrl = TextEditingController();
  final _bodyTrCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();

  String _audience = 'all';
  bool _scheduleMode = false;
  DateTime? _scheduledAt;
  bool _sending = false;

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _bodyEnCtrl.dispose();
    _titleTrCtrl.dispose();
    _bodyTrCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = widget.l10n;
    if (_titleEnCtrl.text.trim().isEmpty || _bodyEnCtrl.text.trim().isEmpty) {
      AppSnackBar.error(
          context, 'Title (EN) and Message (EN) are required.');
      return;
    }

    final audience = _audience == 'single'
        ? 'user:${_uidCtrl.text.trim()}'
        : _audience;
    if (audience == 'user:') {
      AppSnackBar.error(context, 'Please enter a user UID.');
      return;
    }

    setState(() => _sending = true);
    try {
      await AdminService().sendBroadcast(
        titleEn: _titleEnCtrl.text.trim(),
        bodyEn: _bodyEnCtrl.text.trim(),
        titleTr: _titleTrCtrl.text.trim().isEmpty
            ? _titleEnCtrl.text.trim()
            : _titleTrCtrl.text.trim(),
        bodyTr: _bodyTrCtrl.text.trim().isEmpty
            ? _bodyEnCtrl.text.trim()
            : _bodyTrCtrl.text.trim(),
        audience: audience,
        scheduleAt: _scheduleMode ? _scheduledAt : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, l10n.translate('admin.broadcast_send_success'));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, l10n.translate('admin.broadcast_send_error'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final t = widget.t;
    final palette = widget.palette;
    final primary = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── EN fields ────────────────────────────────────────────────────
          _BroadcastLabel(l10n.translate('admin.broadcast_audience'), t, palette),
          _AudienceSelector(
            value: _audience,
            palette: palette,
            t: t,
            l10n: l10n,
            primary: primary,
            onChanged: (v) => setState(() => _audience = v),
          ),
          if (_audience == 'single') ...[
            SizedBox(height: 10.h),
            _field(
              controller: _uidCtrl,
              hint: l10n.translate('admin.broadcast_uid_hint'),
              t: t,
              palette: palette,
            ),
          ],
          SizedBox(height: 16.h),
          _BroadcastLabel(l10n.translate('admin.broadcast_title_en'), t, palette),
          _field(
            controller: _titleEnCtrl,
            hint: 'New feature alert!',
            t: t,
            palette: palette,
          ),
          SizedBox(height: 10.h),
          _BroadcastLabel(l10n.translate('admin.broadcast_body_en'), t, palette),
          _field(
            controller: _bodyEnCtrl,
            hint: 'Check out the latest update…',
            t: t,
            palette: palette,
            maxLines: 3,
          ),
          SizedBox(height: 16.h),

          // ── TR fields ────────────────────────────────────────────────────
          _BroadcastLabel(l10n.translate('admin.broadcast_title_tr'), t, palette),
          _field(
            controller: _titleTrCtrl,
            hint: 'Yeni özellik!',
            t: t,
            palette: palette,
          ),
          SizedBox(height: 10.h),
          _BroadcastLabel(l10n.translate('admin.broadcast_body_tr'), t, palette),
          _field(
            controller: _bodyTrCtrl,
            hint: 'Son güncellemeye göz atın…',
            t: t,
            palette: palette,
            maxLines: 3,
          ),
          SizedBox(height: 16.h),

          // ── Schedule toggle ───────────────────────────────────────────────
          Row(
            children: [
              Switch(
                value: _scheduleMode,
                onChanged: (v) => setState(() => _scheduleMode = v),
                activeThumbColor: primary,
              ),
              SizedBox(width: 8.w),
              Text(
                l10n.translate('admin.broadcast_scheduled'),
                style: t.bodyM.copyWith(color: palette.textPrimary),
              ),
              if (_scheduleMode) ...[
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final ctx = context;
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: now.add(const Duration(hours: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 30)),
                    );
                    if (picked == null) return;
                    if (!ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(
                          now.add(const Duration(hours: 1))),
                    );
                    if (!mounted || time == null) return;
                    setState(() {
                      _scheduledAt = DateTime(picked.year, picked.month,
                          picked.day, time.hour, time.minute);
                    });
                  },
                  child: Text(
                    _scheduledAt == null
                        ? l10n.translate('admin.broadcast_schedule')
                        : DateFormat('MMM d, HH:mm').format(_scheduledAt!),
                    style: t.labelM.copyWith(color: primary),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 20.h),

          AppButton(
            label: _scheduleMode && _scheduledAt != null
                ? l10n.translate('admin.broadcast_scheduled')
                : l10n.translate('admin.broadcast_send_now'),
            onPressed: _sending ? null : _send,
            loading: _sending,
            icon: _scheduleMode
                ? Icons.schedule_rounded
                : Icons.send_rounded,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required AppText t,
    required AppPalette palette,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: t.bodyM.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: t.bodyM.copyWith(color: palette.textTertiary),
        filled: true,
        fillColor: palette.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      ),
    );
  }
}

// ── Broadcast form label ────────────────────────────────────────────────────

class _BroadcastLabel extends StatelessWidget {
  final String text;
  final AppText t;
  final AppPalette palette;
  const _BroadcastLabel(this.text, this.t, this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: t.labelM.copyWith(
            color: palette.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Audience Selector ───────────────────────────────────────────────────────

class _AudienceSelector extends StatelessWidget {
  final String value;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;
  final Color primary;
  final ValueChanged<String> onChanged;

  const _AudienceSelector({
    required this.value,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('all', l10n.translate('admin.broadcast_audience_all')),
      ('coaches', l10n.translate('admin.broadcast_audience_coaches')),
      ('gymOwners', l10n.translate('admin.broadcast_audience_gym_owners')),
      ('single', l10n.translate('admin.broadcast_audience_single')),
    ];

    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      children: options.map((opt) {
        final selected = value == opt.$1;
        return GestureDetector(
          onTap: () => onChanged(opt.$1),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.15)
                  : palette.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
              border: Border.all(
                color: selected ? primary : Colors.transparent,
              ),
            ),
            child: Text(
              opt.$2,
              style: t.labelM.copyWith(
                color: selected ? primary : palette.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Quick Access Card (Dashboard) ─────────────────────────────────────────

class _QuickAccessCard extends StatelessWidget {
  final String label;
  final String? description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText t;

  const _QuickAccessCard({
    required this.label,
    this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      onTap: onTap,
      blur: AppPalette.glassBlurSubtle,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34.r,
                height: 34.r,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.25),
                      accentColor.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9.r),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 17.r),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: palette.textTertiary, size: 16.r),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: t.labelM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (description != null) ...[
            SizedBox(height: 2.h),
            Text(
              description!,
              style: t.labelS.copyWith(color: palette.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Config Tab ────────────────────────────────────────────────────────────

class _ConfigTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _ConfigTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  final _minVersionCtrl = TextEditingController();
  final _aiModelCtrl = TextEditingController();
  final _aiProxyUrlCtrl = TextEditingController();
  final _msgEnCtrl = TextEditingController();
  final _msgTrCtrl = TextEditingController();
  final _maxRetriesCtrl = TextEditingController(text: '3');
  final _keywordCtrl = TextEditingController();

  final Map<String, bool> _flags = {
    'maintenance_mode': false,
    'feature_voice_assistant': false,
    'feature_nutrition_analytics': true,
  };

  List<String> _blockedKeywords = [];
  bool _populated = false;
  bool _hasChanges = false;
  bool _loading = false;

  @override
  void dispose() {
    _minVersionCtrl.dispose();
    _aiModelCtrl.dispose();
    _aiProxyUrlCtrl.dispose();
    _msgEnCtrl.dispose();
    _msgTrCtrl.dispose();
    _maxRetriesCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> cfg) {
    _minVersionCtrl.text = cfg['min_version'] as String? ?? '';
    _aiModelCtrl.text = cfg['ai_model'] as String? ?? '';
    _aiProxyUrlCtrl.text = cfg['ai_proxy_url'] as String? ?? '';
    _msgEnCtrl.text = cfg['maintenance_message_en'] as String? ?? '';
    _msgTrCtrl.text = cfg['maintenance_message_tr'] as String? ?? '';
    _maxRetriesCtrl.text = '${cfg['max_meal_retries'] as int? ?? 3}';
    _flags['maintenance_mode'] = cfg['maintenance_mode'] as bool? ?? false;
    _flags['feature_voice_assistant'] =
        cfg['feature_voice_assistant'] as bool? ?? false;
    _flags['feature_nutrition_analytics'] =
        cfg['feature_nutrition_analytics'] as bool? ?? true;
    _blockedKeywords = List<String>.from(
        cfg['blocked_keywords'] as List? ?? []);
    _populated = true;
    _hasChanges = false;
  }

  void _addKeyword() {
    final kw = _keywordCtrl.text.trim().toLowerCase();
    if (kw.isEmpty || _blockedKeywords.contains(kw)) return;
    setState(() {
      _blockedKeywords.add(kw);
      _keywordCtrl.clear();
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await AdminService().updateAdminConfig({
        'min_version': _minVersionCtrl.text.trim(),
        'ai_model': _aiModelCtrl.text.trim(),
        'ai_proxy_url': _aiProxyUrlCtrl.text.trim(),
        'maintenance_message_en': _msgEnCtrl.text.trim(),
        'maintenance_message_tr': _msgTrCtrl.text.trim(),
        'max_meal_retries':
            int.tryParse(_maxRetriesCtrl.text.trim()) ?? 3,
        'blocked_keywords': _blockedKeywords,
        ..._flags,
      });
      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.l10n.translate('admin.config_saved')),
          backgroundColor: widget.palette.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: AdminService().adminConfigStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
          );
        }
        if (snap.hasData && snap.data != null && !_populated && !_hasChanges) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _populate(snap.data!));
          });
        }
        final cfg = snap.data;
        return SingleChildScrollView(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Status
              _CfgSection(
                  label: l10n.translate('admin.config_section_status'),
                  t: t,
                  palette: palette),
              _ToggleRow(
                label: l10n.translate('admin.config_maintenance_mode'),
                icon: Icons.construction_rounded,
                value: _flags['maintenance_mode'] ?? false,
                activeColor: palette.error,
                onChanged: (v) => setState(() {
                  _flags['maintenance_mode'] = v;
                  _hasChanges = true;
                }),
                palette: palette,
                t: t,
              ),
              if (_flags['maintenance_mode'] ?? false) ...[
                SizedBox(height: 8.h),
                _CfgField(
                  ctrl: _msgEnCtrl,
                  label: l10n.translate('admin.config_maintenance_msg_en'),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
                SizedBox(height: 8.h),
                _CfgField(
                  ctrl: _msgTrCtrl,
                  label: l10n.translate('admin.config_maintenance_msg_tr'),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
              ],
              SizedBox(height: 10.h),
              _CfgField(
                ctrl: _minVersionCtrl,
                label: l10n.translate('admin.config_min_version'),
                hint: '1.0.0',
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              SizedBox(height: 20.h),
              // AI Settings
              _CfgSection(
                  label: l10n.translate('admin.config_section_ai'),
                  t: t,
                  palette: palette),
              _CfgField(
                ctrl: _aiModelCtrl,
                label: l10n.translate('admin.config_ai_model'),
                hint: 'deepseek/deepseek-r1t-chimera:free',
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              SizedBox(height: 8.h),
              _CfgField(
                ctrl: _aiProxyUrlCtrl,
                label: l10n.translate('admin.config_ai_proxy_url'),
                hint: 'https://... (blank = direct)',
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              SizedBox(height: 8.h),
              _CfgField(
                ctrl: _maxRetriesCtrl,
                label: l10n.translate('admin.config_max_retries'),
                hint: '1–10',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              SizedBox(height: 20.h),
              // Feature Flags
              _CfgSection(
                  label: l10n.translate('admin.config_section_features'),
                  t: t,
                  palette: palette),
              _ToggleRow(
                label: l10n.translate('admin.config_feature_voice'),
                icon: Icons.mic_rounded,
                value: _flags['feature_voice_assistant'] ?? false,
                activeColor: primary,
                onChanged: (v) => setState(() {
                  _flags['feature_voice_assistant'] = v;
                  _hasChanges = true;
                }),
                palette: palette,
                t: t,
              ),
              SizedBox(height: 8.h),
              _ToggleRow(
                label: l10n.translate('admin.config_feature_nutrition'),
                icon: Icons.bar_chart_rounded,
                value: _flags['feature_nutrition_analytics'] ?? true,
                activeColor: primary,
                onChanged: (v) => setState(() {
                  _flags['feature_nutrition_analytics'] = v;
                  _hasChanges = true;
                }),
                palette: palette,
                t: t,
              ),
              SizedBox(height: 20.h),
              // Moderation Rules
              _CfgSection(
                  label: l10n.translate('admin.config_section_moderation'),
                  t: t,
                  palette: palette),
              if (_blockedKeywords.isNotEmpty) ...[
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: _blockedKeywords
                      .map((kw) => Chip(
                            label: Text(kw,
                                style: t.labelS
                                    .copyWith(color: palette.textPrimary)),
                            backgroundColor: palette.surfaceVariant,
                            side: BorderSide(color: palette.border),
                            deleteIconColor: palette.textSecondary,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => setState(() {
                              _blockedKeywords.remove(kw);
                              _hasChanges = true;
                            }),
                          ))
                      .toList(),
                ),
                SizedBox(height: 8.h),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordCtrl,
                      style:
                          t.bodyM.copyWith(color: palette.textPrimary),
                      decoration: InputDecoration(
                        hintText: l10n
                            .translate('admin.config_keyword_hint'),
                        hintStyle: t.bodyM
                            .copyWith(color: palette.textSecondary),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppRadius.input.r),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppRadius.input.r),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        filled: true,
                        fillColor: palette.surfaceVariant,
                      ),
                      onSubmitted: (_) => _addKeyword(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  AppButton(
                    label: l10n.translate('admin.config_keyword_add'),
                    onPressed: _addKeyword,
                    expand: false,
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              AppButton(
                label: l10n.translate('admin.config_save'),
                loading: _loading,
                onPressed: _hasChanges ? _save : null,
              ),
              if (cfg != null && cfg['updated_at'] != null) ...[
                SizedBox(height: 12.h),
                Center(
                  child: Text(
                    l10n
                        .translate('admin.config_last_updated')
                        .replaceFirst(
                            '{at}',
                            DateFormat('MMM d, HH:mm').format(
                                (cfg['updated_at'] as Timestamp).toDate())),
                    style:
                        t.labelS.copyWith(color: palette.textTertiary),
                  ),
                ),
              ],
              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }
}

// ── Credits & Codes Tab ────────────────────────────────────────────────────

class _CreditsAndCodesTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _CreditsAndCodesTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  State<_CreditsAndCodesTab> createState() => _CreditsAndCodesTabState();
}

class _CreditsAndCodesTabState extends State<_CreditsAndCodesTab> {
  bool _showCredits = true;
  final _searchCtrl = TextEditingController();
  final _grantCountCtrl = TextEditingController(text: '5');
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String? _grantingUid;
  Set<String> _voidingCodes = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _grantCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await AdminService().searchUsers(q);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _grant(String uid) async {
    final count = int.tryParse(_grantCountCtrl.text.trim()) ?? 0;
    if (count <= 0) return;
    setState(() => _grantingUid = uid);
    try {
      await AdminService().grantBonusCredits(uid, count, 'admin_grant');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Granted $count credits'),
          backgroundColor: widget.palette.success,
        ));
      }
    } finally {
      if (mounted) setState(() => _grantingUid = null);
    }
  }

  Future<void> _void(String code) async {
    setState(() => _voidingCodes = {..._voidingCodes, code});
    try {
      await AdminService().voidReferralCode(code);
    } finally {
      if (mounted) setState(() => _voidingCodes = {..._voidingCodes}..remove(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        // Section toggle
        Padding(
          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 4.r),
          child: Row(
            children: [
              Expanded(
                child: _SectionToggleBtn(
                  label: l10n.translate('admin.credits_section'),
                  icon: Icons.bolt_rounded,
                  active: _showCredits,
                  accentColor: palette.warning,
                  onTap: () => setState(() => _showCredits = true),
                  palette: palette,
                  t: t,
                  primary: primary,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SectionToggleBtn(
                  label: l10n.translate('admin.referrals_section'),
                  icon: Icons.card_giftcard_rounded,
                  active: !_showCredits,
                  accentColor: palette.success,
                  onTap: () => setState(() => _showCredits = false),
                  palette: palette,
                  t: t,
                  primary: primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showCredits
              ? _buildCredits(context, palette, l10n, t, primary)
              : _buildReferrals(context, palette, l10n, t),
        ),
      ],
    );
  }

  Widget _buildCredits(BuildContext context, AppPalette palette,
      AppLocalizations l10n, AppText t, Color primary) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CfgSection(
              label: l10n.translate('admin.credits_top_users'),
              t: t,
              palette: palette),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdminService().aiUsageStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return AppErrorState(
                  title: 'Something went wrong',
                  message: snap.error.toString(),
                  onRetry: () {},
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 4);
              }
              final users = snap.data ?? [];
              if (users.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.bolt_outlined,
                  title: 'No heavy AI users today',
                );
              }
              return Column(
                children: users
                    .map((u) => _AiUsageRow(
                        user: u, palette: palette, t: t))
                    .toList(),
              );
            },
          ),
          SizedBox(height: 24.h),
          _CfgSection(
              label: l10n.translate('admin.credits_grant_title'),
              t: t,
              palette: palette),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: _CfgField(
                  ctrl: _searchCtrl,
                  label: l10n.translate('admin.credits_search_hint'),
                  onChanged: null,
                ),
              ),
              SizedBox(width: 8.w),
              AppButton(
                label: l10n.translate('admin.credits_search_btn'),
                loading: _searching,
                onPressed: _doSearch,
                variant: AppButtonVariant.tonal,
                size: AppButtonSize.medium,
                expand: false,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              SizedBox(
                width: 72.w,
                child: _CfgField(
                  ctrl: _grantCountCtrl,
                  label: l10n.translate('admin.credits_count_label'),
                  keyboardType: TextInputType.number,
                  onChanged: null,
                ),
              ),
              SizedBox(width: 10.w),
              Text(l10n.translate('admin.credits_count_hint'),
                  style: t.labelS.copyWith(color: palette.textSecondary)),
            ],
          ),
          if (_searchResults.isNotEmpty) ...[
            SizedBox(height: 12.h),
            ..._searchResults.map((u) => _GrantUserRow(
                  user: u,
                  isGranting: _grantingUid ==
                      (u['uid'] as String? ?? u['id'] as String? ?? ''),
                  onGrant: () =>
                      _grant(u['uid'] as String? ?? u['id'] as String? ?? ''),
                  palette: palette,
                  t: t,
                )),
          ],
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildReferrals(BuildContext context, AppPalette palette,
      AppLocalizations l10n, AppText t) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService().referralsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList();
        }
        final codes = snap.data ?? [];
        if (codes.isEmpty) {
          return const AppEmptyState(
            icon: Icons.card_giftcard_outlined,
            title: 'No referral codes yet',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: codes.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, i) {
            final d = codes[i];
            final code = d['id'] as String? ?? '';
            final maxUses = d['maxUses'] as int? ?? 10;
            final usedCount =
                (d['usedByUids'] as List<dynamic>?)?.length ?? 0;
            final isVoided = maxUses == 0;
            return _ReferralCodeCard(
              code: code,
              ownerUid: d['ownerUid'] as String? ?? '',
              usedCount: usedCount,
              maxUses: maxUses,
              isVoided: isVoided,
              isVoiding: _voidingCodes.contains(code),
              onVoid: isVoided ? null : () => _void(code),
              voidLabel: l10n.translate('admin.referrals_void_btn'),
              voidedLabel: l10n.translate('admin.referrals_voided'),
              usesLabel: l10n
                  .translate('admin.referrals_uses')
                  .replaceFirst('{used}', '$usedCount')
                  .replaceFirst('{max}', '$maxUses'),
              palette: palette,
              t: t,
            );
          },
        );
      },
    );
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────

class _CfgSection extends StatelessWidget {
  final String label;
  final AppText t;
  final AppPalette palette;

  const _CfgSection(
      {required this.label, required this.t, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: t.labelS.copyWith(
                color: palette.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Divider(color: palette.border, height: 1),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;
  final AppPalette palette;
  final AppText t;

  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      blur: AppPalette.glassBlurSubtle,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          Icon(icon,
              color: value ? activeColor : palette.textTertiary, size: 20.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(label,
                style: t.bodyM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: activeColor,
          ),
        ],
      ),
    );
  }
}

class _CfgField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _CfgField({
    required this.ctrl,
    required this.label,
    this.hint,
    this.keyboardType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: t.labelS.copyWith(
                color: palette.textSecondary, fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: t.bodyM.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.bodyM.copyWith(color: palette.textTertiary),
            filled: true,
            fillColor: palette.surfaceVariant,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(
                  color: Theme.of(context).primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText t;
  final Color primary;

  const _SectionToggleBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.accentColor,
    required this.onTap,
    required this.palette,
    required this.t,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: active
              ? accentColor.withValues(alpha: 0.12)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: active ? accentColor : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: active ? accentColor : palette.textTertiary,
                size: 16.r),
            SizedBox(width: 6.w),
            Text(label,
                style: t.labelM.copyWith(
                    color: active ? accentColor : palette.textSecondary,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _AiUsageRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final AppPalette palette;
  final AppText t;

  const _AiUsageRow(
      {required this.user, required this.palette, required this.t});

  @override
  Widget build(BuildContext context) {
    final name = user['display_name'] as String? ??
        user['displayName'] as String? ??
        'User';
    final used = user['ai_credits_used'] as int? ?? 0;
    final bonus = user['ai_credits_bonus'] as int? ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: AppGlassCard(
        blur: AppPalette.glassBlurSubtle,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Icon(Icons.person_rounded,
                color: palette.textTertiary, size: 18.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(name,
                  style: t.bodyM.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text('$used used',
                  style: t.labelS.copyWith(color: palette.warning)),
            ),
            if (bonus > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text('+$bonus bonus',
                    style: t.labelS.copyWith(color: palette.success)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GrantUserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isGranting;
  final VoidCallback onGrant;
  final AppPalette palette;
  final AppText t;

  const _GrantUserRow({
    required this.user,
    required this.isGranting,
    required this.onGrant,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user['display_name'] as String? ??
        user['displayName'] as String? ??
        'User';
    final email = user['email'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: AppGlassCard(
        blur: AppPalette.glassBlurSubtle,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded,
                color: palette.textSecondary, size: 18.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: t.bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (email.isNotEmpty)
                    Text(email,
                        style: t.labelS.copyWith(
                            color: palette.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AppButton(
              label: l10n.translate('admin.credits_grant_btn'),
              loading: isGranting,
              onPressed: onGrant,
              variant: AppButtonVariant.tonal,
              size: AppButtonSize.small,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final String ownerUid;
  final int usedCount;
  final int maxUses;
  final bool isVoided;
  final bool isVoiding;
  final VoidCallback? onVoid;
  final String voidLabel;
  final String voidedLabel;
  final String usesLabel;
  final AppPalette palette;
  final AppText t;

  const _ReferralCodeCard({
    required this.code,
    required this.ownerUid,
    required this.usedCount,
    required this.maxUses,
    required this.isVoided,
    required this.isVoiding,
    required this.onVoid,
    required this.voidLabel,
    required this.voidedLabel,
    required this.usesLabel,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      blur: AppPalette.glassBlurSubtle,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: isVoided
                  ? palette.textTertiary.withValues(alpha: 0.12)
                  : palette.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              code,
              style: t.labelM.copyWith(
                color: isVoided ? palette.textTertiary : palette.success,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usesLabel,
                    style: t.labelS.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600)),
                if (ownerUid.isNotEmpty)
                  Text(
                    ownerUid.length > 12
                        ? '${ownerUid.substring(0, 12)}…'
                        : ownerUid,
                    style: t.labelS.copyWith(color: palette.textTertiary),
                  ),
              ],
            ),
          ),
          if (isVoided)
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: palette.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(voidedLabel,
                  style: t.labelS.copyWith(color: palette.textTertiary)),
            )
          else
            AppButton(
              label: voidLabel,
              loading: isVoiding,
              onPressed: onVoid,
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.small,
              expand: false,
            ),
        ],
      ),
    );
  }
}

// ── Program Review Tab ────────────────────────────────────────────────────

class _ProgramReviewTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _ProgramReviewTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  State<_ProgramReviewTab> createState() => _ProgramReviewTabState();
}

class _ProgramReviewTabState extends State<_ProgramReviewTab>
    with SingleTickerProviderStateMixin {
  late final TabController _inner =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        TabBar(
          controller: _inner,
          labelColor: primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          tabs: [
            Tab(text: l10n.translate('admin.program_status_pending')),
            Tab(text: l10n.translate('admin.tab_history')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _inner,
            children: [
              _ProgramList(
                stream: AdminService().pendingProgramsStream(),
                emptyKey: 'admin.programs_pending_empty',
                showActions: true,
                palette: palette,
                l10n: l10n,
                t: t,
              ),
              _ProgramList(
                stream: AdminService().programHistoryStream(),
                emptyKey: 'admin.programs_history_empty',
                showActions: false,
                palette: palette,
                l10n: l10n,
                t: t,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgramList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String emptyKey;
  final bool showActions;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _ProgramList({
    required this.stream,
    required this.emptyKey,
    required this.showActions,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
            onRetry: () {},
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList();
        }
        final programs = snap.data ?? [];
        if (programs.isEmpty) {
          return AppEmptyState(
            icon: Icons.library_books_outlined,
            title: l10n.translate(emptyKey),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: programs.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, i) => _ProgramCard(
            data: programs[i],
            showActions: showActions,
            palette: palette,
            l10n: l10n,
            t: t,
          ),
        );
      },
    );
  }
}

class _ProgramCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showActions;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _ProgramCard({
    required this.data,
    required this.showActions,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard> {
  bool _approving = false;
  bool _rejecting = false;
  final _rejectCtrl = TextEditingController();

  @override
  void dispose() {
    _rejectCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await AdminService().approveProgram(widget.data['id'] as String);
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _showRejectSheet() async {
    final ctx = context;
    await AppSheet.show(
      context: ctx,
      title: widget.l10n.translate('admin.program_reject_btn'),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _rejectCtrl,
              decoration: InputDecoration(
                hintText: widget.l10n
                    .translate('admin.program_reject_reason_hint'),
                filled: true,
                fillColor: widget.palette.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: widget.palette.border),
                ),
              ),
              maxLines: 3,
              style: widget.t.bodyM
                  .copyWith(color: widget.palette.textPrimary),
            ),
            SizedBox(height: 12.h),
            AppButton(
              label: widget.l10n.translate('admin.program_reject_btn'),
              variant: AppButtonVariant.destructive,
              onPressed: () async {
                final notes = _rejectCtrl.text.trim();
                setState(() => _rejecting = true);
                Navigator.of(ctx).pop();
                try {
                  await AdminService().rejectProgram(
                      widget.data['id'] as String, notes);
                } finally {
                  if (mounted) setState(() => _rejecting = false);
                }
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final status = d['status'] as String? ?? 'pending';
    final title = d['title'] as String? ?? '';
    final coachName = d['coach_name'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final durationWeeks = d['duration_weeks'] as int? ?? 0;

    Color statusColor() => switch (status) {
          'approved' => palette.success,
          'rejected' => palette.error,
          _ => palette.warning,
        };

    String statusLabel() => switch (status) {
          'approved' => l10n.translate('admin.program_status_approved'),
          'rejected' => l10n.translate('admin.program_status_rejected'),
          _ => l10n.translate('admin.program_status_pending'),
        };

    return AppGlassCard(
      blur: AppPalette.glassBlurSubtle,
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.bodyM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    SizedBox(height: 2.h),
                    Text(
                      l10n
                          .translate('admin.program_by')
                          .replaceFirst('{coach}', coachName),
                      style: t.labelS
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(statusLabel(),
                    style: t.labelS.copyWith(
                        color: statusColor(),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            children: [
              _Chip(
                icon: Icons.grid_view_rounded,
                label: category,
                palette: palette,
                t: t,
              ),
              _Chip(
                icon: Icons.calendar_today_rounded,
                label: l10n
                    .translate('admin.program_weeks')
                    .replaceFirst('{n}', '$durationWeeks'),
                palette: palette,
                t: t,
              ),
            ],
          ),
          if (widget.showActions) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.translate('admin.program_approve_btn'),
                    loading: _approving,
                    onPressed: _approve,
                    size: AppButtonSize.medium,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppButton(
                    label: l10n.translate('admin.program_reject_btn'),
                    loading: _rejecting,
                    onPressed: _showRejectSheet,
                    variant: AppButtonVariant.destructive,
                    size: AppButtonSize.medium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Phase 14.5B: Billing Oversight Tab ─────────────────────────────────────

class _BillingTab extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _BillingTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService().premiumUsersStream(),
      builder: (context, snap) {
        final users = snap.data ?? [];
        final premiumCount = users.length;
        // Estimated MRR — placeholder price until IAP tracking is stored server-side.
        // Replace with actual transaction data when revenue records are added.
        const monthlyPriceTry = 49.99;
        final estimatedMrr = premiumCount * monthlyPriceTry;

        return ListView(
          padding: EdgeInsets.all(16.r),
          children: [
            // KPI row
            Row(
              children: [
                _BillingKpiCard(
                  icon: Icons.workspace_premium_rounded,
                  label: l10n.translate('admin.billing_premium_count'),
                  value: '$premiumCount',
                  color: primary,
                  palette: palette,
                  t: t,
                  isLoading: snap.connectionState == ConnectionState.waiting,
                ),
                SizedBox(width: 12.w),
                _BillingKpiCard(
                  icon: Icons.trending_up_rounded,
                  label: l10n.translate('admin.billing_mrr_estimate'),
                  value: '₺${estimatedMrr.toStringAsFixed(0)}',
                  color: palette.success,
                  palette: palette,
                  t: t,
                  isLoading: snap.connectionState == ConnectionState.waiting,
                ),
              ],
            ),
            SizedBox(height: 16.r),

            // Premium user list
            Text(
              l10n.translate('admin.billing_subscribers_label'),
              style: t.titleM.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10.r),

            if (snap.connectionState == ConnectionState.waiting)
              const AppSkeletonList(itemCount: 5)
            else if (users.isEmpty)
              AppEmptyState(
                icon: Icons.credit_card_off_rounded,
                title: l10n.translate('admin.billing_no_subscribers'),
                message: l10n.translate('admin.billing_no_subscribers_sub'),
              )
            else
              ...users.map((u) => Padding(
                    padding: EdgeInsets.only(bottom: 10.r),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              color: primary,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u['display_name'] as String? ??
                                      u['uid'] as String? ??
                                      '—',
                                  style: t.labelL.copyWith(
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  (u['subscription_tier'] as String? ?? 'premium')
                                      .toUpperCase(),
                                  style: t.labelS.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _BillingKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppPalette palette;
  final AppText t;
  final bool isLoading;

  const _BillingKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
    required this.t,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppGlassCard(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(height: 12.r),
            if (isLoading)
              const AppSkeletonBox(height: 24, width: 60)
            else
              Text(value,
                  style: t.headlineM.copyWith(
                      color: color, fontWeight: FontWeight.w800)),
            SizedBox(height: 4.r),
            Text(label,
                style: t.labelS.copyWith(color: palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Phase 14.5C: Abuse & Rate-Limit Monitoring Tab ─────────────────────────

class _AbuseTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _AbuseTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  State<_AbuseTab> createState() => _AbuseTabState();
}

class _AbuseTabState extends State<_AbuseTab> {
  bool _showBanned = true;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        // Section toggle
        Padding(
          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 4.r),
          child: Row(
            children: [
              _ToggleChip(
                label: l10n.translate('admin.abuse_banned_tab'),
                selected: _showBanned,
                primary: primary,
                palette: palette,
                t: t,
                onTap: () => setState(() => _showBanned = true),
              ),
              SizedBox(width: 8.r),
              _ToggleChip(
                label: l10n.translate('admin.abuse_ai_usage_tab'),
                selected: !_showBanned,
                primary: primary,
                palette: palette,
                t: t,
                onTap: () => setState(() => _showBanned = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showBanned
              ? _BannedUsersList(palette: palette, l10n: l10n, t: t)
              : _AiUsageList(palette: palette, l10n: l10n, t: t),
        ),
      ],
    );
  }
}

class _BannedUsersList extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _BannedUsersList(
      {required this.palette, required this.l10n, required this.t});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService().bannedUsersStream(),
      builder: (context, snap) {
        final users = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 5);
        }
        if (users.isEmpty) {
          return AppEmptyState(
            icon: Icons.shield_rounded,
            title: l10n.translate('admin.abuse_no_banned'),
            message: l10n.translate('admin.abuse_no_banned_sub'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.r),
          itemBuilder: (context, i) {
            final u = users[i];
            final uid = u['uid'] as String? ?? '';
            final name =
                u['display_name'] as String? ?? u['email'] as String? ?? uid;
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.block_rounded,
                        color: palette.error, size: 20),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style:
                                t.labelL.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          l10n.translate('admin.abuse_banned_label'),
                          style: t.labelS
                              .copyWith(color: palette.error),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await AdminService().unbanUser(uid);
                    },
                    child: Text(
                      l10n.translate('admin.abuse_unban_btn'),
                      style: t.labelM.copyWith(color: palette.success),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AiUsageList extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _AiUsageList(
      {required this.palette, required this.l10n, required this.t});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService().aiUsageStream(limit: 30),
      builder: (context, snap) {
        final users = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 5);
        }
        if (users.isEmpty) {
          return AppEmptyState(
            icon: Icons.psychology_rounded,
            title: l10n.translate('admin.abuse_no_ai_usage'),
            message: l10n.translate('admin.abuse_no_ai_usage_sub'),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.r),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.r),
          itemBuilder: (context, i) {
            final u = users[i];
            final name =
                u['display_name'] as String? ?? u['email'] as String? ?? '—';
            final used = (u['ai_credits_used'] as num?)?.toInt() ?? 0;
            final bonus = (u['ai_credits_bonus'] as num?)?.toInt() ?? 0;
            final isPremium = (u['subscription_tier'] as String?) == 'premium';
            final limit = isPremium ? 20 : 2;
            final pct = (used / limit).clamp(0.0, 1.0);
            final isAbuse = used >= limit * 2;

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isAbuse ? palette.error : primary)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: isAbuse ? palette.error : primary,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: t.labelL
                                    .copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              isPremium ? 'Premium' : 'Free',
                              style: t.labelS.copyWith(
                                  color: isPremium ? primary : palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$used / $limit',
                            style: t.labelM.copyWith(
                              color: isAbuse ? palette.error : palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (bonus > 0)
                            Text(
                              '+$bonus bonus',
                              style: t.labelS
                                  .copyWith(color: palette.success),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.r),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor:
                          (isAbuse ? palette.error : primary).withValues(alpha: 0.15),
                      color: isAbuse ? palette.error : primary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Phase 14.5 Analytics Dashboard ─────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _AnalyticsTab(
      {required this.palette, required this.l10n, required this.t});

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  Map<String, int>? _snapshot;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await AdminService().fetchAnalyticsSnapshot();
      if (mounted) setState(() => _snapshot = data);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final t = widget.t;
    final primary = Theme.of(context).primaryColor;

    if (_hasError) {
      return AppErrorState(
        title: l10n.translate('errors.general'),
        onRetry: _load,
      );
    }

    final snap = _snapshot ?? {};
    final total = snap['total_users'] ?? 0;
    final premium = snap['premium_users'] ?? 0;
    final coaches = snap['coaches'] ?? 0;
    final gymOwners = snap['gym_owners'] ?? 0;
    final posts = snap['posts'] ?? 0;
    final openReports = snap['open_reports'] ?? 0;
    final squads = snap['squads'] ?? 0;
    final consumers = total - coaches - gymOwners;
    final premiumPct =
        total > 0 ? (premium / total * 100).toStringAsFixed(1) : '0.0';

    return RefreshIndicator(
      onRefresh: _load,
      color: primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 40.r),
        children: [
          // KPI grid – 2 columns
          Text(
            l10n.translate('admin.analytics_kpi_title'),
            style: t.titleM.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12.r),
          _loading
              ? const AppSkeletonList(itemCount: 4, itemHeight: 90)
              : Wrap(
                  spacing: 12.r,
                  runSpacing: 12.r,
                  children: [
                    _AnalyticsKpi(
                      icon: Icons.people_rounded,
                      label: l10n.translate('admin.analytics_total_users'),
                      value: '$total',
                      sub: '$coaches ${l10n.translate('admin.analytics_coaches_label')}'
                          ' · $gymOwners ${l10n.translate('admin.analytics_gyms_label')}',
                      color: primary,
                      palette: palette,
                      t: t,
                    ),
                    _AnalyticsKpi(
                      icon: Icons.workspace_premium_rounded,
                      label: l10n.translate('admin.analytics_premium'),
                      value: '$premium',
                      sub: '$premiumPct%'
                          ' ${l10n.translate('admin.analytics_conversion')}',
                      color: palette.success,
                      palette: palette,
                      t: t,
                    ),
                    _AnalyticsKpi(
                      icon: Icons.forum_rounded,
                      label: l10n.translate('admin.analytics_posts'),
                      value: '$posts',
                      sub: '$squads ${l10n.translate('admin.analytics_squads_label')}',
                      color: palette.info,
                      palette: palette,
                      t: t,
                    ),
                    _AnalyticsKpi(
                      icon: Icons.flag_rounded,
                      label: l10n.translate('admin.analytics_open_reports'),
                      value: '$openReports',
                      sub: openReports > 0
                          ? l10n.translate('admin.analytics_reports_action')
                          : l10n.translate('admin.analytics_reports_clear'),
                      color: openReports > 0 ? palette.warning : palette.success,
                      palette: palette,
                      t: t,
                    ),
                  ],
                ),

          SizedBox(height: 24.r),

          // Role distribution
          Text(
            l10n.translate('admin.analytics_roles_title'),
            style: t.titleM.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12.r),
          _loading
              ? const AppSkeletonBox(height: 120, width: double.infinity)
              : AppGlassCard(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      _RoleBar(
                        label: l10n.translate('admin.analytics_role_consumer'),
                        count: consumers < 0 ? 0 : consumers,
                        total: total,
                        color: primary,
                        palette: palette,
                        t: t,
                      ),
                      SizedBox(height: 10.r),
                      _RoleBar(
                        label: l10n.translate('admin.analytics_role_coach'),
                        count: coaches,
                        total: total,
                        color: palette.success,
                        palette: palette,
                        t: t,
                      ),
                      SizedBox(height: 10.r),
                      _RoleBar(
                        label: l10n.translate('admin.analytics_role_gym'),
                        count: gymOwners,
                        total: total,
                        color: palette.info,
                        palette: palette,
                        t: t,
                      ),
                      SizedBox(height: 10.r),
                      _RoleBar(
                        label: l10n.translate('admin.analytics_role_premium'),
                        count: premium,
                        total: total,
                        color: palette.warning,
                        palette: palette,
                        t: t,
                      ),
                    ],
                  ),
                ),

          SizedBox(height: 24.r),

          // Top AI users
          Text(
            l10n.translate('admin.analytics_top_ai_title'),
            style: t.titleM.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12.r),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdminService().aiUsageStream(limit: 5),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 3);
              }
              final users = snap.data ?? [];
              if (users.isEmpty) {
                return AppEmptyState(
                  icon: Icons.psychology_rounded,
                  title: l10n.translate('admin.abuse_no_ai_usage'),
                  compact: true,
                );
              }
              return Column(
                children: users.asMap().entries.map((entry) {
                  final i = entry.key;
                  final u = entry.value;
                  final name = u['display_name'] as String? ?? '—';
                  final used = (u['ai_credits_used'] as num?)?.toInt() ?? 0;
                  final isPremium =
                      (u['subscription_tier'] as String?) == 'premium';
                  final limit = isPremium ? 20 : 2;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.r),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '#${i + 1}',
                              style: t.labelS.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(name,
                                style: t.labelL
                                    .copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            '$used / $limit',
                            style: t.labelM.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnalyticsKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final AppPalette palette;
  final AppText t;

  const _AnalyticsKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      child: AppGlassCard(
        padding: EdgeInsets.all(14.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            SizedBox(height: 10.r),
            Text(value,
                style: t.headlineM
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
            SizedBox(height: 2.r),
            Text(label,
                style: t.labelS.copyWith(color: palette.textSecondary)),
            SizedBox(height: 4.r),
            Text(sub,
                style: t.labelS
                    .copyWith(color: color.withValues(alpha: 0.7), fontSize: 10),
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _RoleBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final AppPalette palette;
  final AppText t;

  const _RoleBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final pctStr = (pct * 100).toStringAsFixed(1);
    return Row(
      children: [
        SizedBox(
          width: 80.w,
          child: Text(label,
              style: t.labelS.copyWith(color: palette.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 40.w,
          child: Text(
            '$count ($pctStr%)',
            style: t.labelS
                .copyWith(color: palette.textTertiary, fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}



