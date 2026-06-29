import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/onboarding_projection_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 11 — hydration: a recommended daily target (from body + activity) and
/// an optional daily reminder. Enabling requests notification permission; the
/// actual local schedule is set after registration.
class OnboardingWaterPage extends StatefulWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingWaterPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingWaterPage> createState() => _OnboardingWaterPageState();
}

class _OnboardingWaterPageState extends State<OnboardingWaterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ob = context.read<OnboardingProvider>();
      if (ob.waterDailyTargetMl == null && ob.weight != null) {
        ob.setWaterReminder(
          enabled: ob.waterReminderEnabled,
          targetMl: OnboardingProjectionService.recommendedWaterMl(
            weightKg: ob.weight!,
            activityLevel: ob.activityLevel?['value'] as String?,
          ),
        );
      }
    });
  }

  Future<void> _toggle(bool value) async {
    final ob = context.read<OnboardingProvider>();
    if (value) {
      final granted = await PermissionService().requestNotifications(context);
      if (!mounted) return;
      ob.setWaterReminder(enabled: granted);
    } else {
      ob.setWaterReminder(enabled: false);
    }
  }

  Future<void> _pickTime(bool isWake) async {
    final ob = context.read<OnboardingProvider>();
    final current = isWake ? ob.waterWakeTime : ob.waterSleepTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (picked != null && mounted) {
      final v =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ob.setWaterReminder(
        enabled: ob.waterReminderEnabled,
        wake: isWake ? v : null,
        sleep: isWake ? null : v,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';
    final target = ob.waterDailyTargetMl ??
        (ob.weight != null
            ? OnboardingProjectionService.recommendedWaterMl(
                weightKg: ob.weight!,
                activityLevel: ob.activityLevel?['value'] as String?)
            : 2000);
    final liters = (target / 1000).toStringAsFixed(1);

    return OnboardingScaffold(
      progress: (widget.step + 1) / widget.totalSteps,
      onBack: widget.onBack,
      onContinue: widget.onNext,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.water.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.water.subtitle'),
          ),
          SizedBox(height: AppSpacing.xl.h),
          // Target hero
          Center(
            child: Column(
              children: [
                Container(
                  width: 96.r,
                  height: 96.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      palette.info.withValues(alpha: 0.18),
                      palette.info.withValues(alpha: 0.02),
                    ]),
                  ),
                  child: Icon(Icons.water_drop_rounded,
                      size: 44.sp, color: palette.info),
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(l10n.translate('onboarding.v2.water.recommended'),
                    style: t.labelM.copyWith(color: palette.textTertiary)),
                SizedBox(height: AppSpacing.xxs.h),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: '$liters ',
                        style: t.displayM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: 'L  ·  $target ${l10n.translate('onboarding.v2.units.ml')}',
                        style:
                            t.titleM.copyWith(color: palette.textSecondary)),
                  ]),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
          // Reminder toggle
          AppCard(
            bordered: true,
            elevated: false,
            padding: EdgeInsets.all(AppSpacing.md.r),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        color: primary, size: AppSize.iconMd.r),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              l10n.translate(
                                  'onboarding.v2.water.reminder_title'),
                              style: t.titleM.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2.h),
                          Text(
                              l10n.translate(
                                  'onboarding.v2.water.reminder_subtitle'),
                              style: t.labelM
                                  .copyWith(color: palette.textSecondary)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: ob.waterReminderEnabled,
                      activeThumbColor: primary,
                      onChanged: _toggle,
                    ),
                  ],
                ),
                if (ob.waterReminderEnabled) ...[
                  Divider(height: AppSpacing.lg.h, color: palette.divider),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: l10n.translate('onboarding.v2.water.wake'),
                          time: ob.waterWakeTime,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                      Expanded(
                        child: _TimeField(
                          label: l10n.translate('onboarding.v2.water.sleep'),
                          time: ob.waterSleepTime,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          OnboardingInfoNote(
              text: l10n.translate('onboarding.v2.water.disclaimer')),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _TimeField(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w, vertical: AppSpacing.sm.h),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: t.labelS.copyWith(color: palette.textTertiary)),
            SizedBox(height: 2.h),
            Text(time,
                style: t.titleM.copyWith(
                    color: primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
