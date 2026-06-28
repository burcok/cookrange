import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_dimensions.dart';

/// A card widget that can be captured and shared as a PNG image.
///
/// Usage:
/// ```dart
/// final key = GlobalKey();
/// ShareableFitnessCard(repaintKey: key, ...);
/// // then share:
/// await ShareableFitnessCard.capture(key);
/// ```
class ShareableFitnessCard extends StatelessWidget {
  final GlobalKey repaintKey;
  final double consumedCalories;
  final double targetCalories;
  final int streakDays;
  final String? userName;
  final double protein;
  final double carbs;
  final double fat;

  const ShareableFitnessCard({
    super.key,
    required this.repaintKey,
    required this.consumedCalories,
    required this.targetCalories,
    required this.streakDays,
    this.userName,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  static Future<void> capture(
    GlobalKey key, {
    String subject = 'My Cookrange Progress',
    String text = 'Track your nutrition with AI on Cookrange! #Cookrange',
  }) async {
    try {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cookrange_progress.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
      );
    } catch (e) {
      debugPrint('ShareableFitnessCard.capture error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (pct * 100).round();

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card * 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topRow(context),
            const SizedBox(height: AppSpacing.lg),
            _calorieRow(context, pct, pctInt),
            const SizedBox(height: AppSpacing.md),
            _macroRow(context),
            const SizedBox(height: AppSpacing.lg),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _topRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName != null ? "Hey, ${userName!.split(' ').first}!" : "Today's Progress",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
            const Text(
              "Nutrition Score",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        if (streakDays > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF97300).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFF97300).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🔥", style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  "$streakDays days",
                  style: const TextStyle(
                    color: Color(0xFFF97300),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _calorieRow(BuildContext context, double pct, int pctInt) {
    return Row(
      children: [
        // Progress ring (simple arc via CustomPaint)
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            painter: _SimpleRingPainter(progress: pct),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$pctInt%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Text(
                    "done",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${consumedCalories.round()}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                height: 1,
              ),
            ),
            Text(
              "of ${targetCalories.round()} kcal",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _macroRow(BuildContext context) {
    return Row(
      children: [
        _macroChip("Protein", "${protein.round()}g", const Color(0xFF4ECDC4)),
        const SizedBox(width: AppSpacing.sm),
        _macroChip("Carbs", "${carbs.round()}g", const Color(0xFFFFBE0B)),
        const SizedBox(width: AppSpacing.sm),
        _macroChip("Fat", "${fat.round()}g", const Color(0xFFFF6B6B)),
      ],
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontFamily: 'Poppins'),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "🍳 Cookrange",
          style: TextStyle(
            color: Color(0xFFF97300),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          "AI-Powered Nutrition",
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _SimpleRingPainter extends CustomPainter {
  final double progress;
  const _SimpleRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 8.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Arc
    canvas.drawArc(
      rect,
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF8A3D), Color(0xFFF97300), Color(0xFFFF4E50)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SimpleRingPainter old) => old.progress != progress;
}
