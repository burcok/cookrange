import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/onboarding_options.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 10 — lifestyle profile + adaptive meal schedule. Mirrors the legacy
/// flow's logic (fixed / irregular / rotating) in the V2 design.
class OnboardingLifestylePage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingLifestylePage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  static const Map<String, IconData> _icons = {
    'early_bird': Icons.wb_sunny_rounded,
    'worker': Icons.work_outline_rounded,
    'night_owl': Icons.nightlight_round,
    'rotating_shifts': Icons.sync_rounded,
    'irregular_schedule': Icons.shuffle_rounded,
  };

  void _select(BuildContext context, String key) {
    final ob = context.read<OnboardingProvider>();
    ob.setLifestyleProfile(key);
    if (key == 'rotating_shifts') {
      ob.setScheduleType('rotating');
    } else if (key == 'irregular_schedule') {
      ob.setScheduleType('irregular');
    } else {
      final times = (OnboardingOptions.lifestyleProfiles[key]?['mealTimes']
              as List?)
          ?.cast<String>();
      ob.setScheduleType('fixed', mealTimes: times);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';
    final selected = ob.lifestyleProfile?['value'] as String?;
    final scheduleType = ob.mealSchedule?['schedule_type'] as String?;

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: selected != null ? onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.lifestyle.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.lifestyle.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          ...OnboardingOptions.lifestyleProfiles.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: OnboardingChoiceCard(
                  icon: _icons[e.key] ?? Icons.schedule_rounded,
                  title: l10n.translate(e.value['label'] as String),
                  subtitle: l10n.translate(
                      'onboarding.page5.profiles.${e.key}.description'),
                  selected: selected == e.key,
                  onTap: () => _select(context, e.key),
                ),
              )),
          if (selected != null) ...[
            SizedBox(height: AppSpacing.lg.h),
            if (scheduleType == 'rotating')
              _RotatingEditor(schedule: ob.mealSchedule ?? {})
            else
              _FixedEditor(schedule: ob.mealSchedule ?? {}),
          ],
        ],
      ),
    );
  }
}

const _meals = [
  ('breakfast', Icons.free_breakfast_rounded),
  ('lunch', Icons.lunch_dining_rounded),
  ('dinner', Icons.dinner_dining_rounded),
];

class _FixedEditor extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const _FixedEditor({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _meals
          .map((m) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: _TimeRow(
                  mealKey: m.$1,
                  icon: m.$2,
                  time: (schedule[m.$1] as String?) ?? '--:--',
                ),
              ))
          .toList(),
    );
  }
}

class _RotatingEditor extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const _RotatingEditor({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final weeks = (schedule['rotation_weeks'] as int?) ?? 2;
    final shifts = (schedule['shifts'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: List.generate(3, (i) {
              final w = i + 2;
              final on = w == weeks;
              return Expanded(
                child: GestureDetector(
                  onTap: () => context
                      .read<OnboardingProvider>()
                      .updateRotationWeeks(w),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                    decoration: BoxDecoration(
                      color: on ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$w ${l10n.translate('onboarding.page5.schedule_editor.rotating.week_short')}',
                      style: t.labelM.copyWith(
                        color: on ? palette.textInverse : palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
        ...List.generate(weeks, (i) {
          final week = i + 1;
          final shift = shifts.firstWhere(
            (s) => s['week'] == week,
            orElse: () =>
                {'breakfast': '07:00', 'lunch': '12:00', 'dinner': '18:00'},
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                child: Text(
                  '${l10n.translate('onboarding.page5.schedule_editor.rotating.week')} $week',
                  style: t.headlineS.copyWith(color: palette.textPrimary),
                ),
              ),
              ..._meals.map((m) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                    child: _TimeRow(
                      mealKey: m.$1,
                      icon: m.$2,
                      time: (shift[m.$1] as String?) ?? '--:--',
                      week: week,
                    ),
                  )),
            ],
          );
        }),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String mealKey;
  final IconData icon;
  final String time;
  final int? week;
  const _TimeRow({
    required this.mealKey,
    required this.icon,
    required this.time,
    this.week,
  });

  Future<void> _edit(BuildContext context) async {
    final parts = time.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && context.mounted) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      context
          .read<OnboardingProvider>()
          .updateMealTime(mealKey, '$hh:$mm', week: week);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _edit(context),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSize.iconMd.r, color: palette.textSecondary),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Text(
                l10n.translate('onboarding.page5.preview.$mealKey'),
                style: t.titleM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Text(time,
                  style: t.labelL
                      .copyWith(color: primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
