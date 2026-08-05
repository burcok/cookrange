import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// Prefixed: intl also exports a TextDirection, which collides with
// material's (used below by TextPainter).
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/food_log_repository.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/services/food_log_service.dart';
import '../../core/services/nutrition_analytics_service.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/widgets/ds/ds.dart';

class NutritionAnalyticsScreen extends StatefulWidget {
  /// When false, renders just the analytics body (no Scaffold/AppBar) so it can
  /// be embedded as a tab inside the Foods & Nutrition hub.
  final bool showChrome;

  const NutritionAnalyticsScreen({super.key, this.showChrome = true});

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

  // Faz 5 §5.4 — Entitlements.advancedTrends: the free weekly summary above
  // stays exactly as-is; this is a NEW, additive 30-day view (nothing free
  // users had before is removed). Null until first requested; `_loadingTrend`
  // covers the fetch; `_trendUnlocked` records that the gate already passed
  // this screen visit so re-expanding doesn't re-show the paywall sheet.
  WeeklyNutritionSummary? _trendSummary;
  bool _loadingTrend = false;
  bool _trendUnlocked = false;
  bool _trendExpanded = false;

  late final AnimationController _animController;
  late final Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _barAnim =
        CurvedAnimation(parent: _animController, curve: AppMotion.decelerate);
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

