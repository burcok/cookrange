import 'package:cookrange/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math';

import '../core/services/crashlytics_service.dart';
import '../core/services/device_info_service.dart';
import '../core/services/app_initialization_service.dart';
import '../core/services/system_ui_service.dart';
import '../core/services/performance_service.dart';
import '../core/localization/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/services/auth_service.dart';
import '../core/providers/device_info_provider.dart';
import 'package:provider/provider.dart';
import '../core/providers/onboarding_provider.dart';
import '../core/models/user_model.dart';
import '../core/utils/app_routes.dart';
import '../core/widgets/error_fallback_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _isInitialized = false;
  Timer? _connectivityTimer;
  int _countdownSeconds = 10;
  final Completer<void> _iconLoadCompleter = Completer<void>();
  final Completer<void> _textLoadCompleter = Completer<void>();
  bool _isResourcesLoaded = false;
  DateTime? _startTime;
  bool _hasPrecachedImages = false;
  bool _shouldPreloadOnboardingImages = false;
  bool _isCacheComplete = false;
  final minimumDisplayTime = const Duration(seconds: 5);
  bool _hasReachedMinimumTime = false;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  OverlayEntry? _overlayEntry;
  bool _animationsStarted = false;

  // Animation Controllers
  late AnimationController _mainController;
  late AnimationController _iconInitialController;
  late AnimationController _iconSecondSlideController;
  late AnimationController _iconShrinkController;
  late AnimationController _textFadeController;
  late AnimationController _colorTransitionController;
  late AnimationController _greetingTextController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<Offset> _iconSlideAnimation;
  late Animation<Offset> _iconSecondSlideAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<Color?> _backgroundColorAnimation;
  late Animation<Color?> _iconColorAnimation;
  late Animation<Color?> _textColorAnimation;
  late Animation<double> _greetingTextOpacityAnimation;
  late Animation<Offset> _greetingTextSlideAnimation;

  int _currentMessageIndex = 0;
  List<String> _loadingMessages = [];
  List<int> _remainingMessageIndices = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupConnectivityListener();
    _checkConnectivity(); // Check connectivity on start
    _startConnectivityTimer();

    Future.wait([_iconLoadCompleter.future, _textLoadCompleter.future])
        .then((_) {
      if (mounted) {
        _startAnimations();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection && _isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = false;
          });
          _removeNoInternetOverlay();
          _connectivityTimer?.cancel();
          if (!_isInitialized) {
            _initialize();
          }
        }
      } else if (!hasConnection && !_isOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    });
  }

  void _startConnectivityTimer() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isOffline && mounted) {
        setState(() {
          _countdownSeconds--;
        });
        if (_overlayEntry != null) {
          _overlayEntry!.markNeedsBuild();
        }
        if (_countdownSeconds <= 0) {
          _countdownSeconds = 10;
          _checkConnectivity();
        }
      }
    });
  }

  void _showNoInternetOverlay() {
    if (_overlayEntry != null) {
      return; // Overlay already shown
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '${AppLocalizations.of(context).translate('common.no_internet')}\n${AppLocalizations.of(context).translate('common.retry_in_seconds').replaceAll('{seconds}', _countdownSeconds.toString())}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _removeNoInternetOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context);
    _loadingMessages = localizations.translateArray('splash.loading_messages');
    _remainingMessageIndices = List.generate(_loadingMessages.length, (i) => i);
    _updateColorAnimations(context);

    // Update system UI based on theme
    SystemUIService().updateSystemUIOverlayStyle(context);

    if (!_hasPrecachedImages) {
      _hasPrecachedImages = true;
      _isOnboardingCompleted().then((completed) {
        if (!completed) {
          _shouldPreloadOnboardingImages = true;
        }
      });
    }
  }

  void _updateColorAnimations(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Color transitions
    _backgroundColorAnimation = ColorTween(
      begin: colorScheme.onboardingOptionBgColor,
      end: colorScheme.splashPrimaryColor,
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    _iconColorAnimation = ColorTween(
      begin: colorScheme.splashPrimaryColor,
      end: colorScheme.secondary,
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    _textColorAnimation = ColorTween(
      begin: colorScheme.splashPrimaryColor,
      end: colorScheme.secondary,
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _connectivitySubscription?.cancel();
    _removeNoInternetOverlay();
    _mainController.dispose();
    _iconInitialController.dispose();
    _iconSecondSlideController.dispose();
    _iconShrinkController.dispose();
    _textFadeController.dispose();
    _colorTransitionController.dispose();
    _greetingTextController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _startTime = DateTime.now();

      // Check if app initialization was successful
      final initService = AppInitializationService();
      if (!initService.isInitialized) {
        // If initialization failed, show error screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ErrorFallbackWidget(
                error: initService.initializationError,
                onRetry: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.splash);
                },
              ),
            ),
          );
        }
        return;
      }

      // Use performance service to execute operations in parallel
      await PerformanceService.executeInParallel([
        _preloadResources,
      ], eagerError: false)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Splash initialization timed out, proceeding anyway');
        return [];
      });

      // This part depends on context, so it runs after initializations
      if (!mounted) return;

      // Initialize device info provider with retry mechanism
      final deviceInfoProvider =
          Provider.of<DeviceInfoProvider>(context, listen: false);

      await PerformanceService.executeWithRetry(
        () => deviceInfoProvider.initialize(),
        maxRetries: 2,
        delay: const Duration(milliseconds: 500),
      );

      // Send device info to Firebase without waiting for it to complete
      _sendDeviceInfoToFirebase(deviceInfoProvider);

      if (mounted) {
        setState(() {
          _isResourcesLoaded = true;
          _isCacheComplete = true;
        });
        _checkInitializationComplete();
      }
    } catch (e, stack) {
      debugPrint('Error during splash initialization: $e');
      debugPrint('Stack trace: $stack');
      await CrashlyticsService()
          .recordError(e, stack, reason: 'Splash screen initialization failed');

      if (mounted) {
        // Show error screen instead of continuing
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ErrorFallbackWidget(
              error: e.toString(),
              onRetry: () {
                Navigator.pushReplacementNamed(context, AppRoutes.splash);
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _preloadResources() async {
    await _precacheAppImages();
  }

  Future<void> _precacheAppImages() async {
    if (!mounted) return;

    final imagePaths = [
      'assets/images/splash/cookrange-icon.svg',
      'assets/images/splash/cookrange-text.svg',
    ];

    if (_shouldPreloadOnboardingImages) {
      imagePaths.addAll([
        'assets/images/onboarding/onboarding-1.png',
        'assets/images/onboarding/onboarding-5-1.png',
        'assets/images/onboarding/onboarding-5-2.png',
        'assets/images/onboarding/onboarding-5-3.png',
        'assets/images/onboarding/onboarding-5-4.png',
        'assets/images/onboarding/onboarding-5-5.png',
        'assets/images/onboarding/verify-email.png',
      ]);
    }

    await Future.wait(imagePaths.map((path) {
      if (path.endsWith('.svg')) {
        // TODO: The following line causes linter errors. Investigate flutter_svg dependency and precaching.
        // return precachePicture(
        //   AssetPicture(SvgPicture.svgByteDecoder, path),
        //   context,
        // );
        return Future.value(); // Return a completed future.
      } else {
        return precacheImage(AssetImage(path), context);
      }
    }));
  }

  Future<bool> _isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    // Adjust the key according to your onboarding completion logic
    return prefs.getBool('onboarding_completed') ?? false;
  }

  void _checkInitializationComplete() {
    if (_isResourcesLoaded) {
      final elapsedTime = DateTime.now().difference(_startTime!);

      if (elapsedTime < minimumDisplayTime) {
        // If less than minimum time has passed, wait for the remaining time
        Future.delayed(minimumDisplayTime - elapsedTime, () {
          if (mounted) {
            setState(() {
              _hasReachedMinimumTime = true;
            });
            _checkShouldProceed();
          }
        });
      } else {
        // If minimum time has passed, check if we can proceed
        if (mounted) {
          setState(() {
            _hasReachedMinimumTime = true;
          });
          _checkShouldProceed();
        }
      }
    }
  }

  Future<void> _navigateAfterSplash() async {
    if (!mounted) return;

    final user = AuthService().currentUser;
    debugPrint('User: $user');
    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    if (!user.emailVerified) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.verifyEmail,
        (route) => false,
      );
      return;
    }

    final userModel = await AuthService().getUserData(user.uid);
    debugPrint('User data: ${userModel?.email}');

    // Check if user is verified in Firestore (user_verified field)
    if (userModel?.userVerified == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.verifyEmail,
        (route) => false,
      );
      return;
    }

    if (!mounted) return;

    if (_isOnboardingDataComplete(userModel)) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else {
      if (userModel?.onboardingData != null) {
        Provider.of<OnboardingProvider>(context, listen: false)
            .initializeFromFirestore(userModel!.onboardingData!);
      }
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    }
  }

  void _checkShouldProceed() {
    if (_hasReachedMinimumTime && _isCacheComplete && !_isOffline) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _navigateAfterSplash();
      }
    }
  }

  bool _isOnboardingDataComplete(UserModel? userModel) {
    if (userModel == null || !userModel.onboardingCompleted) {
      return false;
    }

    final onboardingData = userModel.onboardingData;

    if (onboardingData == null) {
      return false;
    }

    final primaryGoals = onboardingData['primary_goals'];
    final kitchenEquipments = onboardingData['kitchen_equipments'];

    // Check for essential fields
    return onboardingData['personal_info']['gender'] != null &&
        onboardingData['personal_info']['birth_date'] != null &&
        onboardingData['personal_info']['height'] != null &&
        onboardingData['personal_info']['weight'] != null &&
        (primaryGoals is List
            ? primaryGoals.isNotEmpty
            : primaryGoals != null) &&
        onboardingData['cooking_level'] != null &&
        onboardingData['activity_level'] != null &&
        onboardingData['meal_schedule'] != null &&
        (kitchenEquipments is List
            ? kitchenEquipments.isNotEmpty
            : kitchenEquipments != null);
  }

  /// Cihaz bilgilerini Firebase Analytics'e gönder
  Future<void> _sendDeviceInfoToFirebase(
      DeviceInfoProvider deviceInfoProvider) async {
    try {
      final deviceInfoService = DeviceInfoService();
      await deviceInfoService.sendDeviceInfoToFirebase(deviceInfoProvider,
          detailed: true);
      debugPrint('Device info sent to Firebase Analytics successfully');
    } catch (e) {
      debugPrint('Error sending device info to Firebase Analytics: $e');
      // Hata durumunda crashlytics'e log at
      await CrashlyticsService()
          .log('Error sending device info to Firebase Analytics: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;

    final hasConnection =
        connectivityResult.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      setState(() {
        _isOffline = true;
        _countdownSeconds = 10;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetOverlay();
      });
    } else {
      setState(() {
        _isOffline = false;
      });
      _removeNoInternetOverlay();
      _connectivityTimer?.cancel();
      _checkShouldProceed();
    }
  }

  void _initializeAnimations() {
    // Main controller for overall timing
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // Icon initial animation (1s)
    _iconInitialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Icon second slide animation (800ms)
    _iconSecondSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Icon shrink animation (800ms)
    _iconShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Text fade animation (800ms)
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Color transition animation (1s)
    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Greeting text animation
    _greetingTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _greetingTextSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _greetingTextController,
        curve: Curves.easeOut,
      ),
    );

    _greetingTextOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _greetingTextController,
        curve: Curves.easeIn,
      ),
    );

    // Icon initial animations
    _iconScaleAnimation = Tween<double>(begin: 0.85, end: 0.25).animate(
      CurvedAnimation(
        parent: _iconInitialController,
        curve: Curves.easeInOutBack,
      ),
    );

    _iconSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _iconInitialController,
        curve: Curves.easeInOutBack,
      ),
    );

    _iconSecondSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.4, 0),
    ).animate(
      CurvedAnimation(
        parent: _iconSecondSlideController,
        curve: Curves.easeInOutBack,
      ),
    );

    _iconOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconInitialController,
        curve: Curves.easeInOutBack,
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: -179, end: 0).animate(
      CurvedAnimation(
        parent: _iconInitialController,
        curve: Curves.easeInOutBack,
      ),
    );

    // Text fade animation
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textFadeController,
        curve: Curves.easeInOut,
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.2, -5.25),
    ).animate(
      CurvedAnimation(
        parent: _iconInitialController,
        curve: Curves.easeInOutBack,
      ),
    );

    // Start greeting text animation after color transition
    _colorTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startGreetingTextAnimation();
      }
    });
  }

  Future<void> _startAnimations() async {
    if (_animationsStarted || !mounted) return;
    _animationsStarted = true;
    _startTime = DateTime.now();

    await _iconInitialController.forward();
    if (!mounted) return;
    await _iconSecondSlideController.forward();
    if (!mounted) return;

    await Future.wait([
      _textFadeController.forward(),
      _iconShrinkController.forward(),
    ]);
    if (!mounted) return;

    await _colorTransitionController.forward();
    if (!mounted) return;

    _mainController.forward();
  }

  Future<void> _startGreetingTextAnimation() async {
    if (!mounted) return;
    await _greetingTextController.forward();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _greetingTextController.reverse();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    setState(() {
      if (_remainingMessageIndices.isEmpty) {
        _remainingMessageIndices =
            List.generate(_loadingMessages.length, (i) => i);
      }
      _remainingMessageIndices.remove(_currentMessageIndex);
      if (_remainingMessageIndices.isNotEmpty) {
        _currentMessageIndex = (_remainingMessageIndices..shuffle()).first;
      }
    });
    _startGreetingTextAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final iconSize = min(screenSize.width, screenSize.height) * 0.8;
    final textWidth = min(screenSize.width, screenSize.height) * 0.45;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _iconInitialController,
        _iconSecondSlideController,
        _iconShrinkController,
        _textFadeController,
        _colorTransitionController,
        _greetingTextController,
      ]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundColorAnimation.value,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlideTransition(
                        position: _iconSlideAnimation,
                        child: SlideTransition(
                          position: _iconSecondSlideAnimation,
                          child: Transform.rotate(
                            angle:
                                _iconRotationAnimation.value * (3.14159 / 180),
                            child: Transform.scale(
                              scale: _iconScaleAnimation.value,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity:
                                    _iconOpacityAnimation.value.clamp(0.0, 1.0),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    _iconColorAnimation.value ?? Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/images/splash/cookrange-icon.svg',
                                    width: iconSize,
                                    height: iconSize,
                                    placeholderBuilder: (context) {
                                      if (!_iconLoadCompleter.isCompleted) {
                                        _iconLoadCompleter.complete();
                                      }
                                      return SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _textOpacityAnimation.value.clamp(0.0, 1.0),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _textColorAnimation.value ?? Colors.black,
                              BlendMode.srcIn,
                            ),
                            child: SvgPicture.asset(
                              'assets/images/splash/cookrange-text.svg',
                              width: textWidth,
                              placeholderBuilder: (context) {
                                if (!_textLoadCompleter.isCompleted) {
                                  _textLoadCompleter.complete();
                                }
                                return SizedBox(
                                  width: textWidth,
                                  height: 50,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading message at the bottom
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _greetingTextSlideAnimation,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _greetingTextOpacityAnimation.value,
                      child: Text(
                        _loadingMessages.isNotEmpty
                            ? _loadingMessages[_currentMessageIndex]
                            : '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                // Debug information
                if (kDebugMode) _buildDebugOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Icon Loaded: ${_iconLoadCompleter.isCompleted ? "Yes" : "No"}',
              ),
              Text(
                'Text Loaded: ${_textLoadCompleter.isCompleted ? "Yes" : "No"}',
              ),
              Text(
                'Icon Initial: ${(_iconInitialController.value * 100).toStringAsFixed(1)}%',
              ),
              Text(
                'Icon Shrink: ${(_iconShrinkController.value * 100).toStringAsFixed(1)}%',
              ),
              Text(
                'Text Fade: ${(_textFadeController.value * 100).toStringAsFixed(1)}%',
              ),
              Text(
                'Color Transition: ${(_colorTransitionController.value * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 8),
              Text(
                'Total Time: ${_startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds / 1000 : 0} seconds',
              ),
              Text(
                'Min Duration: ${minimumDisplayTime.inSeconds} seconds',
              ),
              Text(
                'Cache Complete: ${_isCacheComplete ? "Yes" : "No"}',
              ),
              Text(
                'Min Time Reached: ${_hasReachedMinimumTime ? "Yes" : "No"}',
              ),
              Text(
                'Offline Mode: ${_isOffline ? "Yes" : "No"}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
