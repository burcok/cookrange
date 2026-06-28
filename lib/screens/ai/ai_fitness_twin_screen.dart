import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/ai_insight_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'widgets/ai_credit_badge.dart';

class AiFitnessTwinScreen extends StatefulWidget {
  const AiFitnessTwinScreen({super.key});

  @override
  State<AiFitnessTwinScreen> createState() => _AiFitnessTwinScreenState();
}

class _AiFitnessTwinScreenState extends State<AiFitnessTwinScreen>
    with SingleTickerProviderStateMixin {
  String _locale = 'en';
  bool _isGenerating = false;
  String? _generateError;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeController, curve: AppMotion.decelerate);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture synchronously — never read from a provider after an await.
    _locale = context.read<LanguageProvider>().currentLocale.languageCode;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    // Snapshot locale synchronously before any await
    final locale = context.read<LanguageProvider>().currentLocale.languageCode;
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final uid = user.uid;
    final isPremium = user.subscriptionTier.isPremiumOrAbove;

    if (mounted) setState(() { _isGenerating = true; _generateError = null; });

    final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
    if (!canUse) {
      if (!mounted) return;
      setState(() { _isGenerating = false; });
      final l10n = AppLocalizations.of(context);
      unawaited(AppSheet.show(
        context: context,
        title: l10n.translate('ai.credits_exhausted_title'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded,
                  color: AppPalette.of(context).warning, size: 48.r),
              SizedBox(height: 16.h),
              Text(
                l10n.translate('ai.credits_exhausted_body'),
                textAlign: TextAlign.center,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: AppPalette.of(context).textPrimary),
              ),
              SizedBox(height: 24.h),
              AppButton(
                label: l10n.translate('settings.premium.upgrade_btn'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ));
      return;
    }

    try {
      await AiInsightService().generateFitnessTwin(user, locale: locale);
      if (!mounted) return;
      setState(() { _isGenerating = false; });
      unawaited(_fadeController.forward(from: 0));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generateError = e.toString();
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
          if (user != null) ...[
            if (!_isGenerating)
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: palette.textSecondary, size: 22.r),
                tooltip: l10n.translate('ai.twin_regenerate'),
                onPressed: _generate,
              ),
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
        ],
      ),
      body: user == null
          ? AppEmptyState(
              icon: Icons.person_outline_rounded,
              title: l10n.translate('common.not_signed_in'),
              message: l10n.translate('common.sign_in_to_continue'),
            )
          : _buildStreamBody(context, l10n, palette, textTheme, user),
    );
  }

  Widget _buildStreamBody(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    UserModel user,
  ) {
    return StreamBuilder<DocumentSnapshot?>(
      stream: AiInsightService().getLatestProjectionStream(user.uid, _locale),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isGenerating) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: const AppSkeletonList(itemCount: 5),
          );
        }

        final doc = snapshot.data;
        final hasProjection = doc != null && doc.exists;
        final data = hasProjection ? doc.data() as Map<String, dynamic>? : null;

        if (_isGenerating) {
          return _buildGeneratingOverlay(l10n, palette, textTheme, data);
        }

        if (_generateError != null && !hasProjection) {
          return AppErrorState(
            title: l10n.translate('ai.twin_error'),
            message: _generateError,
            retryLabel: l10n.translate('ai.twin_regenerate'),
            onRetry: _generate,
          );
        }

        if (!hasProjection) {
          return _buildGenerateCta(context, l10n, palette, textTheme);
        }

        return _buildProjectionContent(
            context, l10n, palette, textTheme, user, data!, doc);
      },
    );
  }

  Widget _buildGeneratingOverlay(
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic>? existingData,
  ) {
    // If there's stale data, keep it visible under a translucent loading banner
    return Stack(
      children: [
        if (existingData != null)
          Opacity(
            opacity: 0.4,
            child: _buildScrollContent(
                l10n, palette, textTheme, existingData, null),
          ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48.r,
                height: 48.r,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.watch<ThemeProvider>().primaryColor,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                l10n.translate('ai.twin_generating'),
                style: textTheme.bodyM.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateCta(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
  ) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.r,
              height: 96.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.3),
                    primaryColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: primaryColor,
                size: 52.r,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              l10n.translate('ai.twin_subtitle'),
              style: textTheme.headlineS.copyWith(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              l10n.translate('ai.twin_no_data'),
              style: textTheme.bodyM.copyWith(color: palette.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            AppButton(
              label: l10n.translate('ai.twin_generate'),
              onPressed: _generate,
              icon: Icons.auto_awesome_rounded,
            ),
            if (_generateError != null) ...[
              SizedBox(height: 12.h),
              Text(
                _generateError!,
                style: textTheme.labelS.copyWith(color: palette.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionContent(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    UserModel user,
    Map<String, dynamic> data,
    DocumentSnapshot doc,
  ) {
    final generatedAt = (doc['generatedAt'] as Timestamp?)?.toDate();

    return FadeTransition(
      opacity: _fadeAnim,
      child: _buildScrollContent(l10n, palette, textTheme, data, generatedAt),
    );
  }

  Widget _buildScrollContent(
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
    DateTime? generatedAt,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (generatedAt != null) ...[
            Center(
              child: Text(
                l10n.translate('ai.twin_last_generated').replaceAll(
                    '{date}', DateFormat('d MMM yyyy, HH:mm').format(generatedAt)),
                style: textTheme.labelS.copyWith(color: palette.textTertiary),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          _buildHeaderCard(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildProjectionTimeline(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildGoalDateCard(context, l10n, palette, textTheme, data),
          _buildCalorieGapSection(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildRecommendations(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildHistorySection(context, l10n, palette, textTheme),
          SizedBox(height: 24.h),
        ],
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
    final motivationScore = (data['motivationScore'] as num?)?.toInt() ?? 70;
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
                child: Icon(Icons.psychology_rounded,
                    color: primaryColor, size: 26.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('ai.twin_subtitle'),
                      style:
                          textTheme.titleM.copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      l10n.translate('ai.twin_powered'),
                      style: textTheme.labelS.copyWith(color: primaryColor),
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
          primaryColor, 1.0),
      (l10n.translate('ai.twin_60d'),
          data['projection60days'] as String? ?? '',
          primaryColor, 0.65),
      (l10n.translate('ai.twin_90d'),
          data['projection90days'] as String? ?? '',
          primaryColor, 0.40),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('ai.twin_projection_title'),
          style: textTheme.headlineS.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 10.h),
        Row(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < items.length - 1 ? 8.w : 0),
                child: _ProjectionCard(
                  label: item.$1,
                  text: item.$2,
                  color: item.$3.withValues(alpha: item.$4),
                  textTheme: textTheme,
                  palette: palette,
                ),
              ),
            );
          }).toList(),
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
    final weeklyChange =
        (data['weeklyWeightChange'] as num?)?.toDouble() ?? 0;
    final sign = weeklyChange >= 0 ? '+' : '';

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: AppPalette.of(context).success.withValues(alpha: 0.15),
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
                  style:
                      textTheme.titleM.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.translate('ai.twin_weekly_change'),
                style:
                    textTheme.labelS.copyWith(color: palette.textTertiary),
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

    final text = isDeficit
        ? l10n
            .translate('ai.twin_calorie_below')
            .replaceAll('{n}', '$absGap')
        : l10n
            .translate('ai.twin_calorie_above')
            .replaceAll('{n}', '$absGap');

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
                    style: textTheme.labelS
                        .copyWith(color: palette.textTertiary),
                  ),
                  Text(
                    text,
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

  Widget _buildHistorySection(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
  ) {
    final user = context.read<UserProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('ai.twin_history_title'),
          style: textTheme.headlineS.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 10.h),
        StreamBuilder<List<QueryDocumentSnapshot>>(
          stream: AiInsightService().getProjectionHistoryStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppSkeletonList(itemCount: 2);
            }

            final docs = snapshot.data ?? [];
            // Skip the first (latest) if there are multiple — it's already shown
            final historyDocs = docs.length > 1 ? docs.sublist(1) : <QueryDocumentSnapshot>[];

            if (historyDocs.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  l10n.translate('ai.twin_history_empty'),
                  style:
                      textTheme.bodyM.copyWith(color: palette.textSecondary),
                ),
              );
            }

            return Column(
              children: historyDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = (data['generatedAt'] as Timestamp?)?.toDate();
                final score =
                    (data['motivationScore'] as num?)?.toInt() ?? 70;
                final goalDate =
                    data['goalDateEstimate'] as String? ?? '—';
                final dateStr = ts != null
                    ? l10n
                        .translate('ai.twin_history_date')
                        .replaceAll(
                            '{date}',
                            DateFormat('d MMM yyyy').format(ts))
                    : '';

                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: textTheme.labelS
                                    .copyWith(color: palette.textTertiary),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                l10n
                                    .translate('ai.twin_history_goal_date')
                                    .replaceAll('{date}', goalDate),
                                style: textTheme.bodyM
                                    .copyWith(color: palette.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        _MotivationBadge(score: score),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
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
            style: textTheme.labelS
                .copyWith(color: color, fontWeight: FontWeight.bold),
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
