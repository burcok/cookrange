import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/utils/age_gate.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../widgets/number_picker_modal.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 4 — body metrics: age, height, weight. Age is captured directly and
/// stored as a derived birth date (so [AgeGate] still enforces the minimum
/// age). Height + weight feed BMI, calorie, and water calculations.
class OnboardingMetricsPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingMetricsPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  Future<void> _pickAge(BuildContext context, OnboardingProvider ob) async {
    final current = ob.ageYears ?? 25;
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => NumberPickerModal(
        title: AppLocalizations.of(context)
            .translate('onboarding.v2.metrics.age_label'),
        min: AgeGate.kMinimumAgeYears,
        max: 100,
        initialValue: current.clamp(AgeGate.kMinimumAgeYears, 100),
        unit:
            AppLocalizations.of(context).translate('onboarding.v2.units.years'),
      ),
    );
    if (result != null) {
      final now = DateTime.now();
      ob.setBirthDate(DateTime(now.year - result, now.month, now.day));
    }
  }

  Future<void> _pickNumber(
    BuildContext context,
    OnboardingProvider ob, {
    required String title,
    required int min,
    required int max,
    required int initial,
    required String unit,
    required void Function(int) onSet,
  }) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => NumberPickerModal(
          title: title, min: min, max: max, initialValue: initial, unit: unit),
    );
    if (result != null) onSet(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';
    final age = ob.ageYears;
    final valid =
        ob.birthDate != null && ob.height != null && ob.weight != null;
    final select = l10n.translate('common.select');

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: valid ? onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.metrics.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.metrics.subtitle'),
          ),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingMetricTile(
            label: l10n.translate('onboarding.v2.metrics.age_label'),
            value: age != null
                ? '$age ${l10n.translate('onboarding.v2.units.years')}'
                : select,
            filled: age != null,
            icon: Icons.cake_outlined,
            onTap: () => _pickAge(context, context.read<OnboardingProvider>()),
          ),
          SizedBox(height: AppSpacing.md.h),
          OnboardingMetricTile(
            label: l10n.translate('onboarding.v2.metrics.height_label'),
            value: ob.height != null
                ? '${ob.height} ${l10n.translate('onboarding.v2.units.cm')}'
                : select,
            filled: ob.height != null,
            icon: Icons.straighten_rounded,
            onTap: () => _pickNumber(
              context,
              context.read<OnboardingProvider>(),
              title: l10n.translate('onboarding.v2.metrics.height_label'),
              min: 120,
              max: 220,
              initial: ob.height ?? 170,
              unit: l10n.translate('onboarding.v2.units.cm'),
              onSet: (v) => context.read<OnboardingProvider>().setHeight(v),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          OnboardingMetricTile(
            label: l10n.translate('onboarding.v2.metrics.weight_label'),
            value: ob.weight != null
                ? '${ob.weight} ${l10n.translate('onboarding.v2.units.kg')}'
                : select,
            filled: ob.weight != null,
            icon: Icons.monitor_weight_outlined,
            onTap: () => _pickNumber(
              context,
              context.read<OnboardingProvider>(),
              title: l10n.translate('onboarding.v2.metrics.weight_label'),
              min: 30,
              max: 250,
              initial: ob.weight ?? 70,
              unit: l10n.translate('onboarding.v2.units.kg'),
              onSet: (v) => context.read<OnboardingProvider>().setWeight(v),
            ),
          ),
        ],
      ),
    );
  }
}
