import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai/ai_service.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/ai_insight_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/ds/ds.dart';
import 'widgets/ai_credit_badge.dart';
import 'widgets/ai_credits_sheet.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen>
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
    _fadeController =
        AnimationController(vsync: this, duration: AppMotion.slow);
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: AppMotion.decelerate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = context.read<LanguageProvider>().currentLocale.languageCode;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final locale = context.read<LanguageProvider>().currentLocale.languageCode;
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final uid = user.uid;
    final isPremium = user.subscriptionTier.isPremiumOrAbove;

    setState(() {
      _isGenerating = true;
      _generateError = null;
      _limitReached = false;
    });

    // Low-data recaps are free — only consume a credit for full AI recaps.
    final isLowData = await AiInsightService().checkLowDataThisWeek(uid);
    if (!isLowData) {
      final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
      if (!canUse) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _limitReached = true;
        });
        unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
        return;
      }
    }

    try {
      await AiInsightService().generateWeeklyRecap(user, locale: locale);
      if (!mounted) return;
      setState(() => _isGenerating = false);
      unawaited(_fadeController.forward(from: 0));
    } on AIQuotaExceededException {
      if (!isLowData) unawaited(AiCreditService().rollbackCredit(uid));
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _limitReached = true;
      });
      unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
    } catch (e) {
      if (!isLowData) unawaited(AiCreditService().rollbackCredit(uid));
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
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: _buildAppBar(context, l10n, palette, t, primary, user),
      body: Stack(
        children: [
          // Ambient background blobs
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -80,
                    right: -60,
                    child: _GlowBlob(
                        color: primary,
                        size: 300,
                        opacity: palette.isDark ? 0.24 : 0.16),
                  ),
                  Positioned(
                    top: 200,
                    left: -80,
                    child: _GlowBlob(
                        color: palette.success,
                        size: 260,
                        opacity: palette.isDark ? 0.18 : 0.10),
                  ),
                ],
              ),
            ),
          ),
          user == null
              ? AppEmptyState(
                  icon: Icons.person_outline_rounded,
                  title: l10n.translate('common.not_signed_in'),
                  message: l10n.translate('common.sign_in_to_continue'),
                )
              : _buildBody(context, l10n, palette, t, primary, user),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
    dynamic user,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 2),
      child: Container(
        decoration: BoxDecoration(color: palette.background),
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
                l10n.translate('ai.weekly_recap_title'),
                style: t.titleM.copyWith(color: palette.textPrimary),
              ),
              actions: [
                if (user != null) ...[
                  if (!_isGenerating)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: palette.textSecondary, size: 22.r),
                      tooltip: l10n.translate('ai.weekly_recap_regenerate'),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, palette.success]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
    dynamic user,
  ) {
    return StreamBuilder<DocumentSnapshot?>(
      stream: AiInsightService().getLatestWeeklyRecapStream(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !_isGenerating) {
          return _buildSkeleton();
        }

        final doc = snap.data;
        final hasData = doc != null && doc.exists;

        if (_isGenerating) {
          return _buildGenerating(l10n, palette, t, primary);
        }

        if (!hasData) {
          return _buildEmpty(l10n, palette, t, primary);
        }

        final data = doc.data() as Map<String, dynamic>;
        // Check if this doc is from the current week
        final docWeekKey = data['weekKey'] as String? ?? '';
        final currentWeekKey = AiInsightService.weekKey(DateTime.now());
        final isStale = docWeekKey != currentWeekKey;

        return FadeTransition(
          opacity: _fadeAnim.value > 0
              ? _fadeAnim
              : const AlwaysStoppedAnimation(1.0),
          child: _buildRecap(
              context, l10n, palette, t, primary, data, user, isStale),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      child: Column(
        children: [
          AppSkeletonBox(
              width: double.infinity, height: 180.h, radius: AppRadius.card.r),
          SizedBox(height: AppSpacing.md.h),
          AppSkeletonBox(
              width: double.infinity, height: 120.h, radius: AppRadius.card.r),
          SizedBox(height: AppSpacing.md.h),
          AppSkeletonBox(
              width: double.infinity, height: 100.h, radius: AppRadius.card.r),
        ],
      ),
    );
  }

  Widget _buildGenerating(
      AppLocalizations l10n, AppPalette palette, AppText t, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppShimmer(
            child: Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                color: palette.shimmerBase,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(
            l10n.translate('ai.weekly_recap_generating'),
            style: t.bodyL.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
      AppLocalizations l10n, AppPalette palette, AppText t, Color primary) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.xl.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 48.r, color: primary),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(
            l10n.translate('ai.weekly_recap_no_recap'),
            style: t.titleL.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            l10n.translate('ai.weekly_recap_no_recap_sub'),
            style: t.bodyL.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (_generateError != null) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              l10n.translate('ai.weekly_recap_error'),
              style: t.bodyM.copyWith(color: palette.error),
              textAlign: TextAlign.center,
            ),
          ],
          if (_limitReached) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              l10n.translate('ai.credits_limit_reached'),
              style: t.bodyM.copyWith(color: palette.warning),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: AppSpacing.xl.h),
          AppButton(
            label: l10n.translate('ai.weekly_recap_generate'),
            icon: Icons.auto_awesome,
            onPressed: _generate,
          ),
        ],
      ),
    );
  }

  Widget _buildRecap(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
    Map<String, dynamic> data,
    dynamic user,
    bool isStale,
  ) {
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final wins = List<String>.from(data['wins'] as List? ?? []);
    final challenges = List<String>.from(data['challenges'] as List? ?? []);
    final trend = data['trend'] as String? ?? 'steady';
    final recommendation = data['recommendation'] as String? ?? '';
    final weekKey = data['weekKey'] as String? ?? '';
    final isLowData = data['isLowData'] as bool? ?? false;

    // Parse weekKey to a human-readable date
    String weekLabel = '';
    try {
      final parts = weekKey.split('-');
      if (parts.length == 3) {
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        weekLabel = l10n.translate('ai.weekly_recap_week_of',
            variables: {'date': DateFormat('MMM d', _locale).format(d)});
      }
    } catch (_) {}

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Week label + stale badge ──────────────────────────────────────
          if (weekLabel.isNotEmpty)
            Row(
              children: [
                Text(
                  weekLabel,
                  style: t.bodyM.copyWith(color: palette.textSecondary),
                ),
                if (isStale) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: palette.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                    ),
                    child: Text(
                      l10n.translate('common.stale'),
                      style: t.labelS.copyWith(color: palette.warning),
                    ),
                  ),
                ],
              ],
            ),
          SizedBox(height: AppSpacing.md.h),

          // ── Score ring card ───────────────────────────────────────────────
          AppGlassCard(
            padding: EdgeInsets.all(AppSpacing.lg.r),
            child: Row(
              children: [
                _ScoreRing(
                    score: score, primary: primary, t: t, palette: palette),
                SizedBox(width: AppSpacing.lg.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('ai.weekly_recap_score'),
                        style: t.labelM.copyWith(color: palette.textSecondary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$score / 100',
                        style: t.displayM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8.h),
                      _TrendChip(
                          trend: trend, palette: palette, t: t, l10n: l10n),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md.h),

          // ── Wins ─────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.emoji_events_rounded,
            iconColor: palette.success,
            title: l10n.translate('ai.weekly_recap_wins'),
            items: wins,
            palette: palette,
            t: t,
          ),
          SizedBox(height: AppSpacing.md.h),

          // ── Challenges ───────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.trending_up_rounded,
            iconColor: palette.warning,
            title: l10n.translate('ai.weekly_recap_challenges'),
            items: challenges,
            palette: palette,
            t: t,
          ),
          SizedBox(height: AppSpacing.md.h),

          // ── Recommendation ───────────────────────────────────────────────
          AppGlassCard(
            padding: EdgeInsets.all(AppSpacing.lg.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 18.r, color: primary),
                    SizedBox(width: 8.w),
                    Text(
                      l10n.translate('ai.weekly_recap_recommendation'),
                      style: t.labelM.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  recommendation,
                  style: t.bodyL.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),

          if (isLowData) ...[
            SizedBox(height: AppSpacing.sm.h),
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.r),
              decoration: BoxDecoration(
                color: palette.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16.r, color: palette.info),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      l10n.translate('ai.weekly_recap_low_data'),
                      style: t.bodyM.copyWith(color: palette.info),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: AppSpacing.xl.h),

          // ── Share button ─────────────────────────────────────────────────
          AppButton(
            label: l10n.translate('ai.weekly_recap_share'),
            icon: Icons.ios_share_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _share(context, l10n, score, wins, recommendation),
          ),

          if (isStale) ...[
            SizedBox(height: AppSpacing.sm.h),
            AppButton(
              label: l10n.translate('ai.weekly_recap_generate'),
              icon: Icons.auto_awesome,
              variant: AppButtonVariant.tonal,
              onPressed: _generate,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    AppLocalizations l10n,
    int score,
    List<String> wins,
    String recommendation,
  ) async {
    final winsText = wins.take(2).join(', ');
    await Share.share(
      l10n.translate('sharing.weekly_recap_text', variables: {
        'score': score.toString(),
        'wins': winsText,
        'recommendation': recommendation,
        'appTag': '#Cookrange',
      }),
      subject: l10n.translate('sharing.weekly_recap_subject'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color primary;
  final AppText t;
  final AppPalette palette;

  const _ScoreRing({
    required this.score,
    required this.primary,
    required this.t,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88.r,
      height: 88.r,
      child: CustomPaint(
        painter: _RingPainter(
          progress: score / 100.0,
          color: primary,
          bgColor: palette.border.withValues(alpha: 0.3),
          strokeWidth: 8,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _TrendChip extends StatelessWidget {
  final String trend;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _TrendChip({
    required this.trend,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    switch (trend) {
      case 'improving':
        color = palette.success;
        icon = Icons.trending_up_rounded;
        label = l10n.translate('ai.weekly_recap_trend_improving');
      case 'declining':
        color = palette.warning;
        icon = Icons.trending_down_rounded;
        label = l10n.translate('ai.weekly_recap_trend_declining');
      default:
        color = palette.info;
        icon = Icons.trending_flat_rounded;
        label = l10n.translate('ai.weekly_recap_trend_steady');
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: t.labelS.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final AppPalette palette;
  final AppText t;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.r, color: iconColor),
              SizedBox(width: 8.w),
              Text(
                title,
                style: t.labelM.copyWith(
                    color: palette.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6.h),
                    width: 6.r,
                    height: 6.r,
                    decoration:
                        BoxDecoration(color: iconColor, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      item,
                      style: t.bodyL.copyWith(color: palette.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: size / 1.5,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}
