import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/widgets/ds/ds.dart';
import 'gym_checkin_screen.dart';
import 'gym_community_screen.dart';
import 'gym_leaderboard_screen.dart';

class GymMemberHomeScreen extends StatelessWidget {
  final GymModel gym;
  const GymMemberHomeScreen({super.key, required this.gym});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final primary = gym.resolvedBrandColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          gym.name,
          style: text.titleM.copyWith(color: primary),
        ),
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(gym: gym, primary: primary),
              const SizedBox(height: AppSpacing.lg),
              _ActionCard(
                icon: Icons.forum_rounded,
                title: t.translate('gym.member_community'),
                subtitle: t.translate('gym.member_community_sub'),
                primary: primary,
                onTap: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(
                    GymCommunityScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      isOwner: false,
                      brandColor: primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: t.translate('gym.member_checkin'),
                subtitle: t.translate('gym.member_checkin_sub'),
                primary: primary,
                onTap: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(
                    GymCheckInScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      gymLat: gym.latitude,
                      gymLng: gym.longitude,
                      checkInRadius: gym.checkInRadius,
                      brandColor: primary,
                    ),
                  ),
                ),
              ),
              if (gym.latitude != null && gym.longitude != null) ...[
                const SizedBox(height: AppSpacing.md),
                _LocationCard(gym: gym, primary: primary),
              ],
              const SizedBox(height: AppSpacing.md),
              _ActionCard(
                icon: Icons.leaderboard_rounded,
                title: t.translate('gym.member_leaderboard'),
                subtitle: t.translate('gym.member_leaderboard_sub'),
                primary: primary,
                onTap: () => Navigator.push(
                  context,
                  AppTransitions.slideRight(
                    GymLeaderboardScreen(
                      gymId: gym.id,
                      gymName: gym.name,
                      brandColor: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final GymModel gym;
  final Color primary;

  const _HeaderCard({required this.gym, required this.primary});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final hasLogo = gym.logoUrl != null && gym.logoUrl!.isNotEmpty;

    return AppGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  image: hasLogo
                      ? DecorationImage(
                          image: NetworkImage(gym.logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasLogo
                    ? null
                    : Icon(
                        Icons.fitness_center_rounded,
                        color: primary,
                        size: 30,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym.name,
                      style: text.headlineS,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (gym.locationDisplay.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        gym.locationDisplay,
                        style: text.bodyM
                            .copyWith(color: palette.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: palette.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '${gym.memberCount}',
                          style: text.labelS
                              .copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (gym.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in gym.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        tag,
                        style: text.labelS.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final GymModel gym;
  final Color primary;

  const _LocationCard({required this.gym, required this.primary});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final t = AppLocalizations.of(context);
    final center = LatLng(gym.latitude!, gym.longitude!);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cookrange.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      gym.locationDisplay.isNotEmpty
                          ? gym.locationDisplay
                          : t.translate('gym.location_title'),
                      style: text.bodyM.copyWith(
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleM.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: text.bodyM.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: palette.textTertiary,
            size: 22,
          ),
        ],
      ),
    );
  }
}
