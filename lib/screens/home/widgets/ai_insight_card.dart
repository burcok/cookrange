import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/ai_insight_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/ai_insight_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../ai/ai_fitness_twin_screen.dart';

class AiInsightCard extends StatefulWidget {
  final UserModel user;

  const AiInsightCard({super.key, required this.user});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard>
    with SingleTickerProviderStateMixin {
  static const String _kDismissedDate = 'ai_insight_dismissed_date';

  AiRiskLevel _riskLevel = AiRiskLevel.none;
  AiInsightModel? _insight;
  bool _isLoading = true;
  bool _isDismissed = false;
  bool _hasError = false;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeController, curve: AppMotion.decelerate);

  @override
  void initState() {
    super.initState();
    _checkDismissedAndLoad();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkDismissedAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final dismissedDate = prefs.getString(_kDismissedDate);
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      if (dismissedDate == today) {
        setState(() { _isDismissed = true; _isLoading = false; });
        return;
      }
    } catch (e) {
      // ignore prefs error
    }

    if (!context.mounted) return;
    await _loadInsight();
  }

  Future<void> _loadInsight() async {
    if (!context.mounted) return;
    final locale =
        context.read<LanguageProvider>().currentLocale.languageCode;
    setState(() { _isLoading = true; _hasError = false; });

    try {
      final riskLevel =
          await AiInsightService().detectRiskLevel(widget.user.uid);

      if (!context.mounted) return;
      setState(() => _riskLevel = riskLevel);

      if (riskLevel == AiRiskLevel.high || riskLevel == AiRiskLevel.medium) {
        // Build risk insight without AI call
        if (!context.mounted) return;
        setState(() => _isLoading = false);
        unawaited(_fadeController.forward());
        return;
      }

      // Low or none — load accountability insight
      final insight = await AiInsightService()
          .generateAccountabilityInsight(widget.user, locale: locale);

      if (!context.mounted) return;
      setState(() {
        _insight = insight;
        _isLoading = false;
      });
      unawaited(_fadeController.forward());
    } catch (e) {
      if (!context.mounted) return;
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      await prefs.setString(_kDismissedDate, today);
    } catch (e) {
      // ignore
    }
    if (context.mounted) setState(() => _isDismissed = true);
  }

  void _openProjection() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const AiFitnessTwinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    if (_isLoading) {
      return RepaintBoundary(child: _buildSkeleton());
    }

    if (_hasError) {
      return RepaintBoundary(
        child: _buildErrorState(context),
      );
    }

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: AppErrorState(
        title: l10n.translate('ai.twin_error'),
        retryLabel: l10n.translate('common.retry'),
        onRetry: _loadInsight,
        compact: true,
      ),
    );
  }

  Widget _buildSkeleton() {
    return AppShimmer(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppSkeletonBox(height: 40, circle: true),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSkeletonBox(width: 140, height: 14),
                      SizedBox(height: 6.h),
                      const AppSkeletonBox(width: 90, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            const AppSkeletonBox(width: double.infinity, height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_riskLevel == AiRiskLevel.high || _riskLevel == AiRiskLevel.medium) {
      return _buildRiskCard(context, l10n);
    }

    return _buildAccountabilityCard(context, l10n);
  }

  Widget _buildRiskCard(BuildContext context, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final isHigh = _riskLevel == AiRiskLevel.high;
    final color = isHigh ? palette.error : palette.warning;

    final message = isHigh
        ? l10n.translate('ai.insight_risk_high')
        : l10n.translate('ai.insight_risk_medium');

    return GestureDetector(
      onTap: _openProjection,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHigh
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_outlined,
                  color: color,
                  size: 22.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    message,
                    style:
                        textTheme.bodyM.copyWith(color: palette.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded,
                      color: palette.textTertiary, size: 18.r),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: l10n.translate('ai.risk_cta'),
                      onPressed: _openProjection,
                      size: AppButtonSize.small,
                      expand: false,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '✨ Powered by AI',
                  style: textTheme.labelS.copyWith(
                      color: palette.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountabilityCard(
      BuildContext context, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final insight = _insight;

    if (insight == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _openProjection,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: 0.18),
              primaryColor.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
              color: primaryColor.withValues(alpha: 0.25)),
        ),
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.psychology_rounded,
                      color: primaryColor, size: 20.r),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    insight.message,
                    style:
                        textTheme.bodyM.copyWith(color: palette.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded,
                      color: palette.textTertiary, size: 18.r),
                ),
              ],
            ),
            if (insight.tips.isNotEmpty) ...[
              SizedBox(height: 10.h),
              ...insight.tips.take(2).map(
                    (tip) => Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: primaryColor, size: 14.r),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              tip,
                              style: textTheme.labelM
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: l10n.translate('ai.insight_see_projection'),
                      onPressed: _openProjection,
                      variant: AppButtonVariant.tonal,
                      size: AppButtonSize.small,
                      expand: false,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '✨ Powered by AI',
                  style: textTheme.labelS.copyWith(
                      color: palette.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
