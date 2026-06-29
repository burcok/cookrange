import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

            // Image fills the available space
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/onboarding/onboarding-1.png',
                  width: size.width * 0.85,
                  height: size.height * 0.32,
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
                      size: 80.r,
                      color: primary,
                    );
                  },
                ),
              ),
            ),

            // Title + description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                children: [
                  Text(
                    localizations.translate('onboarding.page1.title'),
                    textAlign: TextAlign.center,
                    style: t.headlineL.copyWith(
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
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
                  SizedBox(height: AppSpacing.lg.h),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingContinueButton(
        text: localizations.translate('onboarding.page1.get_started'),
        isLoadingNotifier: widget.isLoadingNotifier,
        onPressed: () {
          widget.onNext?.call();
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
      ),
    );
  }
}
