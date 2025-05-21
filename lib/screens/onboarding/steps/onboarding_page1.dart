import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/onboarding_common_widgets.dart';
import '../../../core/services/analytics_service.dart';

class OnboardingPage1 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  const OnboardingPage1({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
  }) : super(key: key);

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
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
        screenName: 'onboarding_step_1',
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
    return Stack(
      children: [
        Container(color: theme.scaffoldBackgroundColor),
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 36),
              Center(
                child: Text(
                  '1/5',
                  style: TextStyle(
                    color: colorScheme.onboardingOptionTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.04),
              Center(
                child: Image.asset(
                  'assets/images/onboarding/onboarding-1.png',
                  width: size.width * 0.7,
                  height: size.width * 0.7,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding:
                const EdgeInsets.only(top: 36, left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: colorScheme.backgroundColor2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ne Yediğini Bil',
                  style: TextStyle(
                    color: colorScheme.onboardingTitleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yapay zeka destekli cookrange ile tüm yemek planını saniyeler içinde oluştur veya düzenle!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onboardingSubtitleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 32),
                OnboardingNextButton(
                  step: widget.step,
                  previousStep: widget.previousStep,
                  onNext: () {
                    _analyticsService.logUserInteraction(
                      interactionType: 'button_click',
                      target: 'next_button',
                      parameters: {
                        'step': 1,
                        'timestamp': DateTime.now().toIso8601String(),
                      },
                    );
                    widget.onNext?.call();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
