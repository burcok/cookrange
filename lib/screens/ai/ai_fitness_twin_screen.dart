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
import '../../core/services/ai/ai_service.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/ai_insight_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'widgets/ai_credit_badge.dart';
import 'widgets/ai_credits_sheet.dart';

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
  bool _limitReached = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: AppMotion.decelerate);
  }

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

    if (mounted) setState(() { _isGenerating = true; _generateError = null; _limitReached = false; });

    final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
    if (!canUse) {
      if (!mounted) return;
      setState(() { _isGenerating = false; _limitReached = true; });
      return;
    }

    try {
      await AiInsightService().generateFitnessTwin(user, locale: locale);
      if (!mounted) return;
      setState(() { _isGenerating = false; });
      unawaited(_fadeController.forward(from: 0));
    } on AIQuotaExceededException {
      if (!mounted) return;
      setState(() { _isGenerating = false; _limitReached = true; });
      unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
    } catch (e) {
      unawaited(AiCreditService().rollbackCredit(uid));
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
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: _buildAppBar(context, l10n, palette, textTheme, primaryColor, user),
      body: Stack(
        children: [
          // ── Ambient mesh-glow background ──────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  // Large brand blob — top-right
                  Positioned(
                    top: -100,
                    right: -80,
                    child: _GlowBlob(
                      color: primaryColor,
                      size: 340,
                      opacity: palette.isDark ? 0.28 : 0.18,
                    ),
                  ),
                  // Energy blob — mid-left
                  Positioned(
                    top: 220,
                    left: -100,
                    child: _GlowBlob(
                      color: palette.energy,
                      size: 300,
                      opacity: palette.isDark ? 0.22 : 0.14,
                    ),
                  ),
                  // Info accent blob — bottom-right (small)
                  Positioned(
                    bottom: 60,
                    right: -60,
                    child: _GlowBlob(
                      color: palette.info,
                      size: 200,
                      opacity: palette.isDark ? 0.16 : 0.10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Main content ──────────────────────────────────────────────────
          user == null
              ? AppEmptyState(
                  icon: Icons.person_outline_rounded,
                  title: l10n.translate('common.not_signed_in'),
                  message: l10n.translate('common.sign_in_to_continue'),
                )
              : _buildStreamBody(context, l10n, palette, textTheme, user),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Color primaryColor,
    UserModel? user,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 2),
      child: Container(
        decoration: BoxDecoration(
          color: palette.background,
          // Gradient accent line at the bottom of the AppBar
          border: const Border(
            bottom: BorderSide(
              color: Colors.transparent,
              width: 0,
            ),
          ),
        ),
        child: Stack(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
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
            // Gradient accent line at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      palette.energy,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          return _buildGeneratingShimmer(palette, data, l10n, textTheme);
        }

        if (_limitReached) {
          return _buildLimitReached(context, l10n, palette, textTheme);
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

  /// Shimmer skeleton shown while the projection is being generated.
  /// If stale data exists it is shown at reduced opacity underneath.
  Widget _buildGeneratingShimmer(
    AppPalette palette,
    Map<String, dynamic>? existingData,
    AppLocalizations l10n,
    AppText textTheme,
  ) {
    return Stack(
      children: [
        if (existingData != null)
          Opacity(
            opacity: 0.35,
            child: _buildScrollContent(
                l10n, palette, textTheme, existingData, null),
          ),
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: AppShimmer(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSkeletonBox(height: 120, radius: AppRadius.card),
                  SizedBox(height: 12.h),
                  const AppSkeletonBox(height: 100, radius: AppRadius.card),
                  SizedBox(height: 12.h),
                  const AppSkeletonBox(height: 80, radius: AppRadius.card),
                  SizedBox(height: 12.h),
                  const AppSkeletonBox(height: 80, radius: AppRadius.card),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            l10n.translate('ai.twin_generating'),
            style: textTheme.labelM.copyWith(color: palette.textSecondary),
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
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(
          icon: Icons.self_improvement_rounded,
          title: l10n.translate('ai.twin_empty_title'),
          message: _generateError ?? l10n.translate('ai.twin_empty_msg'),
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: _GradientButton(
            label: l10n.translate('ai.twin_generate'),
            primaryColor: primaryColor,
            energyColor: palette.energy,
            onPressed: _generate,
          ),
        ),
        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildLimitReached(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
  ) {
    final user = context.read<UserProvider>().user;
    return AppEmptyState(
      icon: Icons.bolt_rounded,
      title: l10n.translate('ai.twin_limit_title'),
      message: l10n.translate('ai.twin_limit_msg'),
      actionLabel: l10n.translate('settings.premium.upgrade_btn'),
      onAction: user == null
          ? null
          : () => AiCreditsSheet.show(
                context,
                uid: user.uid,
                isPremium: user.subscriptionTier.isPremiumOrAbove,
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
    final primaryColor = context.read<ThemeProvider>().primaryColor;
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
          _buildStatsGrid(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildProjectionTimeline(context, l10n, palette, textTheme, data),
          _buildCalorieGapSection(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildRecommendations(context, l10n, palette, textTheme, data),
          SizedBox(height: 16.h),
          _buildHistorySection(context, l10n, palette, textTheme),
          SizedBox(height: 20.h),
          // Regenerate button at the bottom
          _GradientButton(
            label: l10n.translate('ai.twin_regenerate'),
            primaryColor: primaryColor,
            energyColor: palette.energy,
            icon: Icons.refresh_rounded,
            onPressed: _isGenerating ? null : _generate,
            loading: _isGenerating,
          ),
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

    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withValues(alpha: 0.9),
                      palette.energy.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 26.r),
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

  /// Stats grid: weeklyWeightChange, goalDate, calorieGap, motivationScore
  Widget _buildStatsGrid(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText textTheme,
    Map<String, dynamic> data,
  ) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final goalDate = data['goalDateEstimate'] as String? ?? '—';
    final weeklyChange = (data['weeklyWeightChange'] as num?)?.toDouble() ?? 0;
    final sign = weeklyChange >= 0 ? '+' : '';
    final calorieGap = (data['calorieGap'] as num?)?.toInt() ?? 0;
    final motivationScore = (data['motivationScore'] as num?)?.toInt() ?? 70;

    final weightColor = weeklyChange > 0
        ? palette.success
        : weeklyChange < 0
            ? palette.error
            : palette.textSecondary;
    final calorieColor = calorieGap < 0 ? palette.warning : palette.info;
    final motivationColor = motivationScore >= 75
        ? palette.success
        : motivationScore >= 50
            ? palette.warning
            : palette.error;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 1.6,
      children: [
        _StatCell(
          icon: Icons.trending_up_rounded,
          iconGradient: LinearGradient(
            colors: [weightColor, weightColor.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          label: l10n.translate('ai.twin_weekly_change'),
          value: '$sign${weeklyChange.toStringAsFixed(1)} kg/wk',
          valueColor: weightColor,
          textTheme: textTheme,
          palette: palette,
        ),
        _StatCell(
          icon: Icons.emoji_events_rounded,
          iconGradient: LinearGradient(
            colors: [palette.success, palette.success.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          label: l10n.translate('ai.twin_goal_date'),
          value: goalDate,
          valueColor: palette.textPrimary,
          textTheme: textTheme,
          palette: palette,
        ),
        _StatCell(
          icon: Icons.local_fire_department_rounded,
          iconGradient: LinearGradient(
            colors: [calorieColor, calorieColor.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          label: l10n.translate('ai.twin_calorie_gap'),
          value: calorieGap == 0
              ? '—'
              : '${calorieGap > 0 ? '+' : ''}$calorieGap kcal',
          valueColor: calorieGap == 0 ? palette.textSecondary : calorieColor,
          textTheme: textTheme,
          palette: palette,
        ),
        _StatCell(
          icon: Icons.bolt_rounded,
          iconGradient: LinearGradient(
            colors: [motivationColor, primaryColor.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          label: l10n.translate('ai.twin_motivation'),
          value: '$motivationScore%',
          valueColor: motivationColor,
          textTheme: textTheme,
          palette: palette,
        ),
      ],
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
                child: _GlassProjectionCard(
                  label: item.$1,
                  text: item.$2,
                  accentColor: item.$3.withValues(alpha: item.$4),
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
      child: AppGlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 22.r),
            ),
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
                child: AppGlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              palette.energy.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: textTheme.labelS.copyWith(
                                color: Colors.white,
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
                  child: AppGlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
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

/// Ambient glow blob for the mesh-glow background effect.
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Stats grid cell using AppGlassCard with gradient icon background.
class _StatCell extends StatelessWidget {
  final IconData icon;
  final Gradient iconGradient;
  final String label;
  final String value;
  final Color valueColor;
  final AppText textTheme;
  final AppPalette palette;

  const _StatCell({
    required this.icon,
    required this.iconGradient,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.textTheme,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              gradient: iconGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Icon(icon, color: Colors.white, size: 18.r),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: textTheme.labelS
                      .copyWith(color: palette.textTertiary, fontSize: 10.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: textTheme.labelL.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Glassmorphism projection card for the 30/60/90-day timeline.
class _GlassProjectionCard extends StatelessWidget {
  final String label;
  final String text;
  final Color accentColor;
  final AppText textTheme;
  final AppPalette palette;

  const _GlassProjectionCard({
    required this.label,
    required this.text,
    required this.accentColor,
    required this.textTheme,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.xs.r),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              label,
              style: textTheme.labelS.copyWith(
                  color: accentColor, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8.h),
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

/// Gradient-filled regenerate button wrapping AppButton primary variant.
/// Uses a DecoratedBox + ClipRRect to apply a brand→energy gradient while
/// still leveraging AppButton's press-scale, haptics, and loading state.
class _GradientButton extends StatelessWidget {
  final String label;
  final Color primaryColor;
  final Color energyColor;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const _GradientButton({
    required this.label,
    required this.primaryColor,
    required this.energyColor,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.button.r),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [
                    primaryColor.withValues(alpha: 0.4),
                    energyColor.withValues(alpha: 0.3),
                  ]
                : [
                    primaryColor,
                    energyColor,
                  ],
          ),
        ),
        child: AppButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          loading: loading,
          variant: AppButtonVariant.ghost,
        ),
      ),
    );
  }
}
