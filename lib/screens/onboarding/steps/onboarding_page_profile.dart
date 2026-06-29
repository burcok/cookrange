import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/utils/age_gate.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../widgets/date_picker_modal.dart';
import '../../../widgets/number_picker_modal.dart';
import '../../../widgets/onboarding_common_widgets.dart';

class OnboardingPageProfile extends StatelessWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingPageProfile({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final onboarding = Provider.of<OnboardingProvider>(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          OnboardingHeader(
            title: localizations.translate('onboarding.profile.title'),
            currentStep: step + 1,
            totalSteps: 6,
            previousStep: previousStep,
            onBackButtonPressed: onBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  OnboardingSection(
                    title: localizations
                        .translate('onboarding.profile.genderTitle'),
                    subtitle: localizations
                        .translate('onboarding.profile.genderSubtitle'),
                    options: [
                      OptionData(
                        label:
                            localizations.translate('onboarding.profile.male'),
                        icon: Icons.male,
                        value: 'Male',
                      ),
                      OptionData(
                        label: localizations
                            .translate('onboarding.profile.female'),
                        icon: Icons.female,
                        value: 'Female',
                      ),
                      OptionData(
                        label: localizations
                            .translate('onboarding.profile.preferNotToSay'),
                        icon: Icons.not_interested,
                        value: 'Prefer not to say',
                      ),
                    ],
                    selectedValue: onboarding.gender,
                    onSelectionChanged: (value) => onboarding.setGender(value),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context,
                      title: localizations
                          .translate('onboarding.profile.birthdayTitle'),
                      subtitle: localizations
                          .translate('onboarding.profile.birthdaySubtitle')),
                  const SizedBox(height: 16),
                  _buildBirthDateSelector(context, onboarding),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context,
                      title:
                          localizations.translate('onboarding.profile.hwTitle'),
                      subtitle: localizations
                          .translate('onboarding.profile.hwSubtitle')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child:
                              _buildWeightSelector(context, onboarding)),
                      const SizedBox(width: 16),
                      Expanded(
                          child:
                              _buildHeightSelector(context, onboarding)),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: OnboardingContinueButton(
        onPressed: isLoadingNotifier.value ? null : onNext,
        text: localizations.translate('onboarding.continue'),
        isLoadingNotifier: isLoadingNotifier,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title, required String subtitle}) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: t.headlineS.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: t.bodyM.copyWith(color: palette.textSecondary)),
      ],
    );
  }

  Widget _buildBirthDateSelector(
      BuildContext context, OnboardingProvider onboarding) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return InkWell(
      onTap: () => _showDatePicker(context, onboarding),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              onboarding.birthDate != null
                  ? DateFormat('dd.MM.yyyy').format(onboarding.birthDate!)
                  : localizations.translate('onboarding.profile.selectDate'),
              style: t.bodyL.copyWith(color: palette.textPrimary),
            ),
            Icon(Icons.calendar_today_outlined,
                color: palette.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightSelector(
      BuildContext context, OnboardingProvider onboarding) {
    return _buildNumberSelector(
      context: context,
      value: onboarding.height,
      unit: 'CM',
      onTap: () => _showNumberPicker(
        context,
        onboarding,
        'height',
        min: 120,
        max: 220,
        initialValue: onboarding.height ?? 170,
        unit: 'cm',
        title: AppLocalizations.of(context)
            .translate('onboarding.profile.heightTitle'),
      ),
    );
  }

  Widget _buildWeightSelector(
      BuildContext context, OnboardingProvider onboarding) {
    return _buildNumberSelector(
      context: context,
      value: onboarding.weight,
      unit: 'KG',
      onTap: () => _showNumberPicker(
        context,
        onboarding,
        'weight',
        min: 30,
        max: 200,
        initialValue: onboarding.weight ?? 70,
        unit: 'kg',
        title: AppLocalizations.of(context)
            .translate('onboarding.profile.weightTitle'),
      ),
    );
  }

  Widget _buildNumberSelector({
    required BuildContext context,
    required int? value,
    required String unit,
    required VoidCallback onTap,
  }) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null
                  ? '$value$unit'
                  : AppLocalizations.of(context).translate('common.select'),
              style: t.bodyL.copyWith(color: palette.textPrimary),
            ),
            Icon(Icons.unfold_more, color: palette.textPrimary),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, OnboardingProvider onboarding) {
    // Age gate (KVKK/GDPR children's data): the picker cannot select a date
    // younger than the minimum age, and we re-check defensively on selection.
    final maxBirth = AgeGate.maxAllowedBirthDate();
    final initial = onboarding.birthDate ??
        (DateTime(2005, 9, 3).isAfter(maxBirth) ? maxBirth : DateTime(2005, 9, 3));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DatePickerModal(
        initialDate: initial,
        minDate: DateTime(1920),
        maxDate: maxBirth,
        onSelected: (date) {
          if (AgeGate.isUnderMinimumAge(date)) {
            AppSnackBar.warning(
              context,
              AppLocalizations.of(context).translate('onboarding.age_gate'),
            );
            return;
          }
          onboarding.setBirthDate(date);
        },
      ),
    );
  }

  void _showNumberPicker(
      BuildContext context, OnboardingProvider onboarding, String field,
      {required int min,
      required int max,
      required int initialValue,
      required String unit,
      required String title}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => NumberPickerModal(
        title: title,
        min: min,
        max: max,
        initialValue: initialValue,
        unit: unit,
      ),
    ).then((value) {
      if (value != null) {
        if (field == 'height') {
          onboarding.setHeight(value);
        } else if (field == 'weight') {
          onboarding.setWeight(value);
        }
      }
    });
  }
}
