import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_post.dart';
import '../../../core/services/community_service.dart';
import '../../../core/utils/profile_navigation.dart';

/// Glassmorphic "Weekly Highlights" card shown at the top of the Global feed.
///
/// Displays the top-liked post of the past 7 days and the current streak
/// leader side-by-side. Both subsections are tappable and navigate to the
/// relevant user profile. The card hides itself (SizedBox.shrink) when no
/// data is available.
///
/// Loading state: branded AppShimmer skeleton.
/// i18n keys: community.weekly_highlights_title, community.top_post_this_week,
///            community.top_streak_label, community.highlights_likes_count,
///            community.highlights_days.
class WeeklyHighlightsCard extends StatefulWidget {
  const WeeklyHighlightsCard({super.key});

  @override
  State<WeeklyHighlightsCard> createState() => _WeeklyHighlightsCardState();
}

class _WeeklyHighlightsCardState extends State<WeeklyHighlightsCard> {
  final CommunityService _service = CommunityService();

  // null → loading; special sentinel handled via _loaded flag
  CommunityPost? _topPost;
  Map<String, dynamic>? _streakUser;
  bool _loaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getTopPostThisWeek(),
        _service.getTopStreakUserThisWeek(),
      ]);
      if (!mounted) return;
      setState(() {
        _topPost = results[0] as CommunityPost?;
        _streakUser = results[1] as Map<String, dynamic>?;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely on error or when both data sources are empty after load
    if (_hasError) return const SizedBox.shrink();
    if (_loaded && _topPost == null && _streakUser == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: _loaded ? _buildCard(context) : _buildSkeleton(context),
    );
  }

  // ─── Loaded card ────────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context) {
    final palette = AppPalette.of(context);
    final txt = AppText.of(context);
    final appLoc = AppLocalizations.of(context);

    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 2px brand gradient header bar ──────────────────────────────────
          const _GradientBar(),

          // ── Header row ─────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              AppSpacing.sm.h,
              AppSpacing.md.w,
              AppSpacing.xs.h,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: palette.warning,
                  size: AppSize.iconMd.r,
                ),
                SizedBox(width: AppSpacing.xs.w),
                Text(
                  appLoc.translate('community.weekly_highlights_title'),
                  style: txt.titleM.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Two subsections ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm.w,
              AppSpacing.xxs.h,
              AppSpacing.sm.w,
              AppSpacing.sm.h,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_topPost != null)
                    Expanded(
                      child: _TopPostCell(
                        post: _topPost!,
                        palette: palette,
                        txt: txt,
                        appLoc: appLoc,
                      ),
                    ),
                  if (_topPost != null && _streakUser != null)
                    SizedBox(width: AppSpacing.xs.w),
                  if (_streakUser != null)
                    Expanded(
                      child: _StreakLeaderCell(
                        data: _streakUser!,
                        palette: palette,
                        txt: txt,
                        appLoc: appLoc,
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

  // ─── Loading skeleton ───────────────────────────────────────────────────────

  Widget _buildSkeleton(BuildContext context) {
    return AppShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
        ),
        padding: EdgeInsets.all(AppSpacing.md.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBox(width: 160.w, height: 14),
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                const Expanded(
                  child: AppSkeletonBox(
                    width: double.infinity,
                    height: 72,
                    radius: AppRadius.md,
                  ),
                ),
                SizedBox(width: AppSpacing.xs.w),
                const Expanded(
                  child: AppSkeletonBox(
                    width: double.infinity,
                    height: 72,
                    radius: AppRadius.md,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gradient bar (same as TodaySummaryCard) ──────────────────────────────────

class _GradientBar extends StatelessWidget {
  const _GradientBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.h,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.card),
          topRight: Radius.circular(AppRadius.card),
        ),
        gradient: LinearGradient(
          colors: [
            AppPalette.brand,
            AppPalette.sunsetA,
            AppPalette.energyLight,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─── Shared cell container ─────────────────────────────────────────────────────

class _HighlightCell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final AppPalette palette;

  const _HighlightCell({
    required this.child,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: EdgeInsets.all(AppSpacing.sm.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
          color: palette.glassStroke.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: child,
    );

    if (onTap == null) return cell;

    return GestureDetector(
      onTap: onTap,
      child: cell,
    );
  }
}

// ─── (a) Top Post subsection ────────────────────────────────────────────────────

class _TopPostCell extends StatelessWidget {
  final CommunityPost post;
  final AppPalette palette;
  final AppText txt;
  final AppLocalizations appLoc;

  const _TopPostCell({
    required this.post,
    required this.palette,
    required this.txt,
    required this.appLoc,
  });

  @override
  Widget build(BuildContext context) {
    final preview = post.content.length > 60
        ? '${post.content.substring(0, 60)}…'
        : post.content;

    return _HighlightCell(
      palette: palette,
      onTap: () => openUserProfile(context, userId: post.author.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row
          Row(
            children: [
              Icon(
                Icons.thumb_up_rounded,
                color: palette.error,
                size: AppSize.iconSm.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Text(
                  appLoc.translate('community.top_post_this_week'),
                  style: txt.labelS.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xs.h),

          // Author row
          Row(
            children: [
              AppInitialsAvatar(
                photoUrl: post.author.avatarUrl.isNotEmpty
                    ? post.author.avatarUrl
                    : null,
                name: post.author.name,
                size: 22.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Text(
                  post.author.name,
                  style: txt.labelS.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xxs.h),

          // Content preview
          Text(
            preview,
            style: txt.labelS.copyWith(
              color: palette.textSecondary,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: AppSpacing.xs.h),

          // Like count chip
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs.w,
              vertical: 3.h,
            ),
            decoration: BoxDecoration(
              color: palette.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: palette.error,
                  size: 10.r,
                ),
                SizedBox(width: 3.w),
                Text(
                  '${post.likesCount}',
                  style: txt.labelS.copyWith(
                    color: palette.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── (b) Streak Leader subsection ──────────────────────────────────────────────

class _StreakLeaderCell extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppPalette palette;
  final AppText txt;
  final AppLocalizations appLoc;

  const _StreakLeaderCell({
    required this.data,
    required this.palette,
    required this.txt,
    required this.appLoc,
  });

  @override
  Widget build(BuildContext context) {
    final uid = data['uid'] as String? ?? '';
    final name = data['displayName'] as String? ?? '';
    final photoURL = data['photoURL'] as String? ?? '';
    final streak = data['streak'] as int? ?? 0;

    return _HighlightCell(
      palette: palette,
      onTap: uid.isNotEmpty
          ? () => openUserProfile(context, userId: uid)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: palette.warning,
                size: AppSize.iconSm.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Text(
                  appLoc.translate('community.top_streak_label'),
                  style: txt.labelS.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xs.h),

          // Avatar + name row
          Row(
            children: [
              AppInitialsAvatar(
                photoUrl: photoURL.isNotEmpty ? photoURL : null,
                name: name,
                size: 22.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Text(
                  name,
                  style: txt.labelS.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xs.h),

          // Streak number (big, warning color)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$streak',
                style: txt.headlineS.copyWith(
                  color: palette.warning,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text(
                  appLoc.translate('community.highlights_days'),
                  style: txt.labelS.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
