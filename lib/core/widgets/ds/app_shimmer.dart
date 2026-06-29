import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';

/// Branded skeleton loader — a self-contained animated shimmer (no package dep).
///
/// Wrap any layout of [AppSkeletonBox]es in [AppShimmer] to get a smooth,
/// theme-aware loading placeholder. Replaces bare `CircularProgressIndicator`
/// on content surfaces (Rule R7).
///
/// ```dart
/// AppShimmer(
///   child: Column(children: [
///     AppSkeletonBox(width: 200, height: 20),
///     SizedBox(height: 12),
///     AppSkeletonBox(width: double.infinity, height: 120, radius: AppRadius.card),
///   ]),
/// )
/// ```
class AppShimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const AppShimmer({super.key, required this.child, this.enabled = true});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final palette = AppPalette.of(context);

    return ExcludeSemantics(
      child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (_controller.value * 2 - 1) * bounds.width;
            return LinearGradient(
              colors: [
                palette.shimmerBase,
                palette.shimmerHighlight,
                palette.shimmerBase,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// A single skeleton block. Must live inside an [AppShimmer].
class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final bool circle;

  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.margin,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: circle ? height.r : width?.r,
      height: height.r,
      margin: margin,
      decoration: BoxDecoration(
        color: palette.shimmerBase,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius.r),
      ),
    );
  }
}

/// Meal-card skeleton — matches the image-left + macro-chip-row layout used in
/// the home meal plan section.
class AppSkeletonMealCard extends StatelessWidget {
  final int itemCount;

  const AppSkeletonMealCard({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(itemCount, (_) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md.h),
            child: Container(
              height: 110.h,
              decoration: BoxDecoration(
                color: AppPalette.of(context).surface,
                borderRadius: BorderRadius.circular(AppRadius.card.r),
              ),
              child: Row(
                children: [
                  // Image placeholder
                  AppSkeletonBox(
                    width: 100.w,
                    height: 110.h,
                    radius: AppRadius.card,
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonBox(width: 56.w, height: 10),
                          SizedBox(height: AppSpacing.xs.h),
                          const AppSkeletonBox(width: double.infinity, height: 15),
                          SizedBox(height: AppSpacing.xs.h),
                          AppSkeletonBox(width: 140.w, height: 13),
                          const Spacer(),
                          Row(
                            children: [
                              AppSkeletonBox(width: 52.w, height: 20, radius: 20),
                              SizedBox(width: AppSpacing.xs.w),
                              AppSkeletonBox(width: 52.w, height: 20, radius: 20),
                              SizedBox(width: AppSpacing.xs.w),
                              AppSkeletonBox(width: 52.w, height: 20, radius: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Stat-grid skeleton — matches 2-column admin/dashboard metric cards
/// (number + label stacked inside a card).
class AppSkeletonStatGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const AppSkeletonStatGrid({
    super.key,
    this.itemCount = 4,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.sm.w,
          mainAxisSpacing: AppSpacing.sm.h,
          childAspectRatio: 1.5,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) {
          return Container(
            padding: EdgeInsets.all(AppSpacing.md.r),
            decoration: BoxDecoration(
              color: AppPalette.of(context).surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSkeletonBox(width: 64.w, height: 28),
                SizedBox(height: AppSpacing.xs.h),
                AppSkeletonBox(width: 80.w, height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bar-chart skeleton — mimics a 5-bar chart with varying heights and axis
/// label placeholders. Use as a branded loading state for chart sections
/// (replaces bare [CircularProgressIndicator] on analytics surfaces per R7).
///
/// ```dart
/// AppSkeletonChart()                          // default 120.h
/// AppSkeletonChart(maxHeight: 160)            // taller chart area
/// ```
class AppSkeletonChart extends StatelessWidget {
  /// Maximum chart height in design-px (applied via [.h] screenutil extension).
  final double maxHeight;

  const AppSkeletonChart({super.key, this.maxHeight = 120});

  static const List<double> _ratios = [0.4, 0.7, 0.55, 0.9, 0.65];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_ratios.length, (i) {
            final barH = maxHeight.h * _ratios[i];
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSkeletonBox(
                    width: 28,
                    height: barH / 1.h, // convert back to design-px for Box
                    radius: 6,
                  ),
                  SizedBox(height: 6.h),
                  const AppSkeletonBox(width: 28, height: 8),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Ready-made skeleton for a list of cards (common loading surface).
class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const AppSkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenH,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        padding: padding.add(EdgeInsets.only(top: AppSpacing.sm.h)),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
        itemBuilder: (_, __) => Row(
          children: [
            const AppSkeletonBox(height: AppSize.avatarMd, circle: true),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppSkeletonBox(width: 160, height: 14),
                  SizedBox(height: AppSpacing.xs.h),
                  const AppSkeletonBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
