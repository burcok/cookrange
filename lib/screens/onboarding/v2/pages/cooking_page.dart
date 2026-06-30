import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/onboarding_options.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 9 — cooking skill (single) + kitchen equipment (multi). Reuses the
/// existing [OnboardingOptions] sets so recipes match the user's setup.
class OnboardingCookingPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingCookingPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  static const Map<String, IconData> _equipmentIcons = {
    'stove': Icons.local_fire_department_rounded,
    'oven': Icons.microwave_rounded,
    'microwave': Icons.kitchen_rounded,
    'pressure_cooker': Icons.soup_kitchen_rounded,
    'electric_kettle': Icons.coffee_maker_rounded,
    'coffee_maker': Icons.coffee_rounded,
    'grinder': Icons.blender_rounded,
    'toaster': Icons.bakery_dining_rounded,
    'blender': Icons.blender_rounded,
    'hand_mixer': Icons.kitchen_rounded,
    'stand_mixer': Icons.kitchen_rounded,
    'air_fryer': Icons.air_rounded,
    'electric_grill': Icons.outdoor_grill_rounded,
    'samovar': Icons.emoji_food_beverage_rounded,
    'turkish_coffee_pot': Icons.coffee_rounded,
    'tea_pot': Icons.emoji_food_beverage_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';
    final selectedLevel = ob.cookingLevel?['value'] as String?;
    final selectedEquip =
        ob.kitchenEquipment.map((e) => e['value'] as String).toSet();
    final valid = selectedLevel != null && selectedEquip.isNotEmpty;

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: valid ? onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.cooking.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.cooking.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          OnboardingGroupLabel(
              title: l10n.translate('onboarding.v2.cooking.level_title')),
          SizedBox(height: AppSpacing.sm.h),
          ...OnboardingOptions.cookingLevels.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: OnboardingChoiceCard(
                  icon: e.value['icon'] as IconData,
                  title: l10n.translate(e.value['label'] as String),
                  selected: selectedLevel == e.key,
                  onTap: () =>
                      context.read<OnboardingProvider>().setCookingLevel(e.key),
                ),
              )),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
            title: l10n.translate('onboarding.v2.cooking.equipment_title'),
            trailing: l10n.translate('onboarding.v2.cooking.equipment_count',
                variables: {'count': selectedEquip.length.toString()}),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: OnboardingOptions.kitchenEquipment.entries
                .map((e) => OnboardingChoiceChip(
                      icon: _equipmentIcons[e.key] ?? Icons.kitchen_rounded,
                      label: l10n.translate(e.value),
                      selected: selectedEquip.contains(e.key),
                      onTap: () => context
                          .read<OnboardingProvider>()
                          .toggleKitchenEquipment(e.key),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
