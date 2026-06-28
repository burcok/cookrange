import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../coach/coach_discovery_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../gym/gym_discovery_screen.dart';
import '../programs/program_marketplace_screen.dart';

class DiscoverHubScreen extends StatelessWidget {
  const DiscoverHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final user = context.watch<UserProvider>().user;
    final isPremium =
        user?.subscriptionTier.isPaid ?? false;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Ambient mesh-glow blobs so glass cards have visual depth behind them
          ...AppGradients.meshGlow(palette, primary),
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: palette.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            floating: true,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: palette.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.translate('discover.title'),
              style: text.titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // ── Header subtitle ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH.w,
                AppSpacing.xs.h,
                AppSpacing.screenH.w,
                AppSpacing.lg.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      l10n.translate('discover.subtitle'),
                      style: text.bodyM.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 2×2 Category Grid ─────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH.w,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                ),
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    icon: Icons.fitness_center_rounded,
                    title: l10n.translate('discover.gym'),
                    tagline: l10n.translate('discover.gym_tagline'),
                    accentColor: palette.info,
                    onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(const GymDiscoveryScreen()),
                    ),
                  ),
                  _DiscoverCard(
                    icon: Icons.person_rounded,
                    title: l10n.translate('discover.coach'),
                    tagline: l10n.translate('discover.coach_tagline'),
                    accentColor: const Color(0xFF6366F1),
                    onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(const CoachDiscoveryScreen()),
                    ),
                  ),
                  _DiscoverCard(
                    icon: Icons.school_rounded,
                    title: l10n.translate('discover.programs'),
                    tagline: l10n.translate('discover.program_tagline'),
                    accentColor: palette.success,
                    onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(
                          const ProgramMarketplaceScreen()),
                    ),
                  ),
                  _DiscoverCard(
                    icon: Icons.leaderboard_rounded,
                    title: l10n.translate('discover.leaderboard'),
                    tagline: l10n.translate('discover.leaderboard_tagline'),
                    accentColor: palette.warning,
                    onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(const LeaderboardScreen()),
                    ),
                  ),
                ]),
              ),
            ),

            // ── Premium banner (non-premium users only) ───────────────────
            if (!isPremium)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH.w,
                    AppSpacing.xl.h,
                    AppSpacing.screenH.w,
                    AppSpacing.md.h,
                  ),
                  child: _PremiumBanner(
                    onTap: () => FeatureGateService().showPaywall(context),
                  ),
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl.h)),
          ],
        ),
        ], // Stack children
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category card
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String tagline;
  final Color accentColor;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.icon,
    required this.title,
    required this.tagline,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);

    return AppGlassCard(
      padding: EdgeInsets.all(AppSpacing.md.r),
      onTap: onTap,
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container with tinted background
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: accentColor.withValues(
                  alpha: palette.isDark ? 0.18 : 0.12),
              borderRadius:
                  BorderRadius.circular(AppRadius.md.r),
            ),
            child: Icon(
              icon,
              size: 24.r,
              color: accentColor,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: text.titleM.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            tagline,
            style: text.labelM.copyWith(
              color: palette.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium banner
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return AppGlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 22.r,
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('discover.premium_title'),
                    style: text.titleM.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    l10n.translate('discover.premium_subtitle'),
                    style: text.labelM.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14.r,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
