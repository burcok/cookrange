import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/food_log_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/food_log_repository.dart';
import '../../core/services/nutrition_analytics_service.dart';
import '../../core/utils/calorie_calculator.dart';

class NutritionAnalyticsScreen extends StatefulWidget {
  const NutritionAnalyticsScreen({super.key});

  @override
  State<NutritionAnalyticsScreen> createState() =>
      _NutritionAnalyticsScreenState();
}

class _NutritionAnalyticsScreenState extends State<NutritionAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final FoodLogRepository _repo = FoodLogRepository();
  final NutritionAnalyticsService _analyticsService =
      NutritionAnalyticsService();

  WeeklyNutritionSummary? _summary;
  bool _loading = true;
  double _targetCalories = 2000;

  late final AnimationController _animController;
  late final Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final profile = user.profile;
    final bmr = CalorieCalculator.calculateBMR(
      weight: profile.weightKg?.toDouble() ?? 70,
      height: profile.heightCm?.toDouble() ?? 170,
      age: profile.age ?? 30,
      gender: profile.gender ?? 'Male',
    );
    final tdee = CalorieCalculator.calculateTDEE(
      bmr: bmr,
      activityLevel: profile.activityLevel,
    );
    _targetCalories = CalorieCalculator.adjustTDEEForGoal(
      tdee: tdee,
      primaryGoal: profile.primaryGoals.isNotEmpty
          ? profile.primaryGoals.first
          : 'maintain_weight',
    );

    final logs = await _repo.getWeeklyLogs(user.uid);
    if (!mounted) return;

    final summary =
        _analyticsService.computeWeeklySummary(logs, _targetCalories);
    setState(() {
      _summary = summary;
      _loading = false;
    });
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20.sp,
              color: isDark ? Colors.white : const Color(0xFF2E3A59)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('analytics.title'),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2E3A59),
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null || _summary!.loggedDays == 0
              ? _buildEmptyState(l10n, isDark)
              : _buildContent(l10n, isDark, primary),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 72.sp,
                color: isDark
                    ? Colors.white30
                    : const Color(0xFF2E3A59).withAlpha(80)),
            SizedBox(height: 16.h),
            Text(
              l10n.translate('analytics.no_data'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2E3A59),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              l10n.translate('analytics.no_data_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark
                    ? Colors.white54
                    : const Color(0xFF2E3A59).withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      AppLocalizations l10n, bool isDark, Color primary) {
    final summary = _summary!;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('analytics.subtitle'),
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark
                  ? Colors.white54
                  : const Color(0xFF2E3A59).withAlpha(140),
            ),
          ),
          SizedBox(height: 20.h),
          _buildConsistencyCard(l10n, isDark, primary, summary),
          SizedBox(height: 16.h),
          _buildStatCards(l10n, isDark, primary, summary),
          SizedBox(height: 16.h),
          _buildBarChart(l10n, isDark, primary, summary),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildConsistencyCard(AppLocalizations l10n, bool isDark, Color primary,
      WeeklyNutritionSummary summary) {
    final score = summary.consistencyScore;
    final scoreColor = score >= 70
        ? const Color(0xFF22C55E)
        : score >= 40
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final scoreLabel = score >= 70
        ? l10n.translate('analytics.score_great')
        : score >= 40
            ? l10n.translate('analytics.score_good')
            : l10n.translate('analytics.score_needs_work');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) => SizedBox(
              width: 72.w,
              height: 72.w,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  progress: _barAnim.value * score / 100,
                  color: scoreColor,
                  backgroundColor: isDark
                      ? Colors.white12
                      : const Color(0xFFE5E7EB),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('analytics.consistency_score'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF2E3A59).withAlpha(140),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  scoreLabel,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  l10n
                      .translate('analytics.logged_days')
                      .replaceAll('{count}', '${summary.loggedDays}'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF2E3A59).withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(AppLocalizations l10n, bool isDark, Color primary,
      WeeklyNutritionSummary summary) {
    final kcal = l10n.translate('analytics.kcal');
    final g = l10n.translate('analytics.g');
    final items = [
      (l10n.translate('analytics.avg_calories'),
          '${summary.avgCalories.round()} $kcal', Icons.local_fire_department,
          primary),
      (l10n.translate('analytics.avg_protein'),
          '${summary.avgProtein.round()} $g', Icons.fitness_center,
          const Color(0xFF3B82F6)),
      (l10n.translate('analytics.avg_carbs'),
          '${summary.avgCarbs.round()} $g', Icons.grain,
          const Color(0xFFF59E0B)),
      (l10n.translate('analytics.avg_fat'),
          '${summary.avgFat.round()} $g', Icons.water_drop,
          const Color(0xFF8B5CF6)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.6,
      children: items.map((item) {
        return Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2333) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$3, size: 20.sp, color: item.$4),
              SizedBox(height: 6.h),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2E3A59),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.$1,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFF2E3A59).withAlpha(120),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(AppLocalizations l10n, bool isDark, Color primary,
      WeeklyNutritionSummary summary) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('analytics.weekly_chart'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2E3A59),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Container(
                width: 14.w,
                height: 2.h,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF2E3A59).withAlpha(80),
                margin: EdgeInsets.only(right: 6.w),
              ),
              Text(
                '${l10n.translate('analytics.target_line')}: ${_targetCalories.round()} ${l10n.translate('analytics.kcal')}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFF2E3A59).withAlpha(100),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) => SizedBox(
              height: 160.h,
              child: CustomPaint(
                size: Size(double.infinity, 160.h),
                painter: _BarChartPainter(
                  days: summary.days,
                  targetCalories: _targetCalories,
                  progress: _barAnim.value,
                  primaryColor: primary,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const stroke = 6.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _BarChartPainter extends CustomPainter {
  final List<DailyNutrition> days;
  final double targetCalories;
  final double progress;
  final Color primaryColor;
  final bool isDark;

  const _BarChartPainter({
    required this.days,
    required this.targetCalories,
    required this.progress,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    const labelHeight = 24.0;
    final chartHeight = size.height - labelHeight;
    final barWidth = (size.width / days.length) * 0.55;
    final gap = (size.width / days.length) * 0.45;

    final maxCal =
        days.map((d) => d.calories).fold(0.0, math.max).clamp(1.0, double.infinity);
    final scale = chartHeight / (maxCal * 1.15);

    // Target line
    if (targetCalories > 0) {
      final ty = chartHeight - targetCalories * scale;
      if (ty >= 0) {
        final linePaint = Paint()
          ..color = (isDark ? Colors.white : const Color(0xFF2E3A59))
              .withAlpha(60)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final path = Path();
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        double x = 0;
        while (x < size.width) {
          path.moveTo(x, ty);
          path.lineTo(math.min(x + dashWidth, size.width), ty);
          x += dashWidth + dashSpace;
        }
        canvas.drawPath(path, linePaint);
      }
    }

    // Bars
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final x = i * (barWidth + gap) + gap / 2;
      final barH = day.hasLogs ? (day.calories * scale * progress) : 0.0;
      final top = chartHeight - barH;

      final barColor = day.hasLogs
          ? primaryColor
          : (isDark ? Colors.white12 : const Color(0xFFE5E7EB));

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barWidth, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      canvas.drawRRect(rRect, Paint()..color = barColor);

      // Day label (Mon, Tue …)
      final dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
      final dayOfWeek = DateTime.tryParse(day.date)?.weekday ?? 1;
      final label = dayNames[(dayOfWeek - 1) % 7];

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: day.hasLogs
                ? (isDark ? Colors.white70 : const Color(0xFF2E3A59))
                : (isDark ? Colors.white30 : const Color(0xFF2E3A59).withAlpha(80)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x + barWidth / 2 - tp.width / 2, chartHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.progress != progress || old.days != days;
}
