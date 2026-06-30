import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_gradients.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_dimensions.dart';

/// Cookrange Design System — animated gradient calorie ring (bold hero).
///
/// Sweep-gradient progress arc that animates to [progress] on build/update,
/// with a big consumed-calories readout in the center. The signature element of
/// the "Sunset Energy" direction.
class AppCalorieRing extends StatefulWidget {
  final double consumed;
  final double target;
  final double size;
  final double strokeWidth;

  /// Optional label under the number (e.g. "of 2,000 kcal").
  final String? caption;

  /// Overrides the VoiceOver / TalkBack announcement. If null, a default
  /// "{consumed} of {target} kilocalories consumed" label is generated.
  final String? semanticLabel;

  const AppCalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 200,
    this.strokeWidth = 16,
    this.caption,
    this.semanticLabel,
  });

  @override
  State<AppCalorieRing> createState() => _AppCalorieRingState();
}

class _AppCalorieRingState extends State<AppCalorieRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late Animation<double> _anim;
  double _from = 0;

  double get _progress => widget.target <= 0
      ? 0
      : (widget.consumed / widget.target).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _anim = Tween<double>(begin: 0, end: _progress).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standard),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AppCalorieRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed ||
        oldWidget.target != widget.target) {
      _from = _anim.value;
      _anim = Tween<double>(begin: _from, end: _progress).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.standard),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);
    final dim = widget.size.r;

    final pct = (_progress * 100).round();
    final label = widget.semanticLabel ??
        '${widget.consumed.round()} of ${widget.target.round()} kilocalories consumed, $pct percent';

    return Semantics(
      label: label,
      value: '$pct%',
      child: SizedBox(
        width: dim,
        height: dim,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final consumedNow =
                (widget.consumed * _animFractionForReadout()).round();
            return ExcludeSemantics(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _anim.value,
                  trackColor: palette.surfaceVariant,
                  gradient: AppGradients.ring(primary),
                  strokeWidth: widget.strokeWidth.r,
                  glowColor: primary.withValues(alpha: 0.35),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        consumedNow.toString(),
                        style: t.displayM.copyWith(height: 1),
                      ),
                      Text('kcal', style: t.labelM),
                      if (widget.caption != null) ...[
                        SizedBox(height: AppSpacing.xxs.h),
                        Text(widget.caption!, style: t.labelS),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The center number counts up in step with the arc.
  double _animFractionForReadout() {
    final p = _progress;
    if (p <= 0) return 0;
    return (_anim.value / p).clamp(0.0, 1.0);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Gradient gradient;
  final double strokeWidth;
  final Color glowColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.gradient,
    required this.strokeWidth,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Soft glow under the arc.
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, startAngle, sweep, false, glowPaint);

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
