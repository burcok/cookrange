import 'package:flutter/material.dart';
import 'widgets/onboarding_step.dart';
import 'package:provider/provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/localization/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int _previousStep = -1;
  final _analyticsService = AnalyticsService();
  DateTime? _screenStartTime;
  bool _isNavigatingProgrammatically =
      false; // Flag to prevent onPageChanged interference

  @override
  void initState() {
    super.initState();
    _logScreenView();
    _logOnboardingStart();
    _startScreenTimeTracking();
  }

  void _startScreenTimeTracking() {
    _screenStartTime = DateTime.now();
  }

  @override
  void dispose() {
    if (_screenStartTime != null) {
      final duration = DateTime.now().difference(_screenStartTime!);
      _analyticsService.logScreenTime(
        screenName: 'onboarding_screen',
        duration: duration,
      );
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _logScreenView() async {
    await _analyticsService.logScreenView(
      screenName: 'onboarding_screen',
      screenClass: 'OnboardingScreen',
      additionalParams: {
        'step': _currentStep,
      },
    );
  }

  void _logOnboardingStart() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'start',
      action: 'begin',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logOnboardingStep(int step) {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'step_$step',
      action: 'view',
      parameters: {
        'step_number': step,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logOnboardingError(String errorMessage) {
    _analyticsService.logError(
      errorName: 'onboarding_validation_error',
      errorDescription: errorMessage,
      parameters: {
        'step': _currentStep,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _showNotification(String message) {
    _logOnboardingError(message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        showCloseIcon: true,
        closeIconColor: Colors.white,
        actionOverflowThreshold: 1,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _getRequiredFieldsMessage(OnboardingProvider onboarding) {
    final localizations = AppLocalizations.of(context);
    switch (_currentStep) {
      case 1:
        if (onboarding.activityLevel == null &&
            onboarding.primaryGoals.isEmpty) {
          return localizations
              .translate('onboarding.validation.select_activity_and_goals');
        }
        if (onboarding.activityLevel == null) {
          return localizations
              .translate('onboarding.validation.select_activity');
        }
        if (onboarding.primaryGoals.isEmpty) {
          return localizations.translate('onboarding.validation.select_goals');
        }
        return localizations
            .translate('onboarding.validation.complete_activity');
      case 2:
        return '';
      case 3: // Pişirme seviyesi ve mutfak ekipmanı
        if (onboarding.cookingLevel == null &&
            onboarding.kitchenEquipment.isEmpty) {
          return localizations
              .translate('onboarding.validation.select_cooking_level');
        }
        if (onboarding.cookingLevel == null) {
          return localizations
              .translate('onboarding.validation.select_cooking_level');
        }
        if (onboarding.kitchenEquipment.isEmpty) {
          return localizations
              .translate('onboarding.validation.select_kitchen_equipment');
        }
        return localizations
            .translate('onboarding.validation.complete_cooking_preferences');
      case 4: // Hedef kilo
        if (onboarding.targetWeight == null) {
          return localizations
              .translate('onboarding.validation.enter_target_weight');
        }
        return localizations
            .translate('onboarding.validation.complete_target_weight');
      default:
        return localizations.translate('onboarding.validation.fill_required');
    }
  }

  void _nextStep() {
    if (_currentStep < 5) {
      // Set flag to prevent onPageChanged interference
      _isNavigatingProgrammatically = true;

      // Update state immediately without waiting for analytics
      setState(() {
        _previousStep = _currentStep;
        _currentStep++;
      });

      // Animate to the next page immediately
      _pageController
          .animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      )
          .then((_) {
        // Reset flag after animation completes
        if (mounted) {
          setState(() {
            _isNavigatingProgrammatically = false;
          });
        }
      }).catchError((error) {
        print('Error during next step animation: $error');
        // Reset flag on error
        if (mounted) {
          setState(() {
            _isNavigatingProgrammatically = false;
          });
        }
      });

      // Run analytics in background
      Future.microtask(() {
        _analyticsService.logUserInteraction(
          interactionType: 'navigation',
          target: 'next_step',
          parameters: {
            'from_step': _currentStep - 1,
            'to_step': _currentStep,
          },
        );
        _logOnboardingStep(_currentStep);
      });
    } else {
      // Onboarding tamamlandı, analytics gönder
      _logOnboardingCompletion();
    }
  }

  /// Onboarding tamamlanma analytics'ini gönder
  void _logOnboardingCompletion() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'completion',
      action: 'complete',
      parameters: {
        'total_steps': 5,
        'completion_time': DateTime.now().toIso8601String(),
      },
    );

    _analyticsService.logUserInteraction(
      interactionType: 'onboarding_completion',
      target: 'onboarding_finished',
      parameters: {
        'total_steps_completed': 5,
        'completion_time': DateTime.now().toIso8601String(),
      },
    );
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _analyticsService.logUserInteraction(
        interactionType: 'navigation',
        target: 'previous_step',
        parameters: {
          'from_step': _currentStep,
          'to_step': _currentStep - 1,
        },
      );
      _logOnboardingStep(_currentStep - 1);

      // Set flag to prevent onPageChanged interference
      _isNavigatingProgrammatically = true;

      // Update state immediately for better responsiveness
      setState(() {
        _previousStep = _currentStep;
        _currentStep--;
      });

      // Animate to the previous page
      _pageController
          .animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
          .then((_) {
        // Reset flag after animation completes
        if (mounted) {
          setState(() {
            _isNavigatingProgrammatically = false;
          });
        }
      }).catchError((error) {
        print('Error during animation: $error');
        // Reset flag on error
        if (mounted) {
          setState(() {
            _isNavigatingProgrammatically = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Consumer<OnboardingProvider>(
              builder: (context, onboarding, child) {
                return PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (!mounted) return;

                    // Skip if we're navigating programmatically
                    if (_isNavigatingProgrammatically) {
                      return;
                    }

                    // Skip if the index is the same as current step
                    if (index == _currentStep) return;

                    if (index > _currentStep) {
                      if (_shouldPreventForwardScroll(onboarding)) {
                        Future.microtask(() {
                          _analyticsService.logUserInteraction(
                            interactionType: 'validation_error',
                            target: 'forward_scroll',
                            parameters: {
                              'current_step': _currentStep,
                              'attempted_step': index,
                              'error_message':
                                  _getRequiredFieldsMessage(onboarding),
                            },
                          );
                        });
                        _pageController.animateToPage(
                          _currentStep,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                        _showNotification(
                            _getRequiredFieldsMessage(onboarding));
                        return;
                      }
                    }

                    // Only update state if it's different
                    if (index != _currentStep) {
                      setState(() {
                        _previousStep = _currentStep;
                        _currentStep = index;
                      });

                      // Run analytics in background
                      Future.microtask(() {
                        _analyticsService.logUserInteraction(
                          interactionType: 'page_change',
                          target: 'step_$index',
                          parameters: {
                            'from_step': _previousStep,
                            'to_step': index,
                          },
                        );
                        _logOnboardingStep(index);
                      });
                    }
                  },
                  physics: _CustomScrollPhysics(
                    parent: const PageScrollPhysics(),
                    shouldPreventScroll:
                        _shouldPreventForwardScroll(onboarding),
                  ),
                  children: List.generate(
                    5,
                    (index) => OnboardingStep(
                      step: index,
                      previousStep: _previousStep,
                      onNext: _nextStep,
                      onBack: _prevStep,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldPreventForwardScroll(OnboardingProvider onboarding) {
    // Debug logging
    print('_shouldPreventForwardScroll called for step $_currentStep');
    print('cookingLevel: ${onboarding.cookingLevel}');
    print('kitchenEquipment: ${onboarding.kitchenEquipment}');
    print('kitchenEquipment.isEmpty: ${onboarding.kitchenEquipment.isEmpty}');

    switch (_currentStep) {
      case 0: // Welcome page - no validation needed
        return false;
      case 1: // Activity Level ve Primary Goal
        return onboarding.activityLevel == null ||
            onboarding.primaryGoals.isEmpty;
      case 2: // Dietary Preferences - optional, no validation needed
        return false;
      case 3: // Pişirme seviyesi ve mutfak ekipmanı
        final shouldPrevent = onboarding.cookingLevel == null ||
            onboarding.kitchenEquipment.isEmpty;
        print('Step 3 validation: shouldPrevent = $shouldPrevent');
        return shouldPrevent;
      case 4: // Hedef kilo
        return onboarding.targetWeight == null;
      default:
        return false;
    }
  }
}

class _CustomScrollPhysics extends ScrollPhysics {
  final bool shouldPreventScroll;

  const _CustomScrollPhysics({
    ScrollPhysics? parent,
    required this.shouldPreventScroll,
  }) : super(parent: parent);

  @override
  _CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CustomScrollPhysics(
      parent: buildParent(ancestor),
      shouldPreventScroll: shouldPreventScroll,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Geriye doğru swipe her zaman mümkün (value < position.pixels)
    if (value < position.pixels) {
      return super.applyBoundaryConditions(position, value);
    }

    // İleriye doğru swipe gereksinimlere bağlı
    if (shouldPreventScroll && value > position.pixels) {
      return value - position.pixels;
    }

    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Geriye doğru velocity (velocity < 0) her zaman mümkün
    if (velocity < 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    // İleriye doğru velocity (velocity > 0) gereksinimlere bağlı
    if (shouldPreventScroll && velocity > 0) {
      return null;
    }

    return super.createBallisticSimulation(position, velocity);
  }
}
