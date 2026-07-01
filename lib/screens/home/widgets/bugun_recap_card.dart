import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/food_log_service.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ds/app_card.dart';
import '../../../core/widgets/ds/app_shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _DayStat {
  final DateTime date;
  final int kcal;

  const _DayStat({required this.date, required this.kcal});

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// BugunRecapCard
// ─────────────────────────────────────────────────────────────────────────────

/// 7-day sparkline card positioned between AiInsightCard and TodaySummaryCard.
///
/// Fetches last 7 days from [FoodLogService] with a stale-while-revalidate
/// cache in [SharedPreferences] so it renders instantly on subsequent opens.
/// Zero AI credits — all computation is local.
class BugunRecapCard extends StatefulWidget {
  final String uid;
  final int calorieTarget;

  const BugunRecapCard({
    super.key,
    required this.uid,
    required this.calorieTarget,
  });

  @override
  State<BugunRecapCard> createState() => _BugunRecapCardState();
}

class _BugunRecapCardState extends State<BugunRecapCard> {
  static const _kCachePrefix = 'bugun_recap_';

  List<_DayStat>? _days; // null = still loading
  bool _hasAnyLog = false;

  @override
  void initState() {
    super.initState();
    _loadSwr();
  }

  // ── Stale-while-revalidate ─────────────────────────────────────────────────

  Future<void> _loadSwr() async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_kCachePrefix$today');

    if (cached != null && mounted) {
      // Show stale data immediately while the fresh fetch runs.
      setState(() => _applyJson(cached));
    }

    // Always refetch so today's bars update as the user logs meals.
    await _fetchAndCache(prefs, today);
  }

  Future<void> _fetchAndCache(SharedPreferences prefs, String today) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    try {
      final map = await FoodLogService()
          .getLogsForDateRange(widget.uid, _dateOnly(start), _dateOnly(now));

      final days = <_DayStat>[];
      for (var d = _dateOnly(start);
          !d.isAfter(_dateOnly(now));
          d = d.add(const Duration(days: 1))) {
        final key = _fmtKey(d);
        final logs = map[key] ?? [];
        final kcal = logs.fold<num>(0, (s, l) => s + l.calories).round();
        days.add(_DayStat(date: d, kcal: kcal));
      }

      final payload = jsonEncode({
        'days': days.map((d) => {'date': d.dateKey, 'kcal': d.kcal}).toList(),
      });
      await prefs.setString('$_kCachePrefix$today', payload);

      if (mounted) setState(() => _applyList(days));
    } catch (e) {
      debugPrint('BugunRecapCard fetch error: $e');
    }
  }

  void _applyJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final raw = data['days'] as List;
      final days = raw.map((e) {
        final parts = (e['date'] as String).split('-');
        return _DayStat(
          date: DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
          kcal: (e['kcal'] as num).toInt(),
        );
      }).toList();
      _applyList(days);
    } catch (_) {}
  }

  void _applyList(List<_DayStat> days) {
    _days = days;
    _hasAnyLog = days.any((d) => d.kcal > 0);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _fmtKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    if (_days == null) {
      return _Skeleton();
    }

    if (!_hasAnyLog) {
      return _EmptyState(primary: primary, palette: palette, t: t, l10n: l10n);
    }

    return RepaintBoundary(
      child: AppGlassCard(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.md.w, AppSpacing.md.h, AppSpacing.md.w, AppSpacing.md.h),
        child: _Content(
          days: _days!,
          calorieTarget: widget.calorieTarget,
          primary: primary,
          palette: palette,
          t: t,
          l10n: l10n,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  final List<_DayStat> days;
  final int calorieTarget;
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _Content({
    required this.days,
    required this.calorieTarget,
    required this.primary,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Stats
    final logged = days.where((d) => d.kcal > 0).toList();
    final avgKcal = logged.isEmpty
        ? 0
        : (logged.fold(0, (s, d) => s + d.kcal) ~/ logged.length);
    final maxKcal = days.fold(0, (m, d) => d.kcal > m ? d.kcal : m);
    // Effective ceiling for bar heights: max of actual, target (so bars never overflow).
    final ceiling = [maxKcal, calorieTarget, 1].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                l10n.translate('home.recap.title'),
                style: t.titleM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full.r),
              ),
              child: Text(
                l10n.translate('home.recap.days_logged',
                    variables: {'count': '${logged.length}'}),
                style: t.labelS
                    .copyWith(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        // ── Sparkline ─────────────────────────────────────────────────────────
        SizedBox(
          height: 72.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((day) {
              final isToday = day.date == todayOnly;
              final ratio = day.kcal / ceiling;
              // Min visible height for "has data" days so 1 kcal != invisible.
              final barRatio = day.kcal > 0 ? ratio.clamp(0.06, 1.0) : 0.0;
              final barColor = isToday
                  ? primary
                  : day.kcal > 0
                      ? primary.withValues(alpha: 0.38)
                      : palette.border.withValues(alpha: 0.25);

              final dayLabel =
                  DateFormat('E', locale).format(day.date).substring(0, 2);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Bar
                      AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: Curves.easeOut,
                        width: double.infinity,
                        height: 52.h * barRatio,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(3.r)),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      // Day label
                      Text(
                        isToday
                            ? l10n.translate('home.recap.today_short')
                            : dayLabel,
                        style: t.labelS.copyWith(
                          color: isToday ? primary : palette.textTertiary,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 9.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Target line separator ─────────────────────────────────────────────
        if (calorieTarget > 0)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: palette.border.withValues(alpha: 0.5),
                    thickness: 0.5,
                    height: 0,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(height: 10.h),

        // ── Stat row ──────────────────────────────────────────────────────────
        Wrap(
          spacing: 12.w,
          runSpacing: 6.h,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Stat(
              icon: Icons.local_fire_department_rounded,
              color: primary,
              label: l10n.translate('home.recap.avg'),
              value: '$avgKcal kcal',
              t: t,
              palette: palette,
            ),
            if (calorieTarget > 0)
              _Stat(
                icon: Icons.flag_rounded,
                color: palette.success,
                label: l10n.translate('home.recap.target'),
                value: '$calorieTarget kcal',
                t: t,
                palette: palette,
              ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final AppText t;
  final AppPalette palette;

  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.t,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: color),
        SizedBox(width: 4.w),
        Text(
          '$label ',
          style: t.labelS.copyWith(color: palette.textTertiary),
        ),
        Text(
          value,
          style: t.labelS.copyWith(
              color: palette.textSecondary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty + Skeleton states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _EmptyState({
    required this.primary,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Row(
        children: [
          Text('📊', style: TextStyle(fontSize: 28.sp)),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('home.recap.empty_title'),
                  style: t.titleM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  l10n.translate('home.recap.empty_subtitle'),
                  style: t.bodyM.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSkeletonBox(
      width: double.infinity,
      height: 140.h,
      radius: AppRadius.card.r,
    );
  }
}
