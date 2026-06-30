import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_client_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_client_detail_screen.dart';

class CoachClientsScreen extends StatefulWidget {
  const CoachClientsScreen({super.key});

  @override
  State<CoachClientsScreen> createState() => _CoachClientsScreenState();
}

class _CoachClientsScreenState extends State<CoachClientsScreen>
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

  Future<void> _acceptClient(String coachUid, String clientUid) async {
    try {
      unawaited(HapticFeedback.mediumImpact());
      await CoachService().acceptClient(clientUid);
      if (!mounted) return;
      AppSnackBar.success(context, 'Client accepted!');
    } catch (e) {
      debugPrint('CoachClientsScreen._acceptClient error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not accept client.');
    }
  }

  Future<void> _rejectClient(String coachUid, String clientUid) async {
    try {
      unawaited(HapticFeedback.lightImpact());
      await CoachService().rejectClient(clientUid);
      if (!mounted) return;
      AppSnackBar.warning(context, 'Request declined.');
    } catch (e) {
      debugPrint('CoachClientsScreen._rejectClient error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not decline request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final uid = context.read<UserProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      body: StreamBuilder<List<CoachClientModel>>(
        stream: CoachService().getClientsStream(uid),
        builder: (context, snapshot) {
          final allClients = snapshot.data ?? [];
          final pending = allClients
              .where((c) => c.status == CoachClientStatus.pending)
              .toList();
          final active = allClients
              .where((c) => c.status == CoachClientStatus.active)
              .toList();
          final clientCount = active.length;

          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: palette.background,
                title: Row(
                  children: [
                    Text(
                      l10n.translate('coach.clients_title'),
                      style: AppText.of(context).headlineS.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                    if (clientCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$clientCount',
                          style: AppText.of(context).labelS.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: palette.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildBody(context, palette, l10n, uid, pending, active,
                  snapshot.connectionState),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
    String uid,
    List<CoachClientModel> pending,
    List<CoachClientModel> active,
    ConnectionState connectionState,
  ) {
    if (connectionState == ConnectionState.waiting) {
      return const AppSkeletonList();
    }

    if (pending.isEmpty && active.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_alt_rounded,
        title: l10n.translate('coach.clients_empty_title'),
        message: l10n.translate('coach.clients_empty_sub'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          _SectionHeader(
              title: l10n.translate('coach.clients_pending_section'),
              palette: palette),
          const SizedBox(height: 8),
          ...pending.map((c) => _PendingTile(
                client: c,
                palette: palette,
                l10n: l10n,
                onAccept: () => _acceptClient(uid, c.clientUid),
                onReject: () => _rejectClient(uid, c.clientUid),
              )),
          const SizedBox(height: 24),
        ],
        if (active.isNotEmpty) ...[
          _SectionHeader(
              title: l10n.translate('coach.clients_active_section'),
              palette: palette),
          const SizedBox(height: 8),
          ...active.map((c) => _ClientTile(
                client: c,
                palette: palette,
                l10n: l10n,
                onTap: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(CoachClientDetailScreen(client: c)),
                ),
              )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppPalette palette;
  const _SectionHeader({required this.title, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppText.of(context).overline.copyWith(
            color: palette.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final CoachClientModel client;
  final AppPalette palette;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _ClientTile(
      {required this.client,
      required this.palette,
      required this.l10n,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withValues(alpha: 0.15),
                backgroundImage: client.clientPhotoURL != null
                    ? NetworkImage(client.clientPhotoURL!)
                    : null,
                child: client.clientPhotoURL == null
                    ? Icon(Icons.person_rounded, color: primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.clientDisplayName ?? 'Client',
                            style: AppText.of(context).bodyM.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (client.isAtRisk)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: palette.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.translate('coach.client_at_risk_label'),
                              style: AppText.of(context).overline.copyWith(
                                  color: palette.warning,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (client.clientStreak != null) ...[
                          const Icon(Icons.local_fire_department_rounded,
                              size: 14, color: Color(0xFFF97300)),
                          const SizedBox(width: 3),
                          Text(
                            '${client.clientStreak}d streak',
                            style: AppText.of(context).labelS.copyWith(
                                color: const Color(0xFFF97300),
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Icon(Icons.schedule_rounded,
                            size: 14, color: palette.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          client.lastLoggedAt == null
                              ? 'Never logged'
                              : '${l10n.translate('coach.client_last_logged')} ${client.daysSinceLastLog} ${l10n.translate('coach.client_days_ago')}',
                          style: AppText.of(context)
                              .labelS
                              .copyWith(color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: palette.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final CoachClientModel client;
  final AppPalette palette;
  final AppLocalizations l10n;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _PendingTile({
    required this.client,
    required this.palette,
    required this.l10n,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withValues(alpha: 0.15),
                backgroundImage: client.clientPhotoURL != null
                    ? NetworkImage(client.clientPhotoURL!)
                    : null,
                child: client.clientPhotoURL == null
                    ? Icon(Icons.person_rounded, color: primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  client.clientDisplayName ?? 'User',
                  style: AppText.of(context).bodyM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              AppButton(
                label: l10n.translate('coach.client_reject'),
                onPressed: onReject,
                size: AppButtonSize.small,
                expand: false,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l10n.translate('coach.client_accept'),
                onPressed: onAccept,
                size: AppButtonSize.small,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