    // Faz 5 §5.4 — Entitlements.nutritionAnalytics is `true` for every tier
    // ("free feature" per that getter's own doc comment) — this call never
    // blocks anyone today. It's the single, correct entry point for this
    // screen's core feature so the getter isn't dead scaffolding, and so a
    // future change to that business rule has exactly one place to take
    // effect, matching FeatureGateService's documented "single entry point"
    // contract (see feature_gate_service.dart).
    if (!await FeatureGateService()
        .check(context, (e) => e.nutritionAnalytics)) {
      return;
    }
    if (!mounted) return;

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
    unawaited(_animController.forward());
  }

  /// Faz 5 §5.4 — "detaylı analitik" (docs/PREMIUM.md §1 "Full nutrition
  /// analytics history"), gated on Entitlements.advancedTrends. Free users
  /// keep the full weekly summary above unchanged; this is a NEW,
  /// additive 30-day view reusing `NutritionAnalyticsService.
  /// computeWeeklySummary` — that method is generic over whatever date-keyed
  /// log map it's given (see its own body: no assumption of exactly 7
  /// entries), so no new aggregation logic is needed, only a wider fetch
  /// (`FoodLogService.getLogsForDateRange`, the same 30-day call
  /// `AiInsightService.generateFitnessTwin` already uses).
  Future<void> _toggleTrend() async {
    if (_trendExpanded) {
      setState(() => _trendExpanded = false);
      return;
    }
    if (_trendUnlocked && _trendSummary != null) {
      setState(() => _trendExpanded = true);
      return;
    }

    final user = context.read<UserProvider>().user;
    if (user == null) return;
    if (!await FeatureGateService().check(
      context,
      (e) => e.advancedTrends,
      featureName: AppLocalizations.of(context)
          .translate('analytics.trend_paywall_title'),
      featureDescription: AppLocalizations.of(context)
          .translate('analytics.trend_paywall_desc'),
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _loadingTrend = true);
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final logs = await FoodLogService()
          .getLogsForDateRange(user.uid, thirtyDaysAgo, now);
      if (!mounted) return;
      final summary =
          _analyticsService.computeWeeklySummary(logs, _targetCalories);
      setState(() {
        _trendSummary = summary;
        _trendUnlocked = true;
        _trendExpanded = true;
        _loadingTrend = false;
      });
    } catch (e) {
      debugPrint('NutritionAnalyticsScreen._toggleTrend error: $e');
      if (!mounted) return;
      setState(() => _loadingTrend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    final body = _loading
        ? Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: const AppSkeletonChart(maxHeight: 160),
            ),
          )
        : _summary == null || _summary!.loggedDays == 0
            ? _buildEmptyState(l10n, palette, t)
            : _buildContent(l10n, palette, t, primary);

    if (!widget.showChrome) return body;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20.sp, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('analytics.title'),
          style: t.headlineS,
        ),
        centerTitle: false,
      ),
      body: body,
    );
  }

  Widget _buildEmptyState(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 72.sp, color: palette.textTertiary),
            SizedBox(height: AppSpacing.md.h),
            Text(
              l10n.translate('analytics.no_data'),
              style: t.headlineS,
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              l10n.translate('analytics.no_data_subtitle'),
              textAlign: TextAlign.center,
              style: t.bodyM,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      AppLocalizations l10n, AppPalette palette, AppText t, Color primary) {
    final summary = _summary!;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w, vertical: AppSpacing.xs.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('analytics.subtitle'),
            style: t.bodyM,
          ),
          SizedBox(height: AppSpacing.lg.h),
          _buildConsistencyCard(l10n, palette, t, primary, summary),
          SizedBox(height: AppSpacing.md.h),
          _buildStatCards(l10n, palette, t, primary, summary),
          SizedBox(height: AppSpacing.md.h),
          _buildBarChart(l10n, palette, t, primary, summary),
          SizedBox(height: AppSpacing.md.h),
          _buildTrendSection(l10n, palette, t, primary),
          SizedBox(height: AppSpacing.xl.h),
        ],
      ),
    );
  }

  /// Faz 5 §5.4 — premium-exclusive 30-day trend, additive to (never a
  /// replacement for) the free weekly view above. See [_toggleTrend].
  Widget _buildTrendSection(
      AppLocalizations l10n, AppPalette palette, AppText t, Color primary) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: AppElevation.opacityLight),
            blurRadius: AppElevation.blurMd,
            offset: AppElevation.offsetMd,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _loadingTrend ? null : _toggleTrend,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: AppSize.iconSm.sp, color: primary),
                SizedBox(width: AppSpacing.xs.w),
                Expanded(
                  child: Text(
                    l10n.translate('analytics.trend_30day_title'),
                    style: t.titleL,
                  ),
                ),
                if (_loadingTrend)
                  SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary),
                  )
                else
                  Icon(
                    _trendExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: palette.textTertiary,
                  ),
              ],
            ),
          ),
          if (!_trendExpanded)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs.h),
              child: Text(
                l10n.translate('analytics.trend_30day_subtitle'),
                style: t.labelS.copyWith(color: palette.textSecondary),
              ),
            ),
          if (_trendExpanded && _trendSummary != null) ...[
            SizedBox(height: AppSpacing.md.h),
            if (_trendSummary!.loggedDays == 0)
              Text(l10n.translate('analytics.no_data'), style: t.bodyM)
            else
              Row(
                children: [
                  Expanded(
                    child: _TrendStat(
                      label: l10n.translate('analytics.avg_calories'),
                      value:
                          '${_trendSummary!.avgCalories.round()} ${l10n.translate('analytics.kcal')}',
                      t: t,
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: _TrendStat(
                      label: l10n.translate('analytics.consistency_score'),
                      value: '${_trendSummary!.consistencyScore}',
                      t: t,
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: _TrendStat(
                      label:
                          l10n.translate('analytics.trend_days_logged_label'),
                      value: '${_trendSummary!.loggedDays}/30',
                      t: t,
                      palette: palette,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsistencyCard(AppLocalizations l10n, AppPalette palette,
      AppText t, Color primary, WeeklyNutritionSummary summary) {
    final score = summary.consistencyScore;
    final scoreColor = score >= 70
        ? palette.success
        : score >= 40
            ? palette.warning
            : palette.error;
    final scoreLabel = score >= 70
        ? l10n.translate('analytics.score_great')
        : score >= 40
            ? l10n.translate('analytics.score_good')
            : l10n.translate('analytics.score_needs_work');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: AppElevation.opacityLight),
            blurRadius: AppElevation.blurMd,
            offset: AppElevation.offsetMd,
          ),
        ],
      ),
      child: Row(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) => SizedBox(
                width: 72.w,
                height: 72.w,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: _barAnim.value * score / 100,
                    color: scoreColor,
                    backgroundColor: palette.surfaceVariant,
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: t.headlineS.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('analytics.consistency_score'),
                  style: t.bodyM,
                ),
                SizedBox(height: AppSpacing.xxs.h),
                Text(
                  scoreLabel,
                  style: t.headlineS.copyWith(color: scoreColor),
                ),
                SizedBox(height: AppSpacing.xxs.h),
                Text(
                  l10n
                      .translate('analytics.logged_days')
                      .replaceAll('{count}', '${summary.loggedDays}'),
                  style: t.labelS,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primary, WeeklyNutritionSummary summary) {
    final kcal = l10n.translate('analytics.kcal');
    final g = l10n.translate('analytics.g');
    final items = [
      (
        l10n.translate('analytics.avg_calories'),
        '${summary.avgCalories.round()} $kcal',
        Icons.local_fire_department,
        primary
      ),
      (
        l10n.translate('analytics.avg_protein'),
        '${summary.avgProtein.round()} $g',
        Icons.fitness_center,
        palette.protein
      ),
      (
        l10n.translate('analytics.avg_carbs'),
        '${summary.avgCarbs.round()} $g',
        Icons.grain,
        palette.carbs
      ),
      (
        l10n.translate('analytics.avg_fat'),
        '${summary.avgFat.round()} $g',
        Icons.water_drop,
        palette.fat
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm.w,
      mainAxisSpacing: AppSpacing.sm.h,
      childAspectRatio: 1.6,
      children: items.map((item) {
        return Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            boxShadow: [
              BoxShadow(
                color:
                    palette.shadow.withValues(alpha: AppElevation.opacityLight),
                blurRadius: AppElevation.blurSm,
                offset: AppElevation.offsetSm,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$3, size: AppSize.iconSm.sp, color: item.$4),
              SizedBox(height: AppSpacing.xxs.h),
              Text(
                item.$2,
                style: t.titleL,
              ),
              SizedBox(height: AppSpacing.xxxs.h),
              Text(
                item.$1,
                style: t.labelS,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primary, WeeklyNutritionSummary summary) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: AppElevation.opacityLight),
            blurRadius: AppElevation.blurMd,
            offset: AppElevation.offsetMd,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('analytics.weekly_chart'),
            style: t.titleL,
          ),
          SizedBox(height: AppSpacing.xxs.h),
          Row(
            children: [
              Container(
                width: 14.w,
                height: 2.h,
                color: palette.textTertiary,
                margin: EdgeInsets.only(right: AppSpacing.xxs.w),
              ),
              Text(
                '${l10n.translate('analytics.target_line')}: ${_targetCalories.round()} ${l10n.translate('analytics.kcal')}',
                style: t.labelS,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          RepaintBoundary(
            child: AnimatedBuilder(
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
                    palette: palette,
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One label/value pair inside the 30-day trend card ([_buildTrendSection]).
class _TrendStat extends StatelessWidget {
  final String label;
  final String value;
  final AppText t;
  final AppPalette palette;

  const _TrendStat({
    required this.label,
    required this.value,
    required this.t,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: t.titleL),
        SizedBox(height: AppSpacing.xxxs.h),
        Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
      ],
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
  final AppPalette palette;
  final String locale;

  const _BarChartPainter({
    required this.days,
    required this.targetCalories,
    required this.progress,
    required this.primaryColor,
    required this.palette,
    required this.locale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    const labelHeight = 24.0;
    final chartHeight = size.height - labelHeight;
    final barWidth = (size.width / days.length) * 0.55;
    final gap = (size.width / days.length) * 0.45;

    final maxCal = days
        .map((d) => d.calories)
        .fold(0.0, math.max)
        .clamp(1.0, double.infinity);
    final scale = chartHeight / (maxCal * 1.15);

    // Target line
    if (targetCalories > 0) {
      final ty = chartHeight - targetCalories * scale;
      if (ty >= 0) {
        final linePaint = Paint()
          ..color = palette.textTertiary.withValues(alpha: 0.5)
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

      final barColor = day.hasLogs ? primaryColor : palette.surfaceVariant;

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barWidth, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      canvas.drawRRect(rRect, Paint()..color = barColor);

      // Day label (Mon, Tue …) — Faz 0 §8.1: was a hardcoded English
      // array regardless of app language; now uses intl's locale-aware
      // weekday abbreviation, matching the pattern already established in
      // bugun_recap_card.dart.
      final parsedDate = DateTime.tryParse(day.date);
      final label = parsedDate != null
          ? intl.DateFormat('E', locale).format(parsedDate).substring(0, 2)
          : '';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: day.hasLogs ? palette.textSecondary : palette.textTertiary,
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
