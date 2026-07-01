import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/utils/firestore_count.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../admin/admin_panel_screen.dart';
import '../../coach/coach_dashboard_screen.dart';
import '../../gym/gym_dashboard_screen.dart';

/// Shows role-specific quick-access cards on the home screen.
/// Renders a card for every non-consumer role the user holds.
/// Pure consumer → returns SizedBox.shrink().
class RoleQuickCard extends StatelessWidget {
  final UserModel user;

  const RoleQuickCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];

    if (user.hasRole(UserRole.admin)) cards.add(_AdminCard(user: user));
    if (user.hasRole(UserRole.gymOwner)) cards.add(_GymCard(user: user));
    if (user.hasRole(UserRole.coach)) cards.add(_CoachCard(user: user));

    if (cards.isEmpty) return const SizedBox.shrink();
    if (cards.length == 1) return cards.first;

    return Column(
      children: cards
          .expand((c) => [c, SizedBox(height: 12.h)])
          .take(cards.length * 2 - 1)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin card
// ─────────────────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final UserModel user;

  const _AdminCard({required this.user});

  static const _accentColor = Color(0xFFEC4899);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<int>(
      stream: AdminService().pendingCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final body = count > 0
            ? l10n.translate(
                'home.role_card.admin_pending',
                variables: {'n': '$count'},
              )
            : l10n.translate('home.role_card.admin_all_clear');

        return _RoleCardShell(
          accentColor: _accentColor,
          icon: Icons.admin_panel_settings_rounded,
          title: l10n.translate('home.role_card.admin_title'),
          body: body,
          onTap: () => Navigator.of(context)
              .push(AppTransitions.slideRight(const AdminPanelScreen())),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach card
// ─────────────────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final UserModel user;

  const _CoachCard({required this.user});

  static const _accentColor = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('coach_profiles')
          .doc(user.uid)
          .collection('clients')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.size ?? 0;
        final body = l10n.translate(
          'home.role_card.coach_clients',
          variables: {'n': '$count'},
        );

        return _RoleCardShell(
          accentColor: _accentColor,
          icon: Icons.sports_rounded,
          title: l10n.translate('home.role_card.coach_title'),
          body: body,
          onTap: () => Navigator.of(context)
              .push(AppTransitions.slideRight(const CoachDashboardScreen())),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gym owner card
// ─────────────────────────────────────────────────────────────────────────────

class _GymCard extends StatelessWidget {
  final UserModel user;

  const _GymCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accentColor = Theme.of(context).primaryColor;

    // Member COUNT only — use the cheap aggregation poll, not a whole-collection
    // listener on the always-visible home screen (was a major read-cost sink).
    return StreamBuilder<int>(
      stream: pollCount(
        FirebaseFirestore.instance
            .collection('members')
            .where('gym_uid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active'),
        interval: const Duration(minutes: 2),
      ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final body = l10n.translate(
          'home.role_card.gym_members',
          variables: {'n': '$count'},
        );

        return _RoleCardShell(
          accentColor: accentColor,
          icon: Icons.fitness_center_rounded,
          title: l10n.translate('home.role_card.gym_title'),
          body: body,
          onTap: () => Navigator.of(context)
              .push(AppTransitions.slideRight(const GymDashboardScreen())),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared shell — glassmorphic row card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCardShell extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _RoleCardShell({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final bgAlpha = palette.isDark ? 0.08 : 0.05;
    const borderAlpha = 0.18;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: accentColor.withValues(alpha: borderAlpha),
          ),
        ),
        padding: EdgeInsets.all(AppSpacing.md.r),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 18.r,
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            // Title + body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.titleM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    body,
                    style: text.bodyM.copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.xs.w),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textSecondary,
              size: 20.r,
            ),
          ],
        ),
      ),
    );
  }
}
