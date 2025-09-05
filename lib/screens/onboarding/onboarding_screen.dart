import 'package:flutter/material.dart';
import 'widgets/onboarding_step.dart';
import 'package:provider/provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentStep = 0;
  int _previousStep = -1;
  final _analyticsService = AnalyticsService();
  DateTime? _screenStartTime;
  bool _isNavigatingProgrammatically =
      false; // Flag to prevent onPageChanged interference
  bool _isDataLoaded = false;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);

  late final List<Widget> _onboardingPages;

  @override
  void initState() {
    super.initState();
    // initState should be used for one-time initializations that do not depend on context.
    _logScreenView();
    _logOnboardingStart();
    _startScreenTimeTracking();

    _onboardingPages = List.generate(
      6,
      (index) => OnboardingStep(
        step: index,
        previousStep: _previousStep,
        onNext: _nextStep,
        onBack: _prevStep,
        isLoadingNotifier: _isLoadingNotifier,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadOnboardingData();
      _isDataLoaded = true;
    }
  }

  Future<void> _loadOnboardingData() async {
    final authService = AuthService();
    final onboardingProvider = context.read<OnboardingProvider>();

    if (authService.currentUser != null) {
      final userModel =
          await authService.getUserData(authService.currentUser!.uid);
      if (userModel?.onboardingData != null) {
        onboardingProvider.initializeFromFirestore(userModel!.onboardingData!);
      } else {
        onboardingProvider.reset();
      }
    } else {
      onboardingProvider.reset();
    }
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
    _isLoadingNotifier.dispose();
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
      case 4: // Lifestyle Profile
        if (onboarding.lifestyleProfile == null ||
            onboarding.mealSchedule == null) {
          return localizations
              .translate('onboarding.validation.select_lifestyle_profile');
        }
        return '';

      case 5: // Profile Info
        if (onboarding.gender == null ||
            onboarding.birthDate == null ||
            onboarding.height == null ||
            onboarding.weight == null) {
          return localizations
              .translate('onboarding.validation.complete_profile_info');
        }
        return '';
      default:
        return localizations.translate('onboarding.validation.fill_required');
    }
  }

  void _nextStep() {
    if (_isLoadingNotifier.value) return;

    _isLoadingNotifier.value = true;

    // Validate before proceeding
    final onboardingProvider =
        Provider.of<OnboardingProvider>(context, listen: false);
    if (_shouldPreventForwardScroll(onboardingProvider)) {
      _showNotification(_getRequiredFieldsMessage(onboardingProvider));
      _isLoadingNotifier.value = false;
      return;
    }

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
          _isNavigatingProgrammatically = false;
          _isLoadingNotifier.value = false;
        }
      }).catchError((error) {
        // Reset flag on error
        if (mounted) {
          _isNavigatingProgrammatically = false;
          _isLoadingNotifier.value = false;
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

      final onboardingProvider =
          Provider.of<OnboardingProvider>(context, listen: false);
      if (onboardingProvider.isDirty) {
        onboardingProvider.updateOnboardingDataInFirestore();
      }
    } else {
      if (mounted) {
        _completeOnboarding();
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final onboardingProvider =
        Provider.of<OnboardingProvider>(context, listen: false);
    final authService = AuthService();

    _isLoadingNotifier.value = true;

    // Log completion analytics
    _logOnboardingCompletion();

    try {
      if (authService.currentUser != null) {
        if (!authService.currentUser!.emailVerified) {
          // If email is not verified, navigate to verification screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            "/verify_email",
            (route) => false,
          );
          return;
        }

        // If user is logged in, update their preferences
        final success = await onboardingProvider.saveFinalOnboardingData();

        if (success) {
          // Onboarding verilerini temizle
          onboardingProvider.reset();
          await authService.clearOnboardingData();

          if (mounted) {
            // If all info is complete, go home
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (route) => false);
          }
        } else {
          if (mounted) {
            _showNotification(
                'Please fill all required fields before completing.');
          }
        }
      } else {
        // If user is not logged in, navigate to register screen
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.register);
        }
      }
    } catch (e) {
      if (mounted) {
        _showNotification('An error occurred while saving your preferences.');
      }
    } finally {
      if (mounted) {
        _isLoadingNotifier.value = false;
      }
    }
  }

  /// Onboarding tamamlanma analytics'ini gönder
  void _logOnboardingCompletion() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'completion',
      action: 'complete',
      parameters: {
        'total_steps': 6,
        'completion_time': DateTime.now().toIso8601String(),
      },
    );

    _analyticsService.logUserInteraction(
      interactionType: 'onboarding_completion',
      target: 'onboarding_finished',
      parameters: {
        'total_steps_completed': 6,
        'completion_time': DateTime.now().toIso8601String(),
      },
    );
  }

  void _prevStep() {
    if (_isLoadingNotifier.value) return;

    _isLoadingNotifier.value = true;

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
          _isNavigatingProgrammatically = false;
          _isLoadingNotifier.value = false;
        }
      }).catchError((error) {
        // Reset flag on error
        if (mounted) {
          _isNavigatingProgrammatically = false;
          _isLoadingNotifier.value = false;
        }
      });
    } else {
      _isLoadingNotifier.value = false;
    }
    final onboardingProvider =
        Provider.of<OnboardingProvider>(context, listen: false);
    if (onboardingProvider.isDirty) {
      onboardingProvider.updateOnboardingDataInFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (!mounted) return;

                // Skip if we're navigating programmatically
                if (_isNavigatingProgrammatically) {
                  return;
                }

                // Skip if the index is the same as current step
                if (index == _currentStep) return;

                final onboarding = context.read<OnboardingProvider>();
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
                    _showNotification(_getRequiredFieldsMessage(onboarding));
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
                shouldPreventScroll: _shouldPreventForwardScroll(
                    context.watch<OnboardingProvider>()),
              ),
              children: _onboardingPages,
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldPreventForwardScroll(OnboardingProvider onboarding) {
    // Debug logging

    switch (_currentStep) {
      case 0: // Welcome page - no validation needed
        return false;
      case 1: // Activity Level ve Primary Goal
        return onboarding.activityLevel == null ||
            onboarding.primaryGoals.isEmpty;
      case 2: // Dietary Preferences - optional, no validation needed
        return false;
      case 3: // Pişirme seviyesi ve mutfak ekipmanı
        return onboarding.cookingLevel == null ||
            onboarding.kitchenEquipment.isEmpty;
      case 4: // Lifestyle Profile
        return onboarding.lifestyleProfile == null;
      case 5:
        return onboarding.gender == null ||
            onboarding.birthDate == null ||
            onboarding.height == null ||
            onboarding.weight == null;
      default:
        return false;
    }
  }
}

class _CustomScrollPhysics extends ScrollPhysics {
  final bool shouldPreventScroll;

  const _CustomScrollPhysics({
    super.parent,
    required this.shouldPreventScroll,
  });

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
