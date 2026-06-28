import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'application_review_screen.dart';

/// Admin-only screen for reviewing pending coach and gym applications.
/// Entry point added in settings_screen.dart when user.role == admin.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);

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
        title: Text(
          l10n.translate('admin.panel_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(
              text: l10n.translate('admin.tab_coaches'),
              icon: const Icon(Icons.fitness_center_rounded, size: 18),
            ),
            Tab(
              text: l10n.translate('admin.tab_gyms'),
              icon: const Icon(Icons.business_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CoachApplicationsList(palette: palette, l10n: l10n, t: t),
          _GymApplicationsList(palette: palette, l10n: l10n, t: t),
        ],
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
          padding: const EdgeInsets.all(16),
          itemCount: apps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            return _ApplicationCard(
              name: app.displayName,
              subtitle:
                  '${app.specializations.take(3).join(', ')} · ${app.experienceYears} yrs',
              submittedAt: app.submittedAt,
              evidenceCount: app.evidenceUrls.length,
              refsCount: app.references.length,
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
          padding: const EdgeInsets.all(16),
          itemCount: apps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final app = apps[i];
            return _ApplicationCard(
              name: app.gymName,
              subtitle:
                  '${app.city} · ${app.tags.take(3).join(', ')}',
              submittedAt: app.submittedAt,
              evidenceCount: (app.businessDocUrl != null ? 1 : 0) +
                  app.photoUrls.length,
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

// ── Application Card ───────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final DateTime submittedAt;
  final int evidenceCount;
  final int? refsCount;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _ApplicationCard({
    required this.name,
    required this.subtitle,
    required this.submittedAt,
    required this.evidenceCount,
    this.refsCount,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: t.bodyM.copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip(
                        icon: Icons.attach_file,
                        label: '$evidenceCount docs',
                        palette: palette,
                        t: t),
                    if (refsCount != null) ...[
                      const SizedBox(width: 6),
                      _Chip(
                          icon: Icons.people_outline,
                          label: '$refsCount refs',
                          palette: palette,
                          t: t),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: palette.textSecondary, size: 20),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.textSecondary),
          const SizedBox(width: 3),
          Text(label,
              style: t.labelS.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}
