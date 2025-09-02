import 'package:flutter/material.dart';
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
  final OnboardingProvider onboarding;
  const OnboardingPage2({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.onboarding,
  }) : super(key: key);

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

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            OnboardingHeader(
              headerText: localizations.translate('onboarding.page2.header'),
              currentStep: widget.step + 1,
              totalSteps: 5,
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
                            value: localizations.translate(
                                'onboarding.page2.activity_level.sedentary'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.light'),
                            icon: Icons.directions_walk,
                            value: localizations.translate(
                                'onboarding.page2.activity_level.light'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.moderate'),
                            icon: Icons.directions_run,
                            value: localizations.translate(
                                'onboarding.page2.activity_level.moderate'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.activity_level.active'),
                            icon: Icons.emoji_events,
                            value: localizations.translate(
                                'onboarding.page2.activity_level.active'),
                          ),
                        ],
                        selectedValue: widget.onboarding.activityLevel,
                        onSelectionChanged: (value) {
                          _logSelection('activity_level', value);
                          widget.onboarding.setActivityLevel(value);
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
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.lose_weight'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.gain_weight'),
                            icon: Icons.trending_up,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.gain_weight'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.maintain_weight'),
                            icon: Icons.balance,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.maintain_weight'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.feel_energetic'),
                            icon: Icons.flash_on,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.feel_energetic'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.mental_clarity'),
                            icon: Icons.psychology,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.mental_clarity'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.healthy_eating'),
                            icon: Icons.favorite,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.healthy_eating'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.save_time'),
                            icon: Icons.schedule,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.save_time'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.improve_sleep'),
                            icon: Icons.bedtime,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.improve_sleep'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.increase_muscle'),
                            icon: Icons.fitness_center,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.increase_muscle'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.body_shaping'),
                            icon: Icons.accessibility_new,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.body_shaping'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.stress_management'),
                            icon: Icons.self_improvement,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.stress_management'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.digestive_health'),
                            icon: Icons.healing,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.digestive_health'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.immune_boost'),
                            icon: Icons.health_and_safety,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.immune_boost'),
                          ),
                          OptionData(
                            label: localizations.translate(
                                'onboarding.page2.primary_goal.sustainable_lifestyle'),
                            icon: Icons.eco,
                            value: localizations.translate(
                                'onboarding.page2.primary_goal.sustainable_lifestyle'),
                          ),
                        ],
                        selectedValues: widget.onboarding.primaryGoals,
                        onSelectionChanged: (value) {
                          _logSelection('primary_goal', value);
                          widget.onboarding.setPrimaryGoal(value);
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
              onPressed: (widget.onboarding.activityLevel != null &&
                      widget.onboarding.primaryGoals.isNotEmpty)
                  ? () {
                      _analyticsService.logUserInteraction(
                        interactionType: 'button_click',
                        target: 'continue_button',
                        parameters: {
                          'step': 2,
                          'activity_level':
                              widget.onboarding.activityLevel ?? '',
                          'primary_goals':
                              widget.onboarding.primaryGoals.join(', '),
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      widget.onNext?.call();
                    }
                  : null,
              text: localizations.translate('onboarding.page2.continue'),
            ),
          ],
        ),
      ),
    );
  }
}
