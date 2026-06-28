import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/ai_insight_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'widgets/ai_credit_badge.dart';

class AiFitnessTwinScreen extends StatefulWidget {
  const AiFitnessTwinScreen({super.key});

  @override
  State<AiFitnessTwinScreen> createState() => _AiFitnessTwinScreenState();
}

class _AiFitnessTwinScreenState extends State<AiFitnessTwinScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _projection;
  bool _isLoading = true;
  String? _error;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeController, curve: AppMotion.decelerate);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjection());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProjection() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final uid = user.uid;
    final isPremium =
        user.subscriptionTier.isPremiumOrAbove;

    final canUse =
        await AiCreditService().checkAndConsume(uid, isPremium);
    if (!canUse) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FeatureGateService().showPaywall(
            context,
            featureName: 'AI Credits Exhausted',
            featureDescription:
                'You\'ve used all 20 free AI calls this month. '
                'Upgrade to Premium for unlimited access.',
          );
        }
      });
      return;
    }

    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final result = await AiInsightService().generateFitnessTwin(user);
      if (!mounted) return;
      setState(() {
        _projection = result;
        _isLoading = false;
      });
      unawaited(_fadeController.forward());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('ai.twin_title'),
          style: textTheme.titleM.copyWith(color: palette.textPrimary),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Center(
                child: AiCreditBadge(
                  uid: user.uid,
                  isPremium: user.subscriptionTier.isPremiumOrAbove,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(context, l10n, palette, textTheme, user),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    UserModel? user,
  ) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: const AppSkeletonList(itemCount: 5),
      );
    }

    if (_error != null) {
      return AppErrorState(
        title: l10n.translate('ai.twin_error'),
        message: _error,
        retryLabel: 'Retry',
        onRetry: _loadProjection,
      );
    }

    if (user == null || _projection == null) {
      return AppEmptyState(
        icon: Icons.psychology_rounded,
        title: l10n.translate('ai.twin_no_data'),
        message: l10n.translate('ai.twin_no_data'),
      );
    }

    final data = _projection!;
    final notConfigured = data['currentStatus'] ==
        'Enable AI for a personalized projection of your fitness journey.';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notConfigured) ...[
              _buildNoAiCard(context, l10n, palette, textTheme),
            ] else ...[
              _buildHeaderCard(context, l10n, palette, textTheme, data),
              SizedBox(height: 16.h),
              _buildProjectionTimeline(context, l10n, palette, textTheme, data),
              SizedBox(height: 16.h),
              _buildGoalDateCard(context, l10n, palette, textTheme, data),
              _buildCalorieGapSection(context, l10n, palette, textTheme, data),
              SizedBox(height: 16.h),
              _buildRecommendations(context, l10n, palette, textTheme, data),
            ],
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  // ─── Section Builders ─────────────────────────────────────────────────────

  Widget _buildHeaderCard(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final motivationScore =
        (data['motivationScore'] as num?)?.toInt() ?? 70;
    final currentStatus = data['currentStatus'] as String? ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: primaryColor,
                  size: 26.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('ai.twin_subtitle'),
                      style: textTheme.titleM.copyWith(
                          color: palette.textPrimary),
                    ),
                    Text(
                      l10n.translate('ai.twin_powered'),
                      style: textTheme.labelS.copyWith(
                          color: primaryColor),
                    ),
                  ],
                ),
              ),
              _MotivationBadge(score: motivationScore),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.translate('ai.twin_status'),
            style: textTheme.labelS.copyWith(color: palette.textTertiary),
          ),
          SizedBox(height: 4.h),
          Text(
            currentStatus,
            style: textTheme.bodyM.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionTimeline(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final items = [
      (l10n.translate('ai.twin_30d'),
          data['projection30days'] as String? ?? '',
          primaryColor,
          1.0),
      (l10n.translate('ai.twin_60d'),
          data['projection60days'] as String? ?? '',
          primaryColor,
          0.65),
      (l10n.translate('ai.twin_90d'),
          data['projection90days'] as String? ?? '',
          primaryColor,
          0.40),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projection',
          style: textTheme.headlineS.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 10.h),
        Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: item == items.last ? 0 : 8.w),
                    child: _ProjectionCard(
                      label: item.$1,
                      text: item.$2,
                      color: item.$3.withValues(alpha: item.$4),
                      textTheme: textTheme,
                      palette: palette,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGoalDateCard(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final goalDate = data['goalDateEstimate'] as String? ?? '—';
    final weeklyChange = (data['weeklyWeightChange'] as num?)?.toDouble() ?? 0;
    final sign = weeklyChange >= 0 ? '+' : '';

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_rounded,
                color: palette.success, size: 24.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('ai.twin_goal_date'),
                  style:
                      textTheme.labelS.copyWith(color: palette.textTertiary),
                ),
                Text(
                  goalDate,
                  style: textTheme.titleM.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.translate('ai.twin_weekly_change'),
                style: textTheme.labelS.copyWith(color: palette.textTertiary),
              ),
              Text(
                '$sign${weeklyChange.toStringAsFixed(1)} kg/wk',
                style: textTheme.labelL.copyWith(
                  color: weeklyChange > 0
                      ? palette.success
                      : weeklyChange < 0
                          ? palette.error
                          : palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieGapSection(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final calorieGap = (data['calorieGap'] as num?)?.toInt() ?? 0;
    if (calorieGap == 0) return const SizedBox.shrink();

    final isDeficit = calorieGap < 0;
    final color = isDeficit ? palette.warning : palette.info;
    final absGap = calorieGap.abs();

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: AppCard(
        color: color.withValues(alpha: 0.08),
        child: Row(
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: color, size: 28.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('ai.twin_calorie_gap'),
                    style: textTheme.labelS.copyWith(color: palette.textTertiary),
                  ),
                  Text(
                    isDeficit
                        ? 'You\'re eating $absGap kcal/day below your target'
                        : 'You\'re eating $absGap kcal/day above your target',
                    style:
                        textTheme.bodyM.copyWith(color: palette.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final recs = List<String>.from(data['recommendations'] as List? ?? []);
    if (recs.isEmpty) return const SizedBox.shrink();

    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('ai.twin_recommendations'),
          style: textTheme.headlineS.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 10.h),
        ...recs.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: textTheme.labelS.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: textTheme.bodyM
                              .copyWith(color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildNoAiCard(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
  ) {
    return AppEmptyState(
      icon: Icons.psychology_outlined,
      title: l10n.translate('ai.twin_no_ai'),
      message: l10n.translate('ai.twin_no_ai'),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _MotivationBadge extends StatelessWidget {
  final int score;
  const _MotivationBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = score >= 75
        ? palette.success
        : score >= 50
            ? palette.warning
            : palette.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: color, size: 14.r),
          SizedBox(width: 2.w),
          Text(
            '$score%',
            style: AppText.of(context)
                .labelS
                .copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final AppText textTheme;
  final AppPalette palette;

  const _ProjectionCard({
    required this.label,
    required this.text,
    required this.color,
    required this.textTheme,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelS.copyWith(
                color: color, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            text,
            style: textTheme.bodyM.copyWith(color: palette.textPrimary),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
