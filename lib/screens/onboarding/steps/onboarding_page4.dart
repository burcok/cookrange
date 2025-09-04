import 'package:flutter/material.dart';
import 'package:cookrange/constants.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../widgets/onboarding_common_widgets.dart';
import '../../../core/providers/onboarding_provider.dart';

class OnboardingPage4 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingPage4({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  State<OnboardingPage4> createState() => _OnboardingPage4State();
}

class _OnboardingPage4State extends State<OnboardingPage4> {
  final _analyticsService = AnalyticsService();
  DateTime? _stepStartTime;

  @override
  void initState() {
    super.initState();
    _stepStartTime = DateTime.now();
    _logStepView();
  }

  @override
  void dispose() {
    if (_stepStartTime != null) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _analyticsService.logScreenTime(
        screenName: 'onboarding_step_4',
        duration: duration,
      );
    }
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'time_preferences',
      action: 'view',
      parameters: {
        'step_number': 4,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logSelection(String type, String value) {
    _analyticsService.logUserInteraction(
      interactionType: 'selection',
      target: '${type}_selection',
      parameters: {
        'step': 4,
        'type': type,
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logEquipmentToggle(String equipment, bool isSelected) {
    _analyticsService.logUserInteraction(
      interactionType: 'equipment_toggle',
      target: 'kitchen_equipment',
      parameters: {
        'step': 4,
        'equipment': equipment,
        'is_selected': isSelected,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);
    final onboarding = context.watch<OnboardingProvider>();

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            OnboardingHeader(
              title: localizations.translate('onboarding.page4.header'),
              currentStep: widget.step + 1,
              totalSteps: 6,
              previousStep: widget.previousStep,
              onBackButtonPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'navigation',
                  target: 'back_button',
                  parameters: {
                    'step': 4,
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
                if (widget.onBack != null) {
                  widget.onBack!();
                }
              },
            ),

            // Main Content Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // Cooking Level Section
                      OnboardingSection(
                        title: localizations
                            .translate('onboarding.page4.cooking_level.title'),
                        subtitle: localizations.translate(
                            'onboarding.page4.cooking_level.subtitle'),
                        options: [
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page4.cooking_level.beginner'),
                            icon: Icons
                                .school, // Başlangıç seviyesi için okul ikonu
                            value: 'onboarding.page4.cooking_level.beginner',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page4.cooking_level.intermediate'),
                            icon: Icons
                                .restaurant, // Orta seviye için restoran ikonu
                            value:
                                'onboarding.page4.cooking_level.intermediate',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page4.cooking_level.advanced'),
                            icon: Icons.star, // İleri seviye için yıldız ikonu
                            value: 'onboarding.page4.cooking_level.advanced',
                          ),
                        ],
                        selectedValue: onboarding.cookingLevel?['label'],
                        onSelectionChanged: (value) {
                          _logSelection('cooking_level', value);
                          context.read<OnboardingProvider>().setCookingLevel({
                            'label': value,
                            'value': localizations.translate(value),
                          });
                        },
                      ),

                      const SizedBox(height: 32),

                      // Kitchen Equipment Section
                      _buildKitchenEquipmentSection(localizations, colorScheme),

                      const SizedBox(height: 100), // Space for fixed button
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Continue Button
            OnboardingContinueButton(
              onPressed: onboarding.cookingLevel != null &&
                      onboarding.kitchenEquipment.isNotEmpty
                  ? () {
                      _analyticsService.logUserInteraction(
                        interactionType: 'button_click',
                        target: 'continue_button',
                        parameters: {
                          'step': 4,
                          'cooking_level':
                              onboarding.cookingLevel?['value'] ?? '',
                          'kitchen_equipment': onboarding.kitchenEquipment
                              .map((e) => e['value'] as String)
                              .join(','),
                          'kitchen_equipment_count':
                              onboarding.kitchenEquipment.length,
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      widget.onNext?.call();
                    }
                  : null,
              text: localizations.translate('onboarding.page4.continue'),
              isLoadingNotifier: widget.isLoadingNotifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenEquipmentSection(
      AppLocalizations localizations, ColorScheme colorScheme) {
    final equipmentList = [
      // Basic Equipment
      {
        'key': 'onboarding.page4.kitchen_equipment.stove',
        'label':
            localizations.translate('onboarding.page4.kitchen_equipment.stove')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.oven',
        'label':
            localizations.translate('onboarding.page4.kitchen_equipment.oven')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.microwave',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.microwave')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.pressure_cooker',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.pressure_cooker')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.electric_kettle',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.electric_kettle')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.coffee_maker',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.coffee_maker')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.grinder',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.grinder')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.toaster',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.toaster')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.blender',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.blender')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.hand_mixer',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.hand_mixer')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.stand_mixer',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.stand_mixer')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.air_fryer',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.air_fryer')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.electric_grill',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.electric_grill')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.samovar',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.samovar')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.turkish_coffee_pot',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.turkish_coffee_pot')
      },
      {
        'key': 'onboarding.page4.kitchen_equipment.tea_pot',
        'label': localizations
            .translate('onboarding.page4.kitchen_equipment.tea_pot')
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.translate('onboarding.page4.kitchen_equipment.title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        ...equipmentList.map((equipment) => _buildEquipmentItem(
              equipment['key']!,
              equipment['label']!,
              colorScheme,
            )),
      ],
    );
  }

  Widget _buildEquipmentItem(
      String key, String label, ColorScheme colorScheme) {
    final onboarding = context.watch<OnboardingProvider>();
    final isSelected =
        onboarding.kitchenEquipment.any((equip) => equip['label'] == key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onboardingTitleColor,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _logEquipmentToggle(key, !isSelected);
              context.read<OnboardingProvider>().toggleKitchenEquipment({
                'label': key,
                'value': label,
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.black26,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
