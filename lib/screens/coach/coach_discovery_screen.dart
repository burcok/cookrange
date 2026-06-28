import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/data/turkish_locations.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_profile_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_service.dart';
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
  String _sortBy = 'display_name'; // 'display_name'|'avg_rating'|'client_count'|'created_at'

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
      final results = await CoachService().searchCoaches(
        _query,
        city: _selectedCity,
        sortBy: _sortBy,
      );
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(t.translate('coach.discovery_title')),
        backgroundColor: palette.background,
        elevation: 0,
      ),
      body: Column(
        children: [
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
            sortBy: _sortBy,
            onCityChanged: (city) {
              setState(() { _selectedCity = city; });
              _load();
            },
            onSortChanged: (sort) {
              setState(() { _sortBy = sort; });
              _load();
            },
            palette: palette,
            l10n: t,
          ),
          Expanded(child: _buildBody(t, palette)),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: _coaches.length,
      itemBuilder: (context, index) {
        final coach = _coaches[index];
        return RepaintBoundary(
          child: _CoachCard(
            coach: coach,
            index: index,
            onTap: () => _openProfile(coach),
          ),
        );
      },
    );
  }
}

class _CoachCard extends StatefulWidget {
  final CoachProfileModel coach;
  final int index;
  final VoidCallback onTap;

  const _CoachCard({
    required this.coach,
    required this.index,
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
        child: AppCard(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(coach: coach, palette: palette, text: text),
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
                                style: text.titleM
                                    .copyWith(fontWeight: FontWeight.w700),
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
                        if (coach.bio != null && coach.bio!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            coach.bio!,
                            style: text.bodyM
                                .copyWith(color: palette.textSecondary),
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
                      _SpecChip(label: spec, palette: palette, text: text),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
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
                    style:
                        text.labelS.copyWith(color: palette.textSecondary),
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
              // ── Request button ─────────────────────────────────────────
              if (!isSelf && currentUser?.hasRole(UserRole.coach) != true) ...[
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
                    // No request yet — show button
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
      ),
    );
  }
}

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

class _Avatar extends StatelessWidget {
  final CoachProfileModel coach;
  final AppPalette palette;
  final AppText text;

  const _Avatar({
    required this.coach,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = coach.photoURL != null && coach.photoURL!.isNotEmpty;
    if (hasPhoto) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: palette.surfaceVariant,
        backgroundImage: NetworkImage(coach.photoURL!),
      );
    }
    final initials = coach.displayName.trim().isNotEmpty
        ? coach.displayName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 26,
      backgroundColor: palette.surfaceVariant,
      child: Text(
        initials,
        style: text.titleM.copyWith(color: palette.textSecondary),
      ),
    );
  }
}

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

// ── Coach Filter Bar ────────────────────────────────────────────────────────────

class _CoachFilterBar extends StatelessWidget {
  final String? selectedCity;
  final String sortBy;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String> onSortChanged;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _CoachFilterBar({
    required this.selectedCity,
    required this.sortBy,
    required this.onCityChanged,
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    // Label pinned above a compact indicator pill.
    Widget sortChip(String value, String label) {
      final active = sortBy == value;
      return GestureDetector(
        onTap: () => onSortChanged(value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.of(context).labelS.copyWith(
                    fontSize: 10.sp,
                    height: 1.2,
                    color: active ? primary : palette.textTertiary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
            SizedBox(height: 3.h),
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 30.w,
              height: 20.h,
              decoration: BoxDecoration(
                color: active
                    ? primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full.r),
                border: Border.all(
                  color: active
                      ? primary.withValues(alpha: 0.4)
                      : palette.border,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: active
                  ? Center(
                      child: Icon(Icons.check_rounded,
                          size: 11.r, color: primary),
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: SizedBox(
        height: 58.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          children: [
            // City filter chip — label pinned above pill
            GestureDetector(
              onTap: () => _showCityPicker(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCity ?? l10n.translate('discovery.filter_city'),
                    style: AppText.of(context).labelS.copyWith(
                          fontSize: 10.sp,
                          height: 1.2,
                          color: selectedCity != null
                              ? primary
                              : palette.textTertiary,
                          fontWeight: selectedCity != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                  ),
                  SizedBox(height: 3.h),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: selectedCity != null
                          ? primary.withValues(alpha: 0.12)
                          : palette.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppRadius.full.r),
                      border: Border.all(
                        color: selectedCity != null
                            ? primary.withValues(alpha: 0.4)
                            : palette.border,
                        width: selectedCity != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_city_rounded,
                            size: 13.r,
                            color: selectedCity != null
                                ? primary
                                : palette.textSecondary),
                        SizedBox(width: 3.w),
                        Icon(
                          selectedCity != null
                              ? Icons.check_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 13.r,
                          color: selectedCity != null
                              ? primary
                              : palette.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            sortChip('display_name', l10n.translate('discovery.sort_name')),
            SizedBox(width: 8.w),
            sortChip('avg_rating', l10n.translate('coach.sort_top_rated')),
            SizedBox(width: 8.w),
            sortChip('client_count',
                l10n.translate('coach.sort_most_active')),
            SizedBox(width: 8.w),
            sortChip('created_at', l10n.translate('discovery.sort_newest')),
          ],
        ),
      ),
    );
  }
}
