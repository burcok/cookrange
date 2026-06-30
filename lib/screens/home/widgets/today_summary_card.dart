import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';
import '../../../core/localization/app_localizations.dart';

/// "Today at a Glance" glassmorphic summary card for the home screen.
///
/// Shows calories, streak, water intake, and next meal in a 2x2 stat grid
/// inside a frosted-glass surface with a brand gradient accent bar.
///
/// i18n: home.today_summary_title ('Today')
class TodaySummaryCard extends StatelessWidget {
  /// Calories consumed today.
  final int calorieConsumed;

  /// Daily calorie target.
  final int calorieTarget;

  /// Current streak in days.
  final int streak;

  /// Water consumed today in ml.
  final int waterMl;

  /// Daily water target in ml.
  final int waterTargetMl;

  /// Name of the next scheduled meal. Null when all meals are done.
  final String? nextMealName;

  /// Display time of the next meal, e.g. "12:30".
  final String? nextMealTime;

  const TodaySummaryCard({
    super.key,
    required this.calorieConsumed,
    required this.calorieTarget,
    required this.streak,
    required this.waterMl,
    required this.waterTargetMl,
    this.nextMealName,
    this.nextMealTime,
  });

  // Clamp a ratio to [0.0, 1.0] — guard against zero targets.
  double _ratio(int consumed, int target) {
    if (target <= 0) return 0.0;
    return (consumed / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final txt = AppText.of(context);

    return RepaintBoundary(
      child: _GlowBloom(
        color: AppPalette.brand,
        child: AppGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Brand gradient header bar (4px) ──────────────────────────
              const _GradientBar(),

              // ── Card header row ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg.w,
                  AppSpacing.md.h,
                  AppSpacing.lg.w,
                  AppSpacing.xs.h,
                ),
                child: Text(
                  AppLocalizations.of(context)
                      .translate('home.today_summary_title'),
                  style: txt.titleM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // ── 2×2 stat grid ─────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: AppSpacing.xs.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Calories | Streak
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _CalorieCell(
                              consumed: calorieConsumed,
                              target: calorieTarget,
                              ratio: _ratio(calorieConsumed, calorieTarget),
                              palette: palette,
                              txt: txt,
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Expanded(
                            child: _StreakCell(
                              streak: streak,
                              palette: palette,
                              txt: txt,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs.h),
                    // Row 2: Water | Next Meal
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _WaterCell(
                              waterMl: waterMl,
                              waterTargetMl: waterTargetMl,
                              ratio: _ratio(waterMl, waterTargetMl),
                              palette: palette,
                              txt: txt,
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Expanded(
                            child: _NextMealCell(
                              nextMealName: nextMealName,
                              nextMealTime: nextMealTime,
                              palette: palette,
                              txt: txt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand gradient header bar
// ─────────────────────────────────────────────────────────────────────────────

class _GradientBar extends StatelessWidget {
  const _GradientBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4.h,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared cell container
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final Widget child;
  final AppPalette palette;

  const _StatCell({
    required this.child,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// (a) Calories cell — mini ring + number
// ─────────────────────────────────────────────────────────────────────────────

class _CalorieCell extends StatelessWidget {
  final int consumed;
  final int target;
  final double ratio;
  final AppPalette palette;
  final AppText txt;

  const _CalorieCell({
    required this.consumed,
    required this.target,
    required this.ratio,
    required this.palette,
    required this.txt,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCell(
      palette: palette,
      child: Row(
        children: [
          // Mini calorie ring
          SizedBox(
            width: 44.r,
            height: 44.r,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track ring
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4.r,
                  backgroundColor: palette.calories.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    palette.calories.withValues(alpha: 0.15),
                  ),
                  strokeCap: StrokeCap.round,
                ),
                // Progress ring
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 4.r,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.calories),
                  strokeCap: StrokeCap.round,
                ),
                // Flame emoji center
                Text(
                  '🔥',
                  style: TextStyle(fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.xs.w),
          // Numbers
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$consumed',
                  style: txt.titleL.copyWith(
                    color: palette.calories,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '/ $target kcal',
                  style: txt.labelS.copyWith(color: palette.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// (b) Streak cell — flame icon + count + label
// ─────────────────────────────────────────────────────────────────────────────

class _StreakCell extends StatelessWidget {
  final int streak;
  final AppPalette palette;
  final AppText txt;

  const _StreakCell({
    required this.streak,
    required this.palette,
    required this.txt,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCell(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon row
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: palette.warning,
                size: AppSize.iconMd.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Text(
                '$streak',
                style: txt.headlineS.copyWith(
                  color: palette.warning,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xxs.h),
          Text(
            'days',
            style: txt.labelS.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// (c) Water cell — icon + ml display + linear progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _WaterCell extends StatelessWidget {
  final int waterMl;
  final int waterTargetMl;
  final double ratio;
  final AppPalette palette;
  final AppText txt;

  const _WaterCell({
    required this.waterMl,
    required this.waterTargetMl,
    required this.ratio,
    required this.palette,
    required this.txt,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCell(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + value row
          Row(
            children: [
              Icon(
                Icons.water_drop_rounded,
                color: palette.info,
                size: AppSize.iconMd.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${waterMl}ml',
                      style: txt.titleM.copyWith(
                        color: palette.info,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '/ ${waterTargetMl}ml',
                      style: txt.labelS.copyWith(color: palette.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs.h),
          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5.h,
              backgroundColor: palette.info.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(palette.info),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// (d) Next Meal cell — icon + name + time chip (or "all done" state)
// ─────────────────────────────────────────────────────────────────────────────

class _NextMealCell extends StatelessWidget {
  final String? nextMealName;
  final String? nextMealTime;
  final AppPalette palette;
  final AppText txt;

  const _NextMealCell({
    required this.nextMealName,
    required this.nextMealTime,
    required this.palette,
    required this.txt,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeal = nextMealName != null && nextMealName!.isNotEmpty;

    return _StatCell(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                hasMeal
                    ? Icons.restaurant_menu_rounded
                    : Icons.check_circle_rounded,
                color: palette.success,
                size: AppSize.iconMd.r,
              ),
              SizedBox(width: AppSpacing.xxs.w),
              Expanded(
                child: Text(
                  hasMeal ? nextMealName! : 'All meals done',
                  style: txt.titleM.copyWith(
                    color: hasMeal ? palette.textPrimary : palette.success,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hasMeal && nextMealTime != null) ...[
            SizedBox(height: AppSpacing.xxs.h),
            // Time chip
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: 3.h,
              ),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs.r),
              ),
              child: Text(
                nextMealTime!,
                style: txt.labelS.copyWith(
                  color: palette.success,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ] else if (!hasMeal) ...[
            SizedBox(height: AppSpacing.xxs.h),
            Text(
              '✓ Great work today',
              style: txt.labelS.copyWith(color: palette.success),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glow bloom — subtle brand-colored ambient glow behind the card
// ─────────────────────────────────────────────────────────────────────────────

class _GlowBloom extends StatelessWidget {
  final Color color;
  final Widget child;

  const _GlowBloom({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glow layer: blurred, brand-colored blob behind the card.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 40.r,
                    spreadRadius: 8.r,
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
