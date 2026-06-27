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

    return AnimatedBuilder(
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
