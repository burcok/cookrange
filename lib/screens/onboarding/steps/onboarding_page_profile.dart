import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/theme/app_theme.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.backgroundColor2,
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
                  _buildBirthDateSelector(context, onboarding, theme),
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
                              _buildWeightSelector(context, onboarding, theme)),
                      const SizedBox(width: 16),
                      Expanded(
                          child:
                              _buildHeightSelector(context, onboarding, theme)),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onboardingTitleColor,
              fontFamily: 'Poppins',
            )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onboardingSubtitleColor,
              fontFamily: 'Poppins',
            )),
      ],
    );
  }

  Widget _buildBirthDateSelector(
      BuildContext context, OnboardingProvider onboarding, ThemeData theme) {
    final localizations = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _showDatePicker(context, onboarding),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              onboarding.birthDate != null
                  ? DateFormat('dd.MM.yyyy').format(onboarding.birthDate!)
                  : localizations.translate('onboarding.profile.selectDate'),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onboardingTitleColor),
            ),
            Icon(Icons.calendar_today_outlined,
                color: theme.colorScheme.onboardingTitleColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightSelector(
      BuildContext context, OnboardingProvider onboarding, ThemeData theme) {
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
      theme: theme,
    );
  }

  Widget _buildWeightSelector(
      BuildContext context, OnboardingProvider onboarding, ThemeData theme) {
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
      theme: theme,
    );
  }

  Widget _buildNumberSelector({
    required BuildContext context,
    required int? value,
    required String unit,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null ? '$value$unit' : 'Select',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onboardingTitleColor),
            ),
            Icon(Icons.unfold_more,
                color: theme.colorScheme.onboardingTitleColor),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, OnboardingProvider onboarding) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DatePickerModal(
        initialDate: onboarding.birthDate ?? DateTime(2005, 9, 3),
        minDate: DateTime(1920),
        maxDate: DateTime.now(),
        onSelected: (date) => onboarding.setBirthDate(date),
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
