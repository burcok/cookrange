import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
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
                // Sayfa 2'den sayfa 1'e git
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
                        options: [
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.sedentary'),
                            icon: Icons.weekend,
                            value: 'onboarding.page2.activity_level.sedentary',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.light'),
                            icon: Icons.directions_walk,
                            value: 'onboarding.page2.activity_level.light',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.moderate'),
                            icon: Icons.directions_run,
                            value: 'onboarding.page2.activity_level.moderate',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.active'),
                            icon: Icons.emoji_events,
                            value: 'onboarding.page2.activity_level.active',
                          ),
                        ],
                        selectedValue: onboarding.activityLevel?['label'],
                        onSelectionChanged: (value) {
                          _logSelection('activity_level', value);
                          context.read<OnboardingProvider>().setActivityLevel({
                            'label': value,
                            'value': localizations.translate(value),
                          });
                        },
                      ),

                      const SizedBox(height: 32),

                      // Primary Goal Section
                      OnboardingMultiSelectSection(
                        title: localizations
                            .translate('onboarding.page2.primary_goal.title'),
                        subtitle: localizations.translate(
                            'onboarding.page2.primary_goal.subtitle'),
                        options: [
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.lose_weight'),
                            icon: Icons.trending_down,
                            value: 'onboarding.page2.primary_goal.lose_weight',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.gain_weight'),
                            icon: Icons.trending_up,
                            value: 'onboarding.page2.primary_goal.gain_weight',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.maintain_weight'),
                            icon: Icons.balance,
                            value:
                                'onboarding.page2.primary_goal.maintain_weight',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.feel_energetic'),
                            icon: Icons.flash_on,
                            value:
                                'onboarding.page2.primary_goal.feel_energetic',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.mental_clarity'),
                            icon: Icons.psychology,
                            value:
                                'onboarding.page2.primary_goal.mental_clarity',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.healthy_eating'),
                            icon: Icons.favorite,
                            value:
                                'onboarding.page2.primary_goal.healthy_eating',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.save_time'),
                            icon: Icons.schedule,
                            value: 'onboarding.page2.primary_goal.save_time',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.improve_sleep'),
                            icon: Icons.bedtime,
                            value:
                                'onboarding.page2.primary_goal.improve_sleep',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.increase_muscle'),
                            icon: Icons.fitness_center,
                            value:
                                'onboarding.page2.primary_goal.increase_muscle',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.body_shaping'),
                            icon: Icons.accessibility_new,
                            value: 'onboarding.page2.primary_goal.body_shaping',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.stress_management'),
                            icon: Icons.self_improvement,
                            value:
                                'onboarding.page2.primary_goal.stress_management',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.digestive_health'),
                            icon: Icons.healing,
                            value:
                                'onboarding.page2.primary_goal.digestive_health',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.immune_boost'),
                            icon: Icons.health_and_safety,
                            value: 'onboarding.page2.primary_goal.immune_boost',
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.sustainable_lifestyle'),
                            icon: Icons.eco,
                            value:
                                'onboarding.page2.primary_goal.sustainable_lifestyle',
                          ),
                        ],
                        selectedValues: onboarding.primaryGoals
                            .map((goal) => goal['label'] as String)
                            .toList(),
                        onSelectionChanged: (value) {
                          _logSelection('primary_goal', value);
                          context.read<OnboardingProvider>().togglePrimaryGoal({
                            'label': value,
                            'value': localizations.translate(value),
                          });
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
