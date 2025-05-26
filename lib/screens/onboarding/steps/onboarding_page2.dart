import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../widgets/onboarding_common_widgets.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/localization/app_localizations.dart';

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

  void _logGoalSelection(String goal) {
    _analyticsService.logUserInteraction(
      interactionType: 'goal_selection',
      target: goal,
      parameters: {
        'step': 2,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);
    return Stack(
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _analyticsService.logUserInteraction(
                            interactionType: 'navigation',
                            target: 'back_button',
                            parameters: {
                              'step': 2,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                          widget.onBack?.call();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onboardingTitleColor
                                  .withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: colorScheme.onboardingTitleColor,
                            size: 24,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '2/5',
                            style: TextStyle(
                              color: colorScheme.onboardingTitleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: localizations
                                  .translate('onboarding.page2.title.text1'),
                              style: TextStyle(
                                color:
                                    colorScheme.onboardingNextButtonBorderColor,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            TextSpan(
                              text: localizations
                                  .translate('onboarding.page2.title.text2'),
                              style: TextStyle(
                                color: colorScheme.onboardingOptionTextColor,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          localizations
                              .translate('onboarding.page2.description'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onboardingSubtitleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _GoalOptionV2(
                        label: localizations
                            .translate('onboarding.goals.lose_weight'),
                        selected: widget.onboarding.goal ==
                            localizations
                                .translate('onboarding.goals.lose_weight'),
                        icon: 'assets/images/onboarding/onboarding-2-1.png',
                        onTap: () {
                          _logGoalSelection(localizations
                              .translate('onboarding.goals.lose_weight'));
                          widget.onboarding.setGoal(localizations
                              .translate('onboarding.goals.lose_weight'));
                        },
                      ),
                      const SizedBox(height: 16),
                      _GoalOptionV2(
                        label: localizations
                            .translate('onboarding.goals.gain_weight'),
                        selected: widget.onboarding.goal ==
                            localizations
                                .translate('onboarding.goals.gain_weight'),
                        icon: 'assets/images/onboarding/onboarding-2-2.png',
                        onTap: () {
                          _logGoalSelection(localizations
                              .translate('onboarding.goals.gain_weight'));
                          widget.onboarding.setGoal(localizations
                              .translate('onboarding.goals.gain_weight'));
                        },
                      ),
                      const SizedBox(height: 16),
                      _GoalOptionV2(
                        label: localizations
                            .translate('onboarding.goals.build_muscle'),
                        selected: widget.onboarding.goal ==
                            localizations
                                .translate('onboarding.goals.build_muscle'),
                        icon: 'assets/images/onboarding/onboarding-2-3.png',
                        onTap: () {
                          _logGoalSelection(localizations
                              .translate('onboarding.goals.build_muscle'));
                          widget.onboarding.setGoal(localizations
                              .translate('onboarding.goals.build_muscle'));
                        },
                      ),
                      const SizedBox(height: 16),
                      _GoalOptionV2(
                        label: localizations
                            .translate('onboarding.goals.shape_body'),
                        selected: widget.onboarding.goal ==
                            localizations
                                .translate('onboarding.goals.shape_body'),
                        icon: 'assets/images/onboarding/onboarding-2-4.png',
                        onTap: () {
                          _logGoalSelection(localizations
                              .translate('onboarding.goals.shape_body'));
                          widget.onboarding.setGoal(localizations
                              .translate('onboarding.goals.shape_body'));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: IgnorePointer(
            ignoring: widget.onboarding.goal == null,
            child: Opacity(
              opacity: widget.onboarding.goal == null ? 0.5 : 1.0,
              child: OnboardingNextButton(
                step: widget.step,
                previousStep: widget.previousStep,
                onNext: () {
                  _analyticsService.logUserInteraction(
                    interactionType: 'button_click',
                    target: 'next_button',
                    parameters: {
                      'step': 2,
                      'selected_goal': widget.onboarding.goal ?? '',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );
                  widget.onNext?.call();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalOptionV2 extends StatelessWidget {
  final String label;
  final bool selected;
  final String icon;
  final VoidCallback onTap;
  const _GoalOptionV2({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.onboardingOptionSelectedBgColor
              : colorScheme.onboardingOptionBgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onboardingOptionTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            icon.isNotEmpty
                ? Image.asset(
                    icon,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      final analyticsService = AnalyticsService();
                      analyticsService.logError(
                        errorName: 'image_load_error',
                        errorDescription: 'Failed to load $icon',
                        parameters: {
                          'step': 2,
                          'icon': icon,
                          'error': error.toString(),
                          'stack_trace': stackTrace.toString(),
                        },
                      );
                      return Icon(Icons.image,
                          size: 28, color: theme.cardColor);
                    },
                  )
                : Icon(Icons.image, color: theme.cardColor, size: 28),
          ],
        ),
      ),
    );
  }
}
