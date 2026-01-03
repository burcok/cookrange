import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/constants/onboarding_options.dart';
import '../../../widgets/onboarding_common_widgets.dart';
import '../../../core/providers/onboarding_provider.dart';

class OnboardingPage2 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingPage2({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2> {
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
        screenName: 'onboarding_step_2',
        duration: duration,
      );
    }
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'goal_selection',
      action: 'view',
      parameters: {
        'step_number': 2,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logSelection(String type, String value) {
    _analyticsService.logUserInteraction(
      interactionType: 'selection',
      target: '${type}_selection',
      parameters: {
        'step': 2,
        'type': type,
        'value': value,
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
              title: localizations.translate('onboarding.page2.header'),
              currentStep: widget.step + 1,
              totalSteps: 6,
              previousStep: widget.previousStep,
              onBackButtonPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'navigation',
                  target: 'back_button',
                  parameters: {
                    'step': 2,
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
                      // Activity Level Section
                      OnboardingSection(
                        title: localizations
                            .translate('onboarding.page2.activity_level.title'),
                        subtitle: localizations.translate(
                            'onboarding.page2.activity_level.subtitle'),
                        options:
                            OnboardingOptions.activityLevels.entries.map((e) {
                          return OptionData(
                            label: localizations.translate(e.value['label']),
                            icon: e.value['icon'] as IconData,
                            value: e.key,
                          );
                        }).toList(),
                        selectedValue: onboarding.activityLevel?['value'],
                        onSelectionChanged: (value) {
                          _logSelection('activity_level', value);
                          context
                              .read<OnboardingProvider>()
                              .setActivityLevel(value);
                        },
                      ),

                      const SizedBox(height: 32),

                      // Primary Goal Section
                      OnboardingMultiSelectSection(
                        title: localizations
                            .translate('onboarding.page2.primary_goal.title'),
                        subtitle: localizations.translate(
                            'onboarding.page2.primary_goal.subtitle'),
                        options:
                            OnboardingOptions.primaryGoals.entries.map((e) {
                          return OptionData(
                            label: localizations.translate(e.value['label']),
                            icon: e.value['icon'] as IconData,
                            value: e.key,
                          );
                        }).toList(),
                        selectedValues: onboarding.primaryGoals
                            .map((goal) => goal['value'] as String)
                            .toList(),
                        onSelectionChanged: (value) {
                          _logSelection('primary_goal', value);
                          context
                              .read<OnboardingProvider>()
                              .togglePrimaryGoal(value);
                        },
                      ),

                      const SizedBox(height: 100), // Space for fixed button
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Continue Button
            OnboardingContinueButton(
              onPressed: (onboarding.activityLevel != null &&
                      onboarding.primaryGoals.isNotEmpty)
                  ? () {
                      _analyticsService.logUserInteraction(
                        interactionType: 'button_click',
                        target: 'continue_button',
                        parameters: {
                          'step': 2,
                          'activity_level':
                              onboarding.activityLevel?['value'] ?? '',
                          'primary_goals': onboarding.primaryGoals
                              .map((goal) => goal['value'] as String)
                              .join(', '),
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      widget.onNext?.call();
                    }
                  : null,
              text: localizations.translate('onboarding.page2.continue'),
              isLoadingNotifier: widget.isLoadingNotifier,
            ),
          ],
        ),
      ),
    );
  }
}
