import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/coach_client_model.dart';
import '../../core/models/coach_profile_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_application_service.dart';
import '../../core/services/coach_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_application_pending_screen.dart';
import 'coach_application_screen.dart';
import 'coach_client_detail_screen.dart';
import 'coach_clients_screen.dart';
import 'coach_profile_setup_screen.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: AppMotion.normal);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final uid = context.read<UserProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(
          l10n.translate('coach.dashboard_title'),
          style: AppText.of(context).headlineS.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<CoachProfileModel?>(
        stream: CoachService().getCoachProfileStream(uid),
        builder: (context, profileSnap) {
          final profile = profileSnap.data;

          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const AppSkeletonList();
          }

          if (profile == null) {
            return _buildSetupCta(context, palette, l10n, uid);
          }

          return StreamBuilder<List<CoachClientModel>>(
            stream: CoachService().getClientsStream(uid),
            builder: (context, clientsSnap) {
              final allClients = clientsSnap.data ?? [];
              final active = allClients
                  .where((c) => c.status == CoachClientStatus.active)
                  .toList();
              final pending = allClients
                  .where((c) => c.status == CoachClientStatus.pending)
                  .toList();
              final atRisk = active.where((c) => c.isAtRisk).toList();

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(context, palette, l10n, active.length,
                          pending.length, atRisk.length),
                      const SizedBox(height: 24),
                      if (atRisk.isNotEmpty) ...[
                        _buildAtRiskSection(context, palette, l10n, atRisk),
                        const SizedBox(height: 24),
                      ],
                      _buildActiveClientsSection(
                          context, palette, l10n, uid, active),
                      const SizedBox(height: 24),
                      _buildQuickActions(context, palette, l10n, profile),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSetupCta(BuildContext context, AppPalette palette,
      AppLocalizations l10n, String uid) {
    return StreamBuilder<CoachApplicationModel?>(
      stream: CoachApplicationService().getMyApplicationStream(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 3);
        }
        final app = snap.data;

        // Pending or needs more info → show status screen
        if (app != null && (app.isPending || app.needsMoreInfo)) {
          return CoachApplicationPendingScreen(
            showBackButton: false,
            status: app.status,
            reviewerNotes: app.reviewerNotes,
          );
        }

        // Rejected → show rejection screen
        if (app != null && app.isRejected) {
          return CoachApplicationPendingScreen(
            showBackButton: false,
            status: app.status,
            reviewerNotes: app.reviewerNotes,
          );
        }

        // No application → show apply CTA
        final primary = Theme.of(context).primaryColor;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.insights_rounded, size: 40, color: primary),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('coach.setup_cta_title'),
                  style: AppText.of(context).headlineS.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('coach.setup_cta_sub'),
                  style: AppText.of(context)
                      .bodyM
                      .copyWith(color: palette.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: l10n.translate('coach.setup_cta_btn'),
                  onPressed: () => Navigator.push(
                    context,
                    AppTransitions.slideRight(const CoachApplicationScreen()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
    int activeCount,
    int pendingCount,
    int atRiskCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: activeCount.toString(),
            label: l10n.translate('coach.dashboard_active_clients'),
            color: palette.success,
            icon: Icons.people_alt_rounded,
            palette: palette,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: pendingCount.toString(),
            label: l10n.translate('coach.dashboard_pending'),
            color: palette.info,
            icon: Icons.hourglass_top_rounded,
            palette: palette,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: atRiskCount.toString(),
            label: l10n.translate('coach.dashboard_at_risk'),
            color: palette.warning,
            icon: Icons.warning_amber_rounded,
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildAtRiskSection(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
    List<CoachClientModel> atRisk,
  ) {
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: palette.warning),
            const SizedBox(width: 6),
            Text(
              'At-Risk Clients',
              style: AppText.of(context).titleM.copyWith(
                  color: palette.warning, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...atRisk.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(CoachClientDetailScreen(client: c)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        backgroundImage: c.clientPhotoURL != null
                            ? CachedNetworkImageProvider(c.clientPhotoURL!)
                            : null,
                        child: c.clientPhotoURL == null
                            ? Icon(Icons.person_rounded,
                                color: primary, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.clientDisplayName ?? 'Client',
                                style: AppText.of(context).bodyM.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '${c.daysSinceLastLog == 999 ? "Never" : c.daysSinceLastLog} days since last log',
                              style: AppText.of(context)
                                  .labelS
                                  .copyWith(color: palette.warning),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: palette.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildActiveClientsSection(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
    String uid,
    List<CoachClientModel> active,
  ) {
    final primary = Theme.of(context).primaryColor;
    final top5 = active.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translate('coach.clients_active_section'),
              style: AppText.of(context).titleM.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.bold),
            ),
            if (active.length > 5)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(const CoachClientsScreen()),
                ),
                child: Text(l10n.translate('coach.dashboard.see_all', variables: {'count': active.length.toString()}),
                    style: AppText.of(context).labelS.copyWith(color: primary)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (top5.isEmpty)
          AppEmptyState(
            icon: Icons.people_alt_rounded,
            title: l10n.translate('coach.clients_empty_title'),
            message: l10n.translate('coach.clients_empty_sub'),
            compact: true,
          )
        else
          ...top5.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.push(
                    context,
                    AppTransitions.slideRight(
                        CoachClientDetailScreen(client: c)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primary.withValues(alpha: 0.15),
                          backgroundImage: c.clientPhotoURL != null
                              ? CachedNetworkImageProvider(c.clientPhotoURL!)
                              : null,
                          child: c.clientPhotoURL == null
                              ? Icon(Icons.person_rounded,
                                  color: primary, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(c.clientDisplayName ?? 'Client',
                              style: AppText.of(context).bodyM.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (c.clientStreak != null) ...[
                          const Icon(Icons.local_fire_department_rounded,
                              size: 14, color: Color(0xFFF97300)),
                          const SizedBox(width: 3),
                          Text('${c.clientStreak}d',
                              style: AppText.of(context).labelS.copyWith(
                                  color: const Color(0xFFF97300),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.chevron_right_rounded,
                            color: palette.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
    CoachProfileModel profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppText.of(context).titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.translate('coach.dashboard.action_edit_profile'),
                onPressed: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(
                      CoachProfileSetupScreen(existingProfile: profile)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: l10n.translate('coach.clients_title'),
                onPressed: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(const CoachClientsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final AppPalette palette;
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.bold)),
          Text(label,
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
