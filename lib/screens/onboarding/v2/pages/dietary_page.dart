import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/onboarding_options.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 8 — allergies, dietary preferences, and a searchable "foods to skip"
/// picker (predefined + free-text custom). All optional; everything selected
/// here is excluded from generated plans.
class OnboardingDietaryPage extends StatefulWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingDietaryPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingDietaryPage> createState() => _OnboardingDietaryPageState();
}

class _OnboardingDietaryPageState extends State<OnboardingDietaryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';

    final selectedAllergies = ob.allergyIds.toSet();
    final selectedDiet = ob.dietaryRestrictionIds.toSet();
    final dislikedValues =
        ob.dislikedFoods.map((f) => f['value'] as String).toSet();

    // Filter predefined ingredients by translated label against the query.
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? <MapEntry<String, Map<String, dynamic>>>[]
        : OnboardingOptions.predefinedIngredients.entries
            .where((e) {
              final label =
                  l10n.translate(e.value['label'] as String).toLowerCase();
              return label.contains(q) && !dislikedValues.contains(e.key);
            })
            .take(12)
            .toList();
    final hasExact = q.isNotEmpty &&
        OnboardingOptions.predefinedIngredients.entries.any((e) =>
            l10n.translate(e.value['label'] as String).toLowerCase() == q);

    return OnboardingScaffold(
      progress: (widget.step + 1) / widget.totalSteps,
      onBack: widget.onBack,
      onContinue: widget.onNext,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.dietary.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.dietary.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          OnboardingGroupLabel(
              title: l10n.translate('onboarding.v2.dietary.allergies_title')),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: OnboardingOptions.allergies.entries
                .map((e) => OnboardingChoiceChip(
                      icon: e.value['icon'] as IconData,
                      label: l10n.translate(e.value['label'] as String),
                      selected: selectedAllergies.contains(e.key),
                      selectedColor: palette.warning,
                      onTap: () => context
                          .read<OnboardingProvider>()
                          .toggleAllergy(e.key),
                    ))
                .toList(),
          ),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
              title:
                  l10n.translate('onboarding.v2.dietary.restrictions_title')),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: OnboardingOptions.dietaryRestrictions.entries
                .map((e) => OnboardingChoiceChip(
                      icon: e.value['icon'] as IconData,
                      label: l10n.translate(e.value['label'] as String),
                      selected: selectedDiet.contains(e.key),
                      onTap: () => context
                          .read<OnboardingProvider>()
                          .toggleDietaryRestriction(e.key),
                    ))
                .toList(),
          ),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
              title: l10n.translate('onboarding.v2.dietary.dislikes_title')),
          SizedBox(height: AppSpacing.sm.h),
          if (ob.dislikedFoods.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm.w,
              runSpacing: AppSpacing.sm.h,
              children: ob.dislikedFoods
                  .map((f) => OnboardingChoiceChip(
                        icon: Icons.close_rounded,
                        label: f['label'] as String,
                        selected: true,
                        selectedColor: palette.error,
                        onTap: () => context
                            .read<OnboardingProvider>()
                            .toggleDislikedFood(f),
                      ))
                  .toList(),
            ),
            SizedBox(height: AppSpacing.md.h),
          ],
          AppTextField(
            controller: _searchCtrl,
            hintText: l10n.translate('onboarding.v2.dietary.dislikes_hint'),
            prefixIcon: Icon(Icons.search_rounded,
                color: palette.textTertiary, size: AppSize.iconMd.r),
            onChanged: (v) => setState(() => _query = v),
          ),
          if (q.isNotEmpty) ...[
            SizedBox(height: AppSpacing.md.h),
            Wrap(
              spacing: AppSpacing.sm.w,
              runSpacing: AppSpacing.sm.h,
              children: [
                if (!hasExact)
                  OnboardingChoiceChip(
                    icon: Icons.add_rounded,
                    label: l10n.translate('onboarding.v2.dietary.add_custom',
                        variables: {'q': _query.trim()}),
                    selected: false,
                    onTap: () {
                      final value =
                          _query.trim().toLowerCase().replaceAll(' ', '_');
                      context.read<OnboardingProvider>().toggleDislikedFood(
                          {'value': value, 'label': _query.trim()});
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                ...matches.map((e) => OnboardingChoiceChip(
                      icon: e.value['icon'] as IconData,
                      label: l10n.translate(e.value['label'] as String),
                      selected: false,
                      onTap: () {
                        context.read<OnboardingProvider>().toggleDislikedFood({
                          'value': e.key,
                          'label': l10n.translate(e.value['label'] as String),
                        });
                      },
                    )),
              ],
            ),
          ],
          SizedBox(height: AppSpacing.lg.h),
          OnboardingInfoNote(
              text: l10n.translate('onboarding.v2.dietary.optional_note')),
        ],
      ),
    );
  }
}
