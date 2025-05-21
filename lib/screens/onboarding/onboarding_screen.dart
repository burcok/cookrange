import 'package:flutter/material.dart';
import 'widgets/onboarding_step.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
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
        return localizations.translate('onboarding.validation.select_goal');
      case 2:
        if (onboarding.gender == null) {
          return localizations.translate('onboarding.validation.select_gender');
        }
        if (onboarding.birthDate == null) {
          return localizations
              .translate('onboarding.validation.select_birth_date');
        }
        if (onboarding.weight == null) {
          return localizations.translate('onboarding.validation.enter_weight');
        }
        if (onboarding.height == null) {
          return localizations.translate('onboarding.validation.enter_height');
        }
        return localizations
            .translate('onboarding.validation.complete_profile');
      case 3:
        if (onboarding.activityLevel == null) {
          return localizations
              .translate('onboarding.validation.select_activity');
        }
        if (onboarding.targetWeight == null) {
          return localizations
              .translate('onboarding.validation.enter_target_weight');
        }
        return localizations
            .translate('onboarding.validation.complete_activity');
      default:
        return localizations.translate('onboarding.validation.fill_required');
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _analyticsService.logUserInteraction(
        interactionType: 'navigation',
        target: 'next_step',
        parameters: {
          'from_step': _currentStep,
          'to_step': _currentStep + 1,
        },
      );
      _logOnboardingStep(_currentStep + 1);
      _pageController
          .animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) {
          setState(() {
            _previousStep = _currentStep;
            _currentStep++;
          });
        }
      });
    }
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
      _pageController
          .animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) {
          setState(() {
            _previousStep = _currentStep;
            _currentStep--;
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

                    if (index > _currentStep &&
                        _shouldPreventForwardScroll(onboarding)) {
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
                      _pageController.animateToPage(
                        _currentStep,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                      _showNotification(_getRequiredFieldsMessage(onboarding));
                      return;
                    }

                    _analyticsService.logUserInteraction(
                      interactionType: 'page_change',
                      target: 'step_$index',
                      parameters: {
                        'from_step': _currentStep,
                        'to_step': index,
                      },
                    );
                    _logOnboardingStep(index);
                    setState(() {
                      _previousStep = _currentStep;
                      _currentStep = index;
                    });
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
    switch (_currentStep) {
      case 0:
        return false;
      case 1: // Hedef seçimi
        return onboarding.goal == null;
      case 2: // Profil bilgileri
        return onboarding.gender == null ||
            onboarding.birthDate == null ||
            onboarding.weight == null ||
            onboarding.height == null;
      case 3: // Aktivite ve hedef kilo
        return onboarding.activityLevel == null ||
            onboarding.targetWeight == null;
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
    if (!shouldPreventScroll) {
      return super.applyBoundaryConditions(position, value);
    }

    if (value > position.pixels) {
      return value - position.pixels;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if (!shouldPreventScroll) {
      return super.createBallisticSimulation(position, velocity);
    }

    if (velocity > 0) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
