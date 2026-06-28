import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';
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
  late final TabController _tabs = TabController(length: 5, vsync: this);

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
                    color: palette.error,
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
        bottom: TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              text: l10n.translate('admin.dashboard_title'),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
            ),
            Tab(
              text: l10n.translate('admin.tab_coaches'),
              icon: const Icon(Icons.school_rounded, size: 18),
            ),
            Tab(
              text: l10n.translate('admin.tab_gyms'),
              icon: const Icon(Icons.business_rounded, size: 18),
            ),
            Tab(
              text: l10n.translate('admin.tab_users'),
              icon: const Icon(Icons.people_outline_rounded, size: 18),
            ),
            Tab(
              text: l10n.translate('admin.tab_history'),
              icon: const Icon(Icons.history_rounded, size: 18),
            ),
          ],
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 2×2 stat grid ───────────────────────────────────────
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.1,
            ),
            children: [
              // Pending Coaches
              _StatCard(
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
              // Pending Gyms
              _StatCard(
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
              // Total Users
              _StatCard(
                label: l10n.translate('admin.dashboard_total_users'),
                icon: Icons.people_rounded,
                accentColor: palette.success,
                stream: AdminService().userCountStream(),
                showBadgeWhenNonZero: false,
                onTap: () => tabs.animateTo(3),
                palette: palette,
                t: t,
              ),
              // Open Reports
              _StatCard(
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
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon + badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: accentColor, size: 20.r),
                ),
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
                        width: 10.r,
                        height: 10.r,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
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
          ],
        ),
      ),
    );
  }
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
            return _CoachAppCard(
              app: app,
              palette: palette,
              t: t,
              l10n: l10n,
              onTap: () => Navigator.of(ctx).push(
                AppTransitions.slideRight(
                    ApplicationReviewScreen.forCoach(app)),
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
            return _GymAppCard(
              app: app,
              palette: palette,
              t: t,
              l10n: l10n,
              onTap: () => Navigator.of(ctx).push(
                AppTransitions.slideRight(
                    ApplicationReviewScreen.forGym(app)),
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
            return _HistoryCard(
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
            return _HistoryCard(
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
                        label: 'Antrenörlük Sertifikası',
                        url: app.certDocUrl!,
                        palette: palette,
                      ),
                    if (hasIdDoc)
                      _DocChip(
                        label: 'Kimlik Belgesi',
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
                            'Belge yok',
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
                        label: 'İşletme Ruhsatı',
                        url: app.businessDocUrl!,
                        palette: palette,
                      ),
                    if (hasIdDoc)
                      _DocChip(
                        label: 'Kimlik Belgesi',
                        url: app.idDocUrl!,
                        palette: palette,
                      ),
                  ]
                : [
                    // No docs warning chip
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
                            'Belge yok',
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
