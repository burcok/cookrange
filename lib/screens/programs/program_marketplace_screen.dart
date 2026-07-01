import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/program_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/program_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'program_detail_screen.dart';
import '../coach/coach_dashboard_screen.dart';

class ProgramMarketplaceScreen extends StatefulWidget {
  const ProgramMarketplaceScreen({super.key});

  @override
  State<ProgramMarketplaceScreen> createState() =>
      _ProgramMarketplaceScreenState();
}

class _ProgramMarketplaceScreenState extends State<ProgramMarketplaceScreen> {
  ProgramCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('program.marketplace_title'),
          style:
              AppText.of(context).titleL.copyWith(color: palette.textPrimary),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryFilterRow(
            selectedCategory: _selectedCategory,
            onSelected: (c) => setState(() => _selectedCategory = c),
            l10n: l10n,
          ),
          Expanded(
            child: StreamBuilder<List<ProgramModel>>(
              stream: ProgramService().getPublishedProgramsStream(
                category: _selectedCategory,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _ProgramGridSkeleton();
                }
                if (snap.hasError) {
                  return AppErrorState(
                    title: l10n.translate('programs.error.load_failed'),
                    message: snap.error.toString(),
                    retryLabel: 'Retry',
                    onRetry: () => setState(() {}),
                  );
                }
                final programs = snap.data ?? [];
                if (programs.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.store_rounded,
                    title: l10n.translate('program.no_programs'),
                    message: l10n.translate('program.no_programs_msg'),
                    actionLabel: l10n.translate('program.empty_cta'),
                    onAction: () => Navigator.of(context).push(
                      AppTransitions.slideRight(const CoachDashboardScreen()),
                    ),
                  );
                }
                return GridView.builder(
                  padding: EdgeInsets.all(AppSpacing.md.r),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final delay = Duration(milliseconds: 60 * index);
                    return _ProgramCard(
                      program: programs[index],
                      animationDelay: delay,
                      palette: palette,
                      primary: primary,
                      l10n: l10n,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Filter Row ────────────────────────────────────────────────────────

class _CategoryFilterRow extends StatelessWidget {
  final ProgramCategory? selectedCategory;
  final ValueChanged<ProgramCategory?> onSelected;
  final AppLocalizations l10n;

  const _CategoryFilterRow({
    required this.selectedCategory,
    required this.onSelected,
    required this.l10n,
  });

  IconData _iconFor(ProgramCategory cat) {
    switch (cat) {
      case ProgramCategory.weightLoss:
        return Icons.monitor_weight_rounded;
      case ProgramCategory.muscleGain:
        return Icons.fitness_center_rounded;
      case ProgramCategory.endurance:
        return Icons.directions_run_rounded;
      case ProgramCategory.flexibility:
        return Icons.sports_gymnastics_rounded;
      case ProgramCategory.nutrition:
        return Icons.restaurant_rounded;
      case ProgramCategory.lifestyle:
        return Icons.self_improvement_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const categories = ProgramCategory.values;

    return AppFilterBar(
      children: [
        AppFilterPill(
          label: l10n.translate('program.all_categories'),
          icon: Icons.apps_rounded,
          active: selectedCategory == null,
          onTap: () => onSelected(null),
        ),
        ...categories.map((cat) => AppFilterPill(
              label: l10n.translate(cat.locKey),
              icon: _iconFor(cat),
              active: selectedCategory == cat,
              onTap: () => onSelected(cat == selectedCategory ? null : cat),
            )),
      ],
    );
  }
}

// ── Program Card ──────────────────────────────────────────────────────────────

class _ProgramCard extends StatefulWidget {
  final ProgramModel program;
  final Duration animationDelay;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _ProgramCard({
    required this.program,
    required this.animationDelay,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fade = CurvedAnimation(parent: _c, curve: AppMotion.decelerate);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: AppMotion.emphasized));

    Future.delayed(widget.animationDelay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final palette = widget.palette;
    final primary = widget.primary;
    final l10n = widget.l10n;
    final t = AppText.of(context);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: AppCard(
          padding: const EdgeInsets.all(0),
          onTap: () => Navigator.push(
            context,
            AppTransitions.slideUp(ProgramDetailScreen(program: p)),
          ),
          semanticLabel: p.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image / gradient placeholder
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card.r),
                  topRight: Radius.circular(AppRadius.card.r),
                ),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 110.h,
                      width: double.infinity,
                      child: p.coverImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: p.coverImageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              placeholder: (_, __) =>
                                  _GradientPlaceholder(category: p.category),
                              errorWidget: (_, __, ___) =>
                                  _GradientPlaceholder(category: p.category),
                            )
                          : _GradientPlaceholder(category: p.category),
                    ),
                    // Price badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: p.isFree ? const Color(0xFF10B981) : primary,
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          p.priceDisplay,
                          style: t.labelS.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(10.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleM.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.h),

                      // Coach name
                      Row(
                        children: [
                          if (p.coachPhotoUrl != null)
                            Padding(
                              padding: EdgeInsets.only(right: 4.w),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: p.coachPhotoUrl!,
                                  width: 14.r,
                                  height: 14.r,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 56,
                                  placeholder: (_, __) => Icon(
                                      Icons.person_rounded,
                                      size: 14.r,
                                      color: palette.textSecondary),
                                  errorWidget: (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      size: 14.r,
                                      color: palette.textSecondary),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.only(right: 4.w),
                              child: Icon(Icons.person_rounded,
                                  size: 12.r, color: palette.textSecondary),
                            ),
                          Expanded(
                            child: Text(
                              '${l10n.translate('program.by_coach')} ${p.coachName}',
                              style: t.labelS
                                  .copyWith(color: palette.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Duration + Enrollment row
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11.r, color: palette.textTertiary),
                          SizedBox(width: 3.w),
                          Text(
                            l10n
                                .translate('program.duration_weeks')
                                .replaceFirst(
                                    '{n}', p.durationWeeks.toString()),
                            style:
                                t.labelS.copyWith(color: palette.textTertiary),
                          ),
                          const Spacer(),
                          Icon(Icons.people_outline_rounded,
                              size: 11.r, color: palette.textTertiary),
                          SizedBox(width: 3.w),
                          Text(
                            '${p.enrollmentCount}',
                            style:
                                t.labelS.copyWith(color: palette.textTertiary),
                          ),
                        ],
                      ),
                    ],
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

// ── Gradient Placeholder ───────────────────────────────────────────────────────

class _GradientPlaceholder extends StatelessWidget {
  final ProgramCategory category;

  const _GradientPlaceholder({required this.category});

  List<Color> _colorsFor(ProgramCategory cat) {
    switch (cat) {
      case ProgramCategory.weightLoss:
        return [const Color(0xFFEF4444), const Color(0xFFF97316)];
      case ProgramCategory.muscleGain:
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
      case ProgramCategory.endurance:
        return [const Color(0xFF06B6D4), const Color(0xFF3B82F6)];
      case ProgramCategory.flexibility:
        return [const Color(0xFF10B981), const Color(0xFF06B6D4)];
      case ProgramCategory.nutrition:
        return [const Color(0xFFF59E0B), const Color(0xFF10B981)];
      case ProgramCategory.lifestyle:
        return [const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
    }
  }

  IconData _iconFor(ProgramCategory cat) {
    switch (cat) {
      case ProgramCategory.weightLoss:
        return Icons.trending_down_rounded;
      case ProgramCategory.muscleGain:
        return Icons.fitness_center_rounded;
      case ProgramCategory.endurance:
        return Icons.directions_run_rounded;
      case ProgramCategory.flexibility:
        return Icons.self_improvement_rounded;
      case ProgramCategory.nutrition:
        return Icons.restaurant_rounded;
      case ProgramCategory.lifestyle:
        return Icons.spa_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(_iconFor(category), size: 40.r, color: Colors.white54),
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────────

class _ProgramGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: EdgeInsets.all(AppSpacing.md.r),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const AppSkeletonBox(
          height: 220,
          radius: AppRadius.card,
        ),
      ),
    );
  }
}
