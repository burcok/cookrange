import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/data/turkish_locations.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_profile_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_service.dart';
import '../../core/utils/haversine.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_dashboard_screen.dart';
import 'coach_profile_screen.dart';

class CoachDiscoveryScreen extends StatefulWidget {
  const CoachDiscoveryScreen({super.key});

  @override
  State<CoachDiscoveryScreen> createState() => _CoachDiscoveryScreenState();
}

class _CoachDiscoveryScreenState extends State<CoachDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _error = false;
  List<CoachProfileModel> _coaches = const [];
  String _query = '';
  String? _selectedCity;
  String? _selectedDistrict;
  String _sortBy = 'client_count'; // 'avg_rating'|'client_count'|'created_at'|'near_me'

  // Near Me state
  double? _userLat;
  double? _userLon;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final firestoreSort =
          _sortBy == 'near_me' ? 'client_count' : _sortBy;
      var results = await CoachService().searchCoaches(
        _query,
        city: _selectedCity,
        district: _selectedDistrict,
        sortBy: firestoreSort,
      );
      if (!mounted) return;
      // Client-side distance sort when near_me is active
      if (_sortBy == 'near_me' &&
          _userLat != null &&
          _userLon != null) {
        results = List.from(results)
          ..sort((a, b) {
            final da = (a.latitude != null && a.longitude != null)
                ? haversineKm(
                    _userLat!, _userLon!, a.latitude!, a.longitude!)
                : double.infinity;
            final db = (b.latitude != null && b.longitude != null)
                ? haversineKm(
                    _userLat!, _userLon!, b.latitude!, b.longitude!)
                : double.infinity;
            return da.compareTo(db);
          });
      }
      setState(() {
        _coaches = results;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('CoachDiscoveryScreen._load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _activateNearMe() async {
    final l10n = AppLocalizations.of(context);
    final consent = await PermissionPrimer.show(
      context,
      icon: Icons.location_on_rounded,
      iconColor: AppPalette.of(context).warning,
      title: l10n.translate('coach.nearby_consent_title'),
      rationale: l10n.translate('coach.nearby_consent_rationale'),
      allowLabel: l10n.translate('permission.allow'),
      notNowLabel: l10n.translate('permission.not_now'),
    );
    if (!mounted) return;
    if (!consent) {
      setState(() => _sortBy = 'client_count');
      return;
    }
    setState(() => _loadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _sortBy = 'client_count';
        });
        AppSnackBar.warning(
            context, l10n.translate('coach.location_denied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLon = pos.longitude;
        _loadingLocation = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _sortBy = 'client_count';
      });
      AppSnackBar.error(
          context, AppLocalizations.of(context).translate('coach.location_error'));
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = value.trim();
      _load();
    });
  }

  void _openProfile(CoachProfileModel coach) {
    Navigator.push(
      context,
      AppTransitions.slideRight(CoachProfileScreen(coachUid: coach.uid)),
    );
  }

  void _becomeCoach() {
    Navigator.push(
      context,
      AppTransitions.slideRight(const CoachDashboardScreen()),
    );
  }

  bool get _showRankBadges =>
      _sortBy == 'avg_rating' || _sortBy == 'client_count' || _sortBy == 'near_me';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t.translate('coach.discovery_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: palette.background.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Mesh-glow ambient background ─────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  width: 280.r,
                  height: 280.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -60,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(
                  width: 240.r,
                  height: 240.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.energy.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────────
          Column(
            children: [
              // AppBar space
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: AppTextField(
                  controller: _searchController,
                  hintText: t.translate('coach.discovery_search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  onChanged: _onSearchChanged,
                ),
              ),
              _CoachFilterBar(
                selectedCity: _selectedCity,
                selectedDistrict: _selectedDistrict,
                sortBy: _sortBy,
                loadingLocation: _loadingLocation,
                onCityChanged: (city) {
                  setState(() {
                    _selectedCity = city;
                    _selectedDistrict = null;
                  });
                  _load();
                },
                onDistrictChanged: (district) {
                  setState(() => _selectedDistrict = district);
                  _load();
                },
                onSortChanged: (sort) {
                  setState(() => _sortBy = sort);
                  if (sort == 'near_me') {
                    unawaited(_activateNearMe());
                  } else {
                    _load();
                  }
                },
                palette: palette,
                l10n: t,
              ),
              Expanded(child: _buildBody(t, palette)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations t, AppPalette palette) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppSkeletonList(itemCount: 5),
      );
    }

    if (_error) {
      return AppErrorState(
        title: t.translate('common.error'),
        message: t.translate('errors.general'),
        onRetry: _load,
      );
    }

    if (_coaches.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: t.translate('coach.discovery_empty_title'),
        message: t.translate('coach.discovery_empty_msg'),
        actionLabel: t.translate('coach.discovery_cta'),
        onAction: _becomeCoach,
      );
    }

    final showTopSection =
        _query.isEmpty && _selectedCity == null && _selectedDistrict == null;

    return CustomScrollView(
      slivers: [
        if (showTopSection)
          SliverToBoxAdapter(
            child: _TopCoachesSection(
              onTap: _openProfile,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          sliver: SliverList.builder(
            itemCount: _coaches.length,
            itemBuilder: (context, index) {
              final coach = _coaches[index];
              return RepaintBoundary(
                child: _CoachCard(
                  coach: coach,
                  index: index,
                  rank: _showRankBadges && index < 3 ? index + 1 : null,
                  onTap: () => _openProfile(coach),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Rank badge colors ────────────────────────────────────────────────────────

const _rankGold = Color(0xFFFFCC00);
const _rankSilver = Color(0xFFC0C8D2);
const _rankBronze = Color(0xFFCD7F32);

Color _rankColor(int rank) {
  switch (rank) {
    case 1:
      return _rankGold;
    case 2:
      return _rankSilver;
    case 3:
      return _rankBronze;
    default:
      return _rankBronze;
  }
}

String _rankLabel(int rank) {
  switch (rank) {
    case 1:
      return '#1';
    case 2:
      return '#2';
    case 3:
      return '#3';
    default:
      return '#$rank';
  }
}

// ── Coach Card ───────────────────────────────────────────────────────────────

class _CoachCard extends StatefulWidget {
  final CoachProfileModel coach;
  final int index;

  /// 1-based rank (1=gold, 2=silver, 3=bronze). Null = no badge.
  final int? rank;
  final VoidCallback onTap;

  const _CoachCard({
    required this.coach,
    required this.index,
    required this.rank,
    required this.onTap,
  });

  @override
  State<_CoachCard> createState() => _CoachCardState();
}

class _CoachCardState extends State<_CoachCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 400));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final coach = widget.coach;
    final specs = coach.specializations.take(3).toList();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUser = context.read<UserProvider>().user;
    final isSelf = coach.uid == currentUid;

    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppGlassCard(
              onTap: widget.onTap,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppInitialsAvatar(
                        photoUrl: coach.photoURL,
                        name: coach.displayName,
                        size: 52.r,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    coach.displayName,
                                    style: text.titleM.copyWith(
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (coach.isVerified) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified_rounded,
                                      size: 15, color: Colors.blue.shade400),
                                ],
                              ],
                            ),
                            // ── Rating stars ──────────────────────────
                            if (coach.avgRating > 0) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              _RatingRow(
                                rating: coach.avgRating,
                                count: coach.ratingCount,
                                palette: palette,
                                text: text,
                              ),
                            ],
                            if (coach.bio != null &&
                                coach.bio!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                coach.bio!,
                                style: text.bodyM.copyWith(
                                    color: palette.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final spec in specs)
                          _SpecChip(
                              label: spec, palette: palette, text: text),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // ── Trust signal badges ───────────────────────────
                  _TrustBadgeRow(coach: coach, palette: palette, text: text),
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
                        '${coach.clientCount}',
                        style: text.labelS
                            .copyWith(color: palette.textSecondary),
                      ),
                      if (coach.hourlyRate != null) ...[
                        const Spacer(),
                        Text(
                          '₺${coach.hourlyRate!.toStringAsFixed(0)}${t.translate('coach.discovery_per_hour')}',
                          style: text.labelS.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // ── Request button ────────────────────────────────
                  if (!isSelf &&
                      currentUser?.hasRole(UserRole.coach) != true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    StreamBuilder<String?>(
                      stream: CoachService()
                          .getRequestStatusStream(coach.uid, currentUid),
                      builder: (context, snap) {
                        final status = snap.data;
                        if (status == 'accepted') {
                          return _RequestChip(
                            label: t.translate('coach.request_accepted'),
                            color: palette.success,
                            icon: Icons.check_circle_rounded,
                            palette: palette,
                            text: text,
                          );
                        }
                        if (status == 'pending') {
                          return _RequestChip(
                            label: t.translate('coach.request_pending'),
                            color: palette.warning,
                            icon: Icons.hourglass_top_rounded,
                            palette: palette,
                            text: text,
                          );
                        }
                        return AppButton(
                          label: t.translate('coach.request_coaching'),
                          size: AppButtonSize.small,
                          expand: false,
                          variant: AppButtonVariant.tonal,
                          onPressed: () async {
                            unawaited(HapticFeedback.mediumImpact());
                            try {
                              await CoachService()
                                  .requestCoaching(coach.uid, currentUid);
                            } catch (e) {
                              debugPrint(
                                  '_CoachCard: requestCoaching error: $e');
                            }
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            // ── Rank badge ────────────────────────────────────────────
            if (widget.rank != null)
              Positioned(
                top: -10,
                right: 12,
                child: _RankBadge(rank: widget.rank!),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Rank Badge ───────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = _rankColor(rank);
    final label = _rankLabel(rank);
    final text = AppText.of(context);

    return Container(
      width: 36.r,
      height: 36.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: text.labelS.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 9.sp,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rating Row ───────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final double rating;
  final int count;
  final AppPalette palette;
  final AppText text;

  const _RatingRow({
    required this.rating,
    required this.count,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 14, color: palette.warning),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: text.labelS.copyWith(
            color: palette.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: text.labelS.copyWith(
              color: palette.textTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Request Chip ─────────────────────────────────────────────────────────────

class _RequestChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final AppPalette palette;
  final AppText text;

  const _RequestChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: text.labelS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spec Chip ────────────────────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final AppText text;

  const _SpecChip({
    required this.label,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: text.labelS.copyWith(
          color: palette.info,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Top Coaches Section ──────────────────────────────────────────────────────

class _TopCoachesSection extends StatelessWidget {
  final void Function(CoachProfileModel) onTap;

  const _TopCoachesSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final text = AppText.of(context);

    return StreamBuilder<List<CoachProfileModel>>(
      stream: CoachService().getTopCoachesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 140, height: 18),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeletonBox(
                    width: double.infinity,
                    height: 100,
                    radius: AppRadius.card,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeletonBox(
                    width: double.infinity,
                    height: 100,
                    radius: AppRadius.card,
                  ),
                ],
              ),
            ),
          );
        }

        final coaches = snap.data ?? [];
        if (coaches.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: palette.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    t.translate('coach.top_coaches_title'),
                    style: text.titleM.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...coaches.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TopCoachCard(
                    coach: e.value,
                    index: e.key,
                    onTap: () => onTap(e.value),
                    palette: palette,
                    text: text,
                    t: t,
                  ),
                ),
              ),
              Divider(
                color: palette.divider,
                thickness: 1,
                height: AppSpacing.lg,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Top Coach Card (featured) ─────────────────────────────────────────────────

class _TopCoachCard extends StatelessWidget {
  final CoachProfileModel coach;
  final int index;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText text;
  final AppLocalizations t;

  const _TopCoachCard({
    required this.coach,
    required this.index,
    required this.onTap,
    required this.palette,
    required this.text,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppInitialsAvatar(
            photoUrl: coach.photoURL,
            name: coach.displayName,
            size: 48.r,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        coach.displayName,
                        style: text.titleM.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (coach.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Colors.blue.shade400,
                      ),
                    ],
                  ],
                ),
                if (coach.avgRating > 0) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _RatingRow(
                    rating: coach.avgRating,
                    count: coach.ratingCount,
                    palette: palette,
                    text: text,
                  ),
                ],
                if (coach.city != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: palette.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        coach.city!,
                        style: text.labelS.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 12,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${coach.clientCount}',
                      style: text.labelS.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // TOP RATED badge
          _GradientPill(
            label: t.translate('coach.badge_top_rated'),
            colors: const [_rankGold, AppPalette.brand],
          ),
        ],
      ),
    );
  }
}

// ── Gradient Pill Badge ──────────────────────────────────────────────────────

class _GradientPill extends StatelessWidget {
  final String label;
  final List<Color> colors;

  const _GradientPill({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: text.labelS.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 9.sp,
        ),
      ),
    );
  }
}

// ── Trust Badge Row ──────────────────────────────────────────────────────────

class _TrustBadgeRow extends StatelessWidget {
  final CoachProfileModel coach;
  final AppPalette palette;
  final AppText text;

  const _TrustBadgeRow({
    required this.coach,
    required this.palette,
    required this.text,
  });

  bool get _isTopRated =>
      coach.isVerified &&
      coach.avgRating >= 4.8 &&
      coach.ratingCount >= 5;

  bool get _isRising =>
      !coach.isVerified &&
      coach.avgRating >= 4.0 &&
      coach.ratingCount >= 2 &&
      coach.clientCount >= 3;

  bool get _isFastResponder => coach.clientCount >= 10;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasBadges = _isTopRated || _isRising || _isFastResponder;
    if (!hasBadges) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (_isTopRated)
          _InlineBadge(
            icon: Icons.workspace_premium_rounded,
            label: t.translate('coach.badge_top_rated'),
            color: palette.warning,
            palette: palette,
            text: text,
          ),
        if (_isRising)
          _GradientPill(
            label: t.translate('coach.badge_rising'),
            colors: const [AppPalette.energyLight, AppPalette.brand],
          ),
        if (_isFastResponder)
          _InlineBadge(
            icon: Icons.bolt_rounded,
            label: t.translate('coach.badge_fast_responder'),
            color: palette.success,
            palette: palette,
            text: text,
          ),
      ],
    );
  }
}

// ── Inline Badge (icon + label, solid fill) ──────────────────────────────────

class _InlineBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AppPalette palette;
  final AppText text;

  const _InlineBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: text.labelS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coach Filter Bar ─────────────────────────────────────────────────────────

class _CoachFilterBar extends StatelessWidget {
  final String? selectedCity;
  final String? selectedDistrict;
  final String sortBy;
  final bool loadingLocation;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String> onSortChanged;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _CoachFilterBar({
    required this.selectedCity,
    required this.selectedDistrict,
    required this.sortBy,
    required this.loadingLocation,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.onSortChanged,
    required this.palette,
    required this.l10n,
  });

  void _showCityPicker(BuildContext context) {
    final cities = TurkishLocations.provinces;
    AppSheet.show(
      context: context,
      title: l10n.translate('discovery.filter_city'),
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Icon(Icons.clear_rounded,
                size: 18.r, color: palette.textTertiary),
            title: Text(l10n.translate('discovery.filter_all'),
                style: TextStyle(color: palette.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onCityChanged(null);
            },
          ),
          ...cities.map((city) => ListTile(
                title: Text(city,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: selectedCity == city
                          ? FontWeight.w700
                          : FontWeight.normal,
                    )),
                trailing: selectedCity == city
                    ? Icon(Icons.check_rounded,
                        color: palette.info, size: 18.r)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onCityChanged(city);
                },
              )),
        ],
      ),
    );
  }

  void _showDistrictPicker(BuildContext context) {
    if (selectedCity == null) return;
    final districts = TurkishLocations.districtsOf(selectedCity!);
    AppSheet.show(
      context: context,
      title: l10n.translate('discovery.filter_district'),
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Icon(Icons.clear_rounded,
                size: 18.r, color: palette.textTertiary),
            title: Text(l10n.translate('discovery.filter_all'),
                style: TextStyle(color: palette.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onDistrictChanged(null);
            },
          ),
          ...districts.map((d) => ListTile(
                title: Text(d,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: selectedDistrict == d
                          ? FontWeight.w700
                          : FontWeight.normal,
                    )),
                trailing: selectedDistrict == d
                    ? Icon(Icons.check_rounded,
                        color: palette.info, size: 18.r)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onDistrictChanged(d);
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final hasFilter = selectedCity != null || sortBy != 'client_count';

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              children: [
                // ── Location ─────────────────────────────────────────
                _locationPill(
                  context,
                  icon: Icons.location_city_rounded,
                  value: selectedCity,
                  placeholder: l10n.translate('discovery.filter_city'),
                  primary: primary,
                  onTap: () => _showCityPicker(context),
                ),
                if (selectedCity != null) ...[
                  SizedBox(width: 6.w),
                  _locationPill(
                    context,
                    icon: Icons.map_outlined,
                    value: selectedDistrict,
                    placeholder:
                        l10n.translate('discovery.filter_district'),
                    primary: primary,
                    onTap: () => _showDistrictPicker(context),
                  ),
                ],
                // ── Divider ──────────────────────────────────────────
                SizedBox(width: 10.w),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 6.h,
                  endIndent: 6.h,
                  color: palette.border,
                ),
                SizedBox(width: 10.w),
                // ── Sort ─────────────────────────────────────────────
                _sortPill(context, 'avg_rating', Icons.star_rounded,
                    l10n.translate('discovery.sort_top_rated'), primary),
                SizedBox(width: 6.w),
                _sortPill(
                    context,
                    'client_count',
                    Icons.local_fire_department_rounded,
                    l10n.translate('discovery.sort_popular'),
                    primary),
                SizedBox(width: 6.w),
                _sortPill(
                    context,
                    'created_at',
                    Icons.new_releases_rounded,
                    l10n.translate('discovery.sort_newest'),
                    primary),
                SizedBox(width: 6.w),
                _nearMePill(context, primary),
              ],
            ),
          ),
          if (hasFilter)
            Padding(
              padding:
                  EdgeInsets.only(left: AppSpacing.lg.w, top: 4.h, bottom: 2.h),
              child: GestureDetector(
                onTap: () {
                  onCityChanged(null);
                  onSortChanged('client_count');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 12.r, color: palette.textTertiary),
                    SizedBox(width: 4.w),
                    Text(
                      l10n.translate('discovery.filter_clear'),
                      style: AppText.of(context).labelS.copyWith(
                            color: palette.textTertiary,
                            fontSize: 11.sp,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationPill(
    BuildContext context, {
    required IconData icon,
    required String? value,
    required String placeholder,
    required Color primary,
    required VoidCallback onTap,
  }) {
    final active = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.1)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.45)
                : palette.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13.r,
                color: active ? primary : palette.textSecondary),
            SizedBox(width: 5.w),
            Text(
              value ?? placeholder,
              style: AppText.of(context).labelM.copyWith(
                    fontSize: 12.sp,
                    color: active ? primary : palette.textSecondary,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
            SizedBox(width: 4.w),
            Icon(
              active
                  ? Icons.check_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 13.r,
              color: active ? primary : palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortPill(BuildContext context, String value, IconData icon,
      String label, Color primary) {
    final active = sortBy == value;
    return GestureDetector(
      onTap: () => onSortChanged(value),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.45)
                : palette.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 11.r, color: primary),
              SizedBox(width: 4.w),
            ] else ...[
              Icon(icon, size: 12.r, color: palette.textTertiary),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: AppText.of(context).labelM.copyWith(
                    fontSize: 12.sp,
                    color: active ? primary : palette.textSecondary,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearMePill(BuildContext context, Color primary) {
    final active = sortBy == 'near_me';
    final energyColor = palette.energy;
    return GestureDetector(
      onTap: loadingLocation ? null : () => onSortChanged('near_me'),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: active
              ? energyColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(
            color: active
                ? energyColor.withValues(alpha: 0.45)
                : palette.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loadingLocation)
              SizedBox(
                width: 12.r,
                height: 12.r,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: primary),
              )
            else if (active) ...[
              Icon(Icons.check_rounded,
                  size: 11.r, color: energyColor),
              SizedBox(width: 4.w),
            ] else ...[
              Icon(Icons.near_me_rounded,
                  size: 12.r, color: palette.textTertiary),
              SizedBox(width: 4.w),
            ],
            if (!loadingLocation)
              Text(
                l10n.translate('discovery.sort_near_me'),
                style: AppText.of(context).labelM.copyWith(
                      fontSize: 12.sp,
                      color:
                          active ? energyColor : palette.textSecondary,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
