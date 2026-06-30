import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Cookrange Design System — the "Sunset Energy" bold gradient kit.
///
/// Centralizes every brand gradient so the bold direction stays consistent.
/// Pair the warm [brand] gradient with the cool [AppPalette.energy] accent.
class AppGradients {
  AppGradients._();

  /// Primary brand gradient (warm sunset). Pass the live primary so it honors
  /// the user's selected brand color while keeping the sunset blend.
  static LinearGradient brand(Color primary) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.sunsetA,
          primary,
          AppPalette.sunsetC,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

  /// Subtle brand wash for hero card backgrounds.
  static LinearGradient brandSoft(Color primary, {bool dark = false}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: dark ? 0.22 : 0.14),
          AppPalette.sunsetC.withValues(alpha: dark ? 0.14 : 0.08),
        ],
      );

  /// Energy accent gradient (cool) — progress rings, fitness highlights.
  static LinearGradient energy(AppPalette p) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.energy, p.energy.withValues(alpha: 0.65)],
      );

  /// Sweep gradient for the calorie ring stroke (warm, rotating feel).
  static SweepGradient ring(Color primary) => SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [
          AppPalette.sunsetA,
          primary,
          AppPalette.sunsetC,
          AppPalette.sunsetA,
        ],
        stops: const [0.0, 0.45, 0.8, 1.0],
      );

  /// Two soft radial blobs for an ambient mesh-glow background.
  /// Stack behind content with low opacity for depth (bold direction).
  static List<Widget> meshGlow(AppPalette p, Color primary) => [
        Positioned(
          top: -80,
          right: -60,
          child:
              _Blob(color: primary, size: 280, opacity: p.isDark ? 0.22 : 0.16),
        ),
        Positioned(
          bottom: -100,
          left: -80,
          child: _Blob(
              color: p.energy, size: 320, opacity: p.isDark ? 0.18 : 0.12),
        ),
      ];
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Blob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
