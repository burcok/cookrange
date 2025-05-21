import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../widgets/onboarding_common_widgets.dart';
import '../../../core/services/analytics_service.dart';

class OnboardingPage4 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final OnboardingProvider onboarding;
  final void Function(BuildContext, OnboardingProvider) showActivityPicker;
  final void Function(BuildContext, OnboardingProvider, String) showNumberInput;

  const OnboardingPage4({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.onboarding,
    required this.showActivityPicker,
    required this.showNumberInput,
  }) : super(key: key);

  @override
  State<OnboardingPage4> createState() => _OnboardingPage4State();
}

class _OnboardingPage4State extends State<OnboardingPage4> {
  final _analyticsService = AnalyticsService();
  DateTime? _stepStartTime;
  VoidCallback? _activityListener;
  VoidCallback? _targetWeightListener;

  @override
  void initState() {
    super.initState();
    _stepStartTime = DateTime.now();
    _logStepView();
    _setupListeners();
  }

  void _setupListeners() {
    _activityListener = () {
      if (widget.onboarding.activityLevel != null) {
        _logFieldUpdate('activity_level', widget.onboarding.activityLevel);
      }
    };
    _targetWeightListener = () {
      if (widget.onboarding.targetWeight != null) {
        _logFieldUpdate('target_weight', widget.onboarding.targetWeight);
      }
    };
    widget.onboarding.addListener(_activityListener!);
    widget.onboarding.addListener(_targetWeightListener!);
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
    if (_activityListener != null) {
      widget.onboarding.removeListener(_activityListener!);
    }
    if (_targetWeightListener != null) {
      widget.onboarding.removeListener(_targetWeightListener!);
    }
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'activity_and_target',
      action: 'view',
      parameters: {
        'step_number': 4,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logFieldUpdate(String field, dynamic value) {
    _analyticsService.logUserInteraction(
      interactionType: 'field_update',
      target: field,
      parameters: {
        'step': 4,
        'field': field,
        'value': value.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Stack(
      children: [
        Container(color: colorScheme.background),
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
                              'step': 4,
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
                            '4/5',
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
                              text: 'Profilini ',
                              style: TextStyle(
                                color:
                                    colorScheme.onboardingNextButtonBorderColor,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            TextSpan(
                              text: 'tamamlayalım',
                              style: TextStyle(
                                color: colorScheme.onboardingTitleColor,
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
                          'Bu bilgileri sana daha iyi bir hizmet sunmak için kullanacağız.',
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
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ProfileInput(
                        label: 'Hareket Sıklığınız Nedir?',
                        value: widget.onboarding.activityLevel ?? 'Seçiniz',
                        onTap: () {
                          _analyticsService.logUserInteraction(
                            interactionType: 'modal_open',
                            target: 'activity_picker',
                            parameters: {
                              'step': 4,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                          widget.showActivityPicker(context, widget.onboarding);
                        },
                      ),
                      const SizedBox(height: 12),
                      ProfileInput(
                        label: 'Hedef Kilon',
                        value:
                            widget.onboarding.targetWeight?.toString() ?? 'kg',
                        onTap: () {
                          _analyticsService.logUserInteraction(
                            interactionType: 'modal_open',
                            target: 'target_weight_picker',
                            parameters: {
                              'step': 4,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                          widget.showNumberInput(
                            context,
                            widget.onboarding,
                            'targetWeight',
                          );
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
            ignoring: widget.onboarding.activityLevel == null ||
                widget.onboarding.targetWeight == null,
            child: Opacity(
              opacity: (widget.onboarding.activityLevel == null ||
                      widget.onboarding.targetWeight == null)
                  ? 0.5
                  : 1.0,
              child: OnboardingNextButton(
                step: widget.step,
                previousStep: widget.previousStep,
                onNext: () {
                  _analyticsService.logUserInteraction(
                    interactionType: 'button_click',
                    target: 'next_button',
                    parameters: {
                      'step': 4,
                      'activity_level': widget.onboarding.activityLevel,
                      'target_weight': widget.onboarding.targetWeight,
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
