import 'package:cookrange/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/onboarding_common_widgets.dart' as main_widgets;
import '../widgets/onboarding_common_widgets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../widgets/number_picker_modal.dart';
import 'package:provider/provider.dart';

class OnboardingPage5 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  const OnboardingPage5({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
  }) : super(key: key);

  @override
  State<OnboardingPage5> createState() => _OnboardingPage5State();
}

class _OnboardingPage5State extends State<OnboardingPage5> {
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
        screenName: 'onboarding_step_5',
        duration: duration,
      );
    }
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'target_weight',
      action: 'view',
      parameters: {
        'step_number': 5,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logFieldUpdate(String field, dynamic value) {
    _analyticsService.logUserInteraction(
      interactionType: 'field_update',
      target: field,
      parameters: {
        'step': 5,
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
    final localizations = AppLocalizations.of(context);
    final analyticsService = AnalyticsService();
    final onboarding = Provider.of<OnboardingProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            OnboardingHeader(
              headerText: localizations.translate('onboarding.page5.header'),
              currentStep: widget.step + 1,
              totalSteps: 5,
              previousStep: widget.previousStep,
              onBackPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'navigation',
                  target: 'back_button',
                  parameters: {
                    'step': 5,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Main Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: localizations
                                .translate('onboarding.page5.title.text1'),
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
                                .translate('onboarding.page5.title.text2'),
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
                    Text(
                      localizations.translate('onboarding.page5.description'),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: colorScheme.onboardingSubtitleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Target Weight Section
                    Text(
                      localizations
                          .translate('onboarding.page5.target_weight.title'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onboardingTitleColor,
                        fontFamily: 'Lexend',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.translate(
                          'onboarding.page5.target_weight.description'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onboardingSubtitleColor,
                        fontFamily: 'Lexend',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Target Weight Input
                    GestureDetector(
                      onTap: () {
                        _showNumberInput(context, onboarding, 'targetWeight');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.onboardingTitleColor
                                .withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.monitor_weight,
                              color: colorScheme.primaryColorCustom,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.translate(
                                        'onboarding.page5.target_weight.title'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onboardingTitleColor,
                                      fontFamily: 'Lexend',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    onboarding.targetWeight != null
                                        ? '${onboarding.targetWeight!.toInt()} kg'
                                        : localizations.translate(
                                            'onboarding.page5.target_weight.placeholder'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: onboarding.targetWeight != null
                                          ? colorScheme.onboardingTitleColor
                                          : colorScheme.onboardingSubtitleColor,
                                      fontFamily: 'Lexend',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: colorScheme.onboardingSubtitleColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Image
                    Center(
                      child: Image.asset(
                        'assets/images/onboarding/onboarding-5.png',
                        width: size.width * 0.9,
                        height: size.width * 0.8,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          _analyticsService.logError(
                            errorName: 'image_load_error',
                            errorDescription: 'Failed to load onboarding-5.png',
                            parameters: {
                              'step': 5,
                              'error': error.toString(),
                              'stack_trace': stackTrace.toString(),
                            },
                          );
                          return const Icon(
                            Icons.emoji_food_beverage,
                            size: 80,
                            color: primaryColor,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 100), // Space for fixed button
                  ],
                ),
              ),
            ),

            // Fixed Continue Button
            main_widgets.OnboardingContinueButton(
              onPressed: onboarding.targetWeight != null
                  ? () async {
                      _analyticsService.logUserInteraction(
                        interactionType: 'button_click',
                        target: 'continue_button',
                        parameters: {
                          'step': 5,
                          'target_weight': onboarding.targetWeight ?? 0,
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_completed', true);

                      // Onboarding tamamlanma analytics'ini gönder
                      await onboarding.logOnboardingCompletion();
                      await onboarding.logOnboardingData();

                      await analyticsService.logEvent(
                        name: 'onboarding_completed',
                        parameters: {
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );

                      if (widget.onNext != null) widget.onNext!();
                    }
                  : null,
              text: localizations.translate('onboarding.page5.continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberInput(
      BuildContext context, OnboardingProvider onboarding, String field) {
    int min, max, initialValue;
    String unit, title;
    final localizations = AppLocalizations.of(context);

    if (field == 'targetWeight') {
      min = 40;
      max = 150;
      unit = 'kg';
      title = localizations.translate('onboarding.page5.target_weight.title');
      initialValue = onboarding.targetWeight?.toInt() ?? 60;
    } else {
      min = 40;
      max = 150;
      unit = 'kg';
      title = localizations.translate('onboarding.page5.target_weight.title');
      initialValue = onboarding.targetWeight?.toInt() ?? 60;
    }

    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => NumberPickerModal(
        title: title,
        min: min,
        max: max,
        unit: unit,
        initialValue: initialValue,
      ),
    ).then((value) {
      if (value != null && value is int) {
        if (field == 'targetWeight') {
          onboarding.setTargetWeight(value.toDouble());
          _logFieldUpdate('target_weight', value);
        }
      }
    });
  }
}
