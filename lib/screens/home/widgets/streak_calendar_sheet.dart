import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/food_log_service.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ds/app_sheet.dart';
import '../../../core/widgets/ds/app_shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Streak Chip — tappable badge with periodic shimmer glint
// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in replacement for the inline streak chip in the welcome header.
///
/// Interactivity hint: every ~4 s a light shimmer sweeps left→right across
/// the chip (like an iOS button glint). The chip container never moves or
/// changes size — zero layout impact, zero overflow risk.
class StreakChip extends StatefulWidget {
  final int streak;
  final UserModel userModel;

  const StreakChip({
    super.key,
    required this.streak,
    required this.userModel,
  });

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  /// 0.0 → 1.0: shimmer peak moves from left edge to right edge.
  late final Animation<double> _glint;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      // Sweep takes 900 ms; easeInOut makes it accelerate then decelerate
      // so the peak spends longer in the middle — feels more natural.
      duration: const Duration(milliseconds: 900),
    );
    _glint = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  Future<void> _loop() async {
    while (mounted) {
      // Pause between sweeps: 3.5 s idle → one glint → reset.
      await Future.delayed(const Duration(milliseconds: 3500));
      if (!mounted) break;
      if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations) {
        continue;
      }
      await _ctl.forward();
      _ctl.reset(); // instant reset; no reverse — glint passes once and vanishes.
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(AppRadius.full.r);

    // The chip content — built once and passed as `child` to AnimatedBuilder
    // so Flutter doesn't rebuild the whole subtree on every animation tick.
    final chipContent = Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 15)),
          SizedBox(width: AppSpacing.xxs.w),
          Text(
            l10n.translate('home.streak_days',
                variables: {'count': '${widget.streak}'}),
            style:
                t.labelM.copyWith(fontWeight: FontWeight.bold, color: primary),
          ),
          if (widget.userModel.streakFreezeCount > 0) ...[
            SizedBox(width: AppSpacing.xs.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: palette.info.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.xs.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ac_unit_rounded, size: 10.sp, color: palette.info),
                  SizedBox(width: 2.w),
                  Text(
                    '${widget.userModel.streakFreezeCount}',
                    style: t.labelS.copyWith(
                      color: palette.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => StreakCalendarSheet.show(
        context,
        uid: widget.userModel.uid,
        streak: widget.streak,
        freezeCount: widget.userModel.streakFreezeCount,
      ),
      child: Padding(
        // Margin lives here, outside ClipRRect, so the clip doesn't eat it.
        padding: EdgeInsets.only(top: AppSpacing.xxs.h),
        child: AnimatedBuilder(
          animation: _glint,
          builder: (_, child) {
            // t drives the peak position of the glint: 0 = fully left, 1 = fully right.
            // A half-width band (±0.18) sweeps across, invisible when outside [0,1].
            final t = _glint.value;
            return ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  child!, // the static chip
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0x28FFFFFF), // ~16% white at peak
                              Color(0x00FFFFFF),
                            ],
                            stops: [
                              (t - 0.18).clamp(0.0, 1.0),
                              t.clamp(0.0, 1.0),
                              (t + 0.18).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: chipContent,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak Calendar Sheet
// ─────────────────────────────────────────────────────────────────────────────

class StreakCalendarSheet extends StatefulWidget {
  final String uid;
  final int streak;
  final int freezeCount;

  const StreakCalendarSheet({
    super.key,
    required this.uid,
    required this.streak,
    required this.freezeCount,
  });

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required int streak,
    required int freezeCount,
  }) {
    return AppSheet.show(
      context: context,
      title:
          AppLocalizations.of(context).translate('home.streak_calendar_title'),
      child: StreakCalendarSheet(
        uid: uid,
        streak: streak,
        freezeCount: freezeCount,
      ),
    );
  }

  @override
  State<StreakCalendarSheet> createState() => _StreakCalendarSheetState();
}

class _StreakCalendarSheetState extends State<StreakCalendarSheet> {
  late DateTime _month; // First day of displayed month
  Set<String> _logged = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    // Prefetch 3 months: current + 2 prior — navigation stays instant.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 2);
    final end = DateTime(now.year, now.month + 1, 0);
    try {
      final map =
          await FoodLogService().getLogsForDateRange(widget.uid, start, end);
      final days = <String>{};
      for (final e in map.entries) {
        if (e.value.isNotEmpty) days.add(e.key);
      }
      if (mounted)
        setState(() {
          _logged = days;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Clamp navigation so we can't go into the future.
  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() {
    final candidate = DateTime(_month.year, _month.month + 1);
    final now = DateTime.now();
    if (!candidate.isAfter(DateTime(now.year, now.month))) {
      setState(() => _month = candidate);
    }
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.xl.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Streak headline ──────────────────────────────────────────────
          _StreakHeader(
              streak: widget.streak,
              freezeCount: widget.freezeCount,
              primary: primary,
              palette: palette,
              t: t,
              l10n: l10n),
          SizedBox(height: 20.h),

          // ── Month navigator ──────────────────────────────────────────────
          _MonthBar(
            month: _month,
            canGoNext: _canGoNext,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            primary: primary,
            palette: palette,
            t: t,
          ),
          SizedBox(height: 10.h),

          // ── Calendar grid ────────────────────────────────────────────────
          _loading
              ? _CalSkeleton()
              : _CalGrid(
                  month: _month,
                  logged: _logged,
                  primary: primary,
                  palette: palette,
                  t: t,
                ),
          SizedBox(height: 14.h),

          // ── Legend ───────────────────────────────────────────────────────
          _Legend(primary: primary, palette: palette, t: t, l10n: l10n),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StreakHeader extends StatelessWidget {
  final int streak;
  final int freezeCount;
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _StreakHeader({
    required this.streak,
    required this.freezeCount,
    required this.primary,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: AppSpacing.md.h, horizontal: AppSpacing.lg.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.04)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔥', style: TextStyle(fontSize: 36.sp)),
          SizedBox(width: AppSpacing.sm.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak',
                style: t.displayM.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                l10n.translate('home.streak_calendar_label'),
                style: t.bodyM.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (freezeCount > 0) ...[
            const Spacer(),
            Column(
              children: [
                Text('❄️', style: TextStyle(fontSize: 22.sp)),
                Text(
                  '$freezeCount',
                  style: t.labelM.copyWith(
                    color: palette.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color primary;
  final AppPalette palette;
  final AppText t;

  const _MonthBar({
    required this.month,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.primary,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final label = DateFormat('MMMM yyyy', locale).format(month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavBtn(
            icon: Icons.chevron_left_rounded, onTap: onPrev, palette: palette),
        Text(
          _capitalize(label),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        _NavBtn(
          icon: Icons.chevron_right_rounded,
          onTap: canGoNext ? onNext : null,
          palette: palette,
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final AppPalette palette;

  const _NavBtn(
      {required this.icon, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: onTap != null
              ? palette.surfaceVariant
              : palette.surfaceVariant.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20.r,
          color: onTap != null ? palette.textPrimary : palette.textTertiary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _CalGrid extends StatelessWidget {
  final DateTime month;
  final Set<String> logged;
  final Color primary;
  final AppPalette palette;
  final AppText t;

  const _CalGrid({
    required this.month,
    required this.logged,
    required this.primary,
    required this.palette,
    required this.t,
  });

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // Monday reference: 2024-01-01 is a Monday (month/day omitted — default to 1).
    final monday = DateTime.utc(2024);
    final headers = List.generate(7,
        (i) => DateFormat('EEE', locale).format(monday.add(Duration(days: i))));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-based offset: Monday=0 ... Sunday=6
    final offset = firstOfMonth.weekday - 1;
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Day-of-week header row
        Row(
          children: headers
              .map((h) => Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: t.labelS.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: 6.h),
        // Calendar rows
        for (int row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final dayNum = idx - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final date = DateTime(month.year, month.month, dayNum);
              final dateKey = _key(date);
              final isLogged = logged.contains(dateKey);
              final isToday = date == today;
              final isFuture = date.isAfter(today);

              final prevKey = _key(date.subtract(const Duration(days: 1)));
              final nextKey = _key(date.add(const Duration(days: 1)));
              // Chain bars connect adjacent logged cells within the same row.
              final chainLeft =
                  isLogged && logged.contains(prevKey) && col != 0;
              final chainRight =
                  isLogged && logged.contains(nextKey) && col != 6 && !isFuture;

              return Expanded(
                child: _DayCell(
                  day: dayNum,
                  isLogged: isLogged,
                  isToday: isToday,
                  isFuture: isFuture,
                  chainLeft: chainLeft,
                  chainRight: chainRight,
                  primary: primary,
                  palette: palette,
                  t: t,
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isLogged;
  final bool isToday;
  final bool isFuture;
  final bool chainLeft;
  final bool chainRight;
  final Color primary;
  final AppPalette palette;
  final AppText t;

  const _DayCell({
    required this.day,
    required this.isLogged,
    required this.isToday,
    required this.isFuture,
    required this.chainLeft,
    required this.chainRight,
    required this.primary,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    const cellH = 44.0;
    final circleD = 32.0.r;
    final barH = 14.0.r;
    final chainColor = primary.withValues(alpha: 0.18);

    final textColor = isLogged
        ? Colors.white
        : isFuture
            ? palette.textTertiary.withValues(alpha: 0.4)
            : isToday
                ? primary
                : palette.textSecondary;

    return SizedBox(
      height: cellH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chain bars behind the circle
          if (isLogged && (chainLeft || chainRight))
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: barH,
                    color: chainLeft ? chainColor : Colors.transparent,
                  ),
                ),
                SizedBox(width: circleD),
                Expanded(
                  child: Container(
                    height: barH,
                    color: chainRight ? chainColor : Colors.transparent,
                  ),
                ),
              ],
            ),
          // Circle (logged = filled, today not logged = outlined)
          if (isLogged || isToday)
            Container(
              width: circleD,
              height: circleD,
              decoration: BoxDecoration(
                color: isLogged ? primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isLogged
                    ? Border.all(color: primary, width: 1.5.r)
                    : null,
              ),
            ),
          // Day number
          Text(
            '$day',
            style: t.labelM.copyWith(
              color: textColor,
              fontWeight:
                  (isToday || isLogged) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color primary;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _Legend({
    required this.primary,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: primary, filled: true),
        SizedBox(width: 5.w),
        Text(l10n.translate('home.streak_calendar_logged'),
            style: t.labelS.copyWith(color: palette.textSecondary)),
        SizedBox(width: 16.w),
        _LegendDot(color: primary, filled: false),
        SizedBox(width: 5.w),
        Text(l10n.translate('home.streak_calendar_today'),
            style: t.labelS.copyWith(color: palette.textSecondary)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool filled;

  const _LegendDot({required this.color, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton for the calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _CalSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row skeleton
        Row(
          children: List.generate(
            7,
            (_) => Expanded(
              child: Center(
                child: AppSkeletonBox(
                    width: 20.w, height: 10.h, radius: AppRadius.xs.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 6.h),
        for (int r = 0; r < 5; r++)
          Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              children: List.generate(
                7,
                (_) => Expanded(
                  child: Center(
                    child: AppSkeletonBox(
                      width: 32.w,
                      height: 32.h,
                      radius: 16.r,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
