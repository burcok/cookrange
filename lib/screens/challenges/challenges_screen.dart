import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/challenge_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/challenge_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../../core/widgets/sponsor_badge.dart';
import 'challenge_detail_screen.dart';
import 'widgets/create_challenge_sheet.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  final ChallengeService _service = ChallengeService();
  late TabController _tabController;
  ChallengeDifficulty? _difficultyFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateChallengeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18.r, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('challenge.screen_title'),
          style: t.headlineS.copyWith(
              fontWeight: FontWeight.bold, color: palette.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: palette.divider)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: primary,
              unselectedLabelColor: palette.textSecondary,
              indicatorColor: primary,
              indicatorWeight: 2.5,
              labelStyle: t.labelL.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  t.labelL.copyWith(fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: l10n.translate('challenge.tab_active')),
                Tab(text: l10n.translate('challenge.tab_mine')),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Difficulty filter chips
          _buildDifficultyFilter(context, l10n, palette, t, primary),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChallengeList(
                  stream: _service.getActiveChallengesStream(),
                  emptyKey: 'challenge.empty_active',
                  emptyIcon: Icons.emoji_events_outlined,
                  primary: primary,
                  difficultyFilter: _difficultyFilter,
                ),
                _ChallengeList(
                  stream: _service.getMyChallengesStream(),
                  emptyKey: 'challenge.empty_mine',
                  emptyIcon: Icons.flag_outlined,
                  primary: primary,
                  difficultyFilter: _difficultyFilter,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.translate('challenge.create_btn'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildDifficultyFilter(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
  ) {
    Color diffColor(ChallengeDifficulty d) {
      switch (d) {
        case ChallengeDifficulty.easy:
          return palette.success;
        case ChallengeDifficulty.medium:
          return palette.warning;
        case ChallengeDifficulty.hard:
          return palette.error;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // "All" chip
          _DiffChip(
            label: l10n.translate('challenge.difficulty.all'),
            color: primary,
            isSelected: _difficultyFilter == null,
            onTap: () => setState(() => _difficultyFilter = null),
            t: t,
          ),
          const SizedBox(width: 8),
          ...ChallengeDifficulty.values.map((d) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DiffChip(
                  label: l10n.translate(d.locKey),
                  color: diffColor(d),
                  isSelected: _difficultyFilter == d,
                  onTap: () => setState(() => _difficultyFilter = d),
                  t: t,
                ),
              )),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final AppText t;

  const _DiffChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: t.labelS.copyWith(
            color: color,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  final Stream<List<ChallengeModel>> stream;
  final String emptyKey;
  final IconData emptyIcon;
  final Color primary;
  final ChallengeDifficulty? difficultyFilter;

  const _ChallengeList({
    required this.stream,
    required this.emptyKey,
    required this.emptyIcon,
    required this.primary,
    this.difficultyFilter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<ChallengeModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            title: l10n.translate('challenge.error_loading'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSkeletonList(itemCount: 4);
        }
        final all = snapshot.data ?? [];
        final challenges = difficultyFilter == null
            ? all
            : all.where((c) => c.difficulty == difficultyFilter).toList();

        if (challenges.isEmpty) {
          return AppEmptyState(
            icon: emptyIcon,
            title: l10n.translate(emptyKey),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.xl.w, AppSpacing.xl.h, AppSpacing.xl.w,
              AppSpacing.xl.h + 80.h),
          itemCount: challenges.length,
          separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
          itemBuilder: (context, i) => _ChallengeCard(
            challenge: challenges[i],
            primary: primary,
          ),
        );
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final Color primary;

  const _ChallengeCard({
    required this.challenge,
    required this.primary,
  });

  IconData get _icon {
    switch (challenge.type) {
      case ChallengeType.steps:
        return Icons.directions_walk_rounded;
      case ChallengeType.calories:
        return Icons.local_fire_department_rounded;
      case ChallengeType.workoutDays:
        return Icons.fitness_center_rounded;
      case ChallengeType.custom:
        return Icons.emoji_events_rounded;
    }
  }

  Color _typeColor(AppPalette palette) {
    switch (challenge.type) {
      case ChallengeType.steps:
        return palette.energy;
      case ChallengeType.calories:
        return palette.calories;
      case ChallengeType.workoutDays:
        return palette.info;
      case ChallengeType.custom:
        return palette.fat;
    }
  }

  Color _difficultyColor(AppPalette palette) {
    switch (challenge.difficulty) {
      case ChallengeDifficulty.easy:
        return palette.success;
      case ChallengeDifficulty.medium:
        return palette.warning;
      case ChallengeDifficulty.hard:
        return palette.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final typeColor = _typeColor(palette);
    final isExpired = challenge.isExpired;

    final isSponsored = challenge.isSponsored;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppTransitions.slideUp(ChallengeDetailScreen(challengeId: challenge.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: isSponsored && !isExpired
                ? palette.warning.withValues(alpha: 0.45)
                : isExpired
                    ? palette.border.withValues(alpha: 0.4)
                    : typeColor.withValues(alpha: 0.25),
            width: isSponsored && !isExpired ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSponsored && !isExpired
                  ? palette.warning.withValues(alpha: 0.08)
                  : palette.shadow.withValues(alpha: 0.07),
              blurRadius: 12.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg.r),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    child: Icon(_icon, size: 24.r, color: typeColor),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  // Title + type + sponsor badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: t.titleL.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isExpired
                                  ? palette.textTertiary
                                  : palette.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        if (isSponsored) ...[
                          SponsorBadge(
                            sponsorName: challenge.sponsorName!,
                            sponsorLogoUrl: challenge.sponsorLogoUrl,
                          ),
                          SizedBox(height: 2.h),
                        ] else
                          Text(
                            l10n.translate(
                                'challenge.type.${challenge.type.name}'),
                            style: t.labelS
                                .copyWith(color: palette.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  // Status chip
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? palette.surfaceVariant
                          : palette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      isExpired
                          ? l10n.translate('challenge.ended')
                          : l10n.translate('challenge.days_left',
                              variables: {
                                'days': '${challenge.daysRemaining}'
                              }),
                      style: t.labelS.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? palette.textTertiary
                              : palette.success),
                    ),
                  ),
                ],
              ),
            ),
            // Description
            if (challenge.description.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.md.h),
                child: Text(
                  challenge.description,
                  style:
                      t.bodyM.copyWith(color: palette.textSecondary, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Reward chip (sponsored only)
            if (isSponsored && challenge.sponsorReward != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.sm.h),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    border: Border.all(
                        color: palette.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          size: 14.r, color: palette.warning),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: Text(
                          '${l10n.translate('challenge.sponsor.reward_badge')}: ${challenge.sponsorReward!}',
                          style: t.labelS.copyWith(
                            color: palette.warning,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Footer row
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
              decoration: BoxDecoration(
                color: palette.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.card.r)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 14.r, color: palette.textTertiary),
                  SizedBox(width: 4.w),
                  Text(
                    '${challenge.goal} ${challenge.unit}',
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                  SizedBox(width: AppSpacing.lg.w),
                  Icon(Icons.calendar_today_outlined,
                      size: 13.r, color: palette.textTertiary),
                  SizedBox(width: 4.w),
                  Text(
                    DateFormat('dd MMM').format(challenge.endDate),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                  const Spacer(),
                  // Difficulty badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _difficultyColor(palette).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      l10n.translate(challenge.difficulty.locKey),
                      style: t.labelS.copyWith(
                        color: _difficultyColor(palette),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  Icon(Icons.group_outlined,
                      size: 14.r, color: palette.textTertiary),
                  SizedBox(width: 4.w),
                  Text(
                    '${challenge.participantIds.length}',
                    style: t.labelS.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600),
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
