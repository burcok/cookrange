import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';

class GlassRefresher extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double refreshThreshold;
  final double topPadding; // To adjust for different headers

  const GlassRefresher({
    super.key,
    required this.onRefresh,
    required this.child,
    this.refreshThreshold = 100.0,
    this.topPadding = 100.0,
  });

  @override
  State<GlassRefresher> createState() => _GlassRefresherState();
}

class _GlassRefresherState extends State<GlassRefresher>
    with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  final ValueNotifier<double> _pullDistanceNotifier =
      ValueNotifier<double>(0.0);
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _pullDistanceNotifier.dispose();
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        final rawPull = notification.metrics.pixels.abs();
        double dampenedPull;
        if (rawPull <= widget.refreshThreshold) {
          dampenedPull = rawPull;
        } else {
          dampenedPull = widget.refreshThreshold +
              (math.log(1 + (rawPull - widget.refreshThreshold) / 100) * 50);
        }
        _pullDistanceNotifier.value = dampenedPull;
      } else if (_pullDistanceNotifier.value != 0) {
        _pullDistanceNotifier.value = 0;
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullDistanceNotifier.value >= widget.refreshThreshold) {
        _startRefresh();
      } else {
        _pullDistanceNotifier.value = 0;
      }
    }
  }

  Future<void> _startRefresh() async {
    setState(() => _isRefreshing = true);
    _pullDistanceNotifier.value = widget.refreshThreshold;
    _refreshController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pullDistanceNotifier.value = 0;
        });
        _refreshController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildIndicator(),
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _handleScrollNotification(notification);
            return false;
          },
          child: widget.child,
        ),
      ],
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      top: widget.topPadding,
      left: 0,
      right: 0,
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: _pullDistanceNotifier,
          builder: (context, pullDistance, child) {
            final double progress =
                (pullDistance / widget.refreshThreshold).clamp(0.0, 1.0);
            final double opacity = progress.clamp(0.0, 1.0);
            final double scale = 0.5 + (progress * 0.5);

            return Opacity(
              opacity: opacity,
              child: AnimatedBuilder(
                animation: _refreshController,
                builder: (context, child) {
                  final pulse = _isRefreshing
                      ? (math.sin(_refreshController.value * math.pi * 2) *
                          0.05)
                      : 0.0;
                  final currentScale = scale + pulse;
                  final rotation = _isRefreshing
                      ? _refreshController.value * 2 * math.pi
                      : progress * math.pi;

                  return Container(
                    width: 48,
                    height: 48,
                    transform: Matrix4.identity()..scale(currentScale),
                    transformAlignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(48, 48),
                          painter: _RefreshRingPainter(
                            progress: _isRefreshing ? 0.3 : progress,
                            rotation: rotation,
                            color: context.watch<ThemeProvider>().primaryColor,
                          ),
                        ),
                        Transform.rotate(
                          angle: rotation,
                          child: Icon(
                            Icons.refresh_rounded,
                            color: context.watch<ThemeProvider>().primaryColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RefreshRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final Color color;

  _RefreshRingPainter({
    required this.progress,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + rotation,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RefreshRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.rotation != rotation;
  }
}
