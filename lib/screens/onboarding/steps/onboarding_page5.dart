import 'package:cookrange/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/onboarding_common_widgets.dart';
import '../../../core/localization/app_localizations.dart';

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
      step: 'welcome',
      action: 'view',
      parameters: {
        'step_number': 1,
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
                        onTap: () => widget.onBack?.call(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: colorScheme.onboardingTitleColor
                                    .withOpacity(0.1),
                                width: 1),
                          ),
                          child: Icon(Icons.arrow_back,
                              color: colorScheme.onboardingTitleColor,
                              size: 24),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '5/5',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          localizations
                              .translate('onboarding.page5.description'),
                          textAlign: TextAlign.left,
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
                const SizedBox(height: 14),
                Center(
                  child: Image.asset(
                    'assets/images/onboarding/onboarding-5.png',
                    width: size.width * 0.9,
                    height: size.width * 0.8,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      _analyticsService.logError(
                        errorName: 'image_load_error',
                        errorDescription: 'Failed to load onboarding-1.png',
                        parameters: {
                          'step': 1,
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
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: OnboardingNextButton(
            step: widget.step,
            previousStep: widget.previousStep,
            onNext: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_completed', true);
              await analyticsService.logEvent(
                name: 'onboarding_completed',
                parameters: {
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );
              if (widget.onNext != null) widget.onNext!();
            },
          ),
        ),
      ],
    );
  }
}
