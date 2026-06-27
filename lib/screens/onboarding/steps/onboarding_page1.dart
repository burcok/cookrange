import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../widgets/onboarding_common_widgets.dart';

class OnboardingPage1 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingPage1({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

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

  List<TextSpan> _buildStyledDescription(
      AppLocalizations localizations, AppPalette palette, Color primary) {
    final description = localizations.translate('onboarding.page1.description');
    final parts = description.split('{x}');

    if (parts.length == 2) {
      return [
        TextSpan(text: parts[0]),
        TextSpan(
          text: 'cookrange',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: parts[1]),
      ];
    }

    return [TextSpan(text: description)];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            OnboardingHeader(
              title: localizations.translate('onboarding.page1.header'),
              currentStep: widget.step + 1,
              totalSteps: 6,
              previousStep: widget.previousStep,
            ),

            // Main Content Section
            Expanded(
              child: Column(
                children: [
                  // Food illustration section
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/onboarding/onboarding-1.png',
                        width: size.width * 0.9,
                        height: size.height * 0.35,
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
                          return Icon(
                            Icons.emoji_food_beverage,
                            size: 80,
                            color: primary,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Content Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    localizations.translate('onboarding.page1.title'),
                    textAlign: TextAlign.center,
                    style: t.displayM.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: t.bodyL.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                      children:
                          _buildStyledDescription(localizations, palette, primary),
                    ),
                  ),
                  const SizedBox(height: 42),
                  // Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Call onNext immediately
                        widget.onNext?.call();

                        // Run analytics in background
                        Future.microtask(() {
                          _analyticsService.logUserInteraction(
                            interactionType: 'button_click',
                            target: 'get_started_button',
                            parameters: {
                              'step': 1,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        localizations.translate('onboarding.page1.get_started'),
                        style: t.titleM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
