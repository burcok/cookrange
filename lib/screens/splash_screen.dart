import 'package:cookrange/core/providers/theme_provider.dart';
import 'package:cookrange/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/widgets/ds/ds.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math';

import '../core/services/crashlytics_service.dart';
import '../core/services/device_info_service.dart';
import '../core/services/app_initialization_service.dart';
import '../core/services/app_lifecycle_service.dart';
import '../core/services/system_ui_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/chat_service.dart';
import '../core/services/community_service.dart';
import '../core/services/friend_service.dart';
import '../core/services/billing_service.dart';
import '../core/localization/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/services/auth_service.dart';
import '../core/services/att_consent_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/providers/device_info_provider.dart';
import 'package:provider/provider.dart';
import '../core/providers/user_provider.dart';
import '../core/models/user_model.dart';
import 'onboarding/v2/onboarding_flow_screen.dart';
import '../core/utils/app_routes.dart';
import '../core/utils/onboarding_flow_resolver.dart';
import '../core/widgets/error_fallback_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Tracking state
  Timer? _connectivityTimer;
  int _countdownSeconds = 10;
  bool _isResourcesLoaded = false;
  DateTime? _startTime;
  bool _isCacheComplete = false;
  final minimumDisplayTime = const Duration(seconds: 5);
  bool _hasReachedMinimumTime = false;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  OverlayEntry? _overlayEntry;

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
    _startTime = DateTime.now();

    // 1. Initialize animations FIRST (synchronous, instant)
    _initializeAnimations();

    // 2. Start animations IMMEDIATELY after the first frame is rendered
    //    This is the key fix: Don't wait for anything else.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimations();
    });

    // 3. Run ALL heavy initialization in the BACKGROUND (non-blocking)
    //    This includes AppInitializationService which was previously in main.dart
    _runBackgroundInitialization();

    // 4. Setup connectivity listener (lightweight)
    _setupConnectivityListener();
    _startConnectivityTimer();
  }

  /// All heavy initialization runs here, completely decoupled from animations.
  Future<void> _runBackgroundInitialization() async {
    try {
      debugPrint('SplashScreen: Starting background initialization...');

      // PHASE 1: Core App Initialization (Firebase, Hive, Auth, Analytics, dotenv)
      // This was previously blocking main.dart
      final initService = AppInitializationService();
      final result = await initService.initialize();

      if (!result.isSuccess) {
        debugPrint('SplashScreen: Core initialization failed: ${result.error}');
        if (mounted) {
          unawaited(Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ErrorFallbackWidget(
                error: result.error,
                onRetry: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.splash);
                },
              ),
            ),
          ));
        }
        return;
      }

      debugPrint('SplashScreen: Core initialization complete.');

      // PHASE 2: Initialize AppLifecycleService (was in MyApp.initState)
      AppLifecycleService().initialize();

      // PHASE 3: Load User Data (Essential for routing)
      if (AuthService().currentUser != null && mounted) {
        try {
          debugPrint('SplashScreen: Loading user data...');
          await Provider.of<UserProvider>(context, listen: false).loadUser();
          debugPrint('SplashScreen: User data loaded.');
        } catch (e) {
          debugPrint('SplashScreen: Error loading user data: $e');
        }
      } else {
        debugPrint('SplashScreen: No authenticated user — skipping user load.');
      }

      // PHASE 4: Fire-and-forget background preloading (non-blocking)
      _fireAndForgetPreloading();

      // PHASE 5: Device Info (non-critical, fire-and-forget)
      _initializeDeviceInfo();

      // Mark initialization as complete
      if (mounted) {
        setState(() {
          _isResourcesLoaded = true;
          _isCacheComplete = true;
        });
        _checkInitializationComplete();
      }
    } catch (e, stack) {
      debugPrint('SplashScreen: Background initialization error: $e');
      await CrashlyticsService().recordError(e, stack,
          reason: 'Splash background initialization failed');

      // Even on error, mark as complete so we don't hang forever
      if (mounted) {
        setState(() {
          _isResourcesLoaded = true;
          _isCacheComplete = true;
        });
        _checkInitializationComplete();
      }
    }
  }

  /// Fire-and-forget service preloading
  void _fireAndForgetPreloading() {
    if (AuthService().currentUser == null) return;

    // These run in background, we don't wait for them
    NotificationService()
        .preloadUnreadCount()
        .catchError((e) => debugPrint('Notif preload error: $e'));
    ChatService()
        .preloadChats()
        .catchError((e) => debugPrint('Chat preload error: $e'));
    CommunityService()
        .preloadFeeds()
        .catchError((e) => debugPrint('Community preload error: $e'));
    FriendService()
        .preloadFriends()
        .catchError((e) => debugPrint('Friend preload error: $e'));
    BillingService()
        .initialize()
        .catchError((e) => debugPrint('Billing init error: $e'));
    DeepLinkService()
        .init(AuthService().navigatorKey)
        .catchError((e) => debugPrint('DeepLink init error: $e'));
    PushNotificationService().setNavigatorKey(AuthService().navigatorKey);
  }

  /// Fire-and-forget device info initialization
  void _initializeDeviceInfo() {
    if (!mounted) return;
    final deviceInfoProvider =
        Provider.of<DeviceInfoProvider>(context, listen: false);

    Future(() async {
      try {
        await deviceInfoProvider.initialize();

        // Send to Firebase (non-blocking)
        final deviceInfoService = DeviceInfoService();
        await deviceInfoService.sendDeviceInfoToFirebase(deviceInfoProvider,
            detailed: true);
        debugPrint('SplashScreen: Device info sent to Firebase.');
      } catch (e) {
        debugPrint('SplashScreen: Device info error: $e');
      }
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
    if (_overlayEntry != null) return;
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
                decoration: BoxDecoration(
                  color: AppPalette.of(context).error,
                  borderRadius: const BorderRadius.only(
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
  }

  void _updateColorAnimations(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

  void _checkInitializationComplete() {
    if (_isResourcesLoaded) {
      final elapsedTime = DateTime.now().difference(_startTime!);

      if (elapsedTime < minimumDisplayTime) {
        Future.delayed(minimumDisplayTime - elapsedTime, () {
          if (mounted) {
            setState(() {
              _hasReachedMinimumTime = true;
            });
            _checkShouldProceed();
          }
        });
      } else {
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
    debugPrint('SplashScreen: Navigating. User: $user');
    if (user == null) {
      // Always show the intro carousel for unauthenticated users — the one-shot
      // intro_seen gate has been removed so returning/logged-out users always
      // see the intro before reaching login.
      if (!mounted) return;
      unawaited(Navigator.pushReplacementNamed(context, AppRoutes.intro));
      return;
    }

    // Email verification is enforced as a hard gate in RouteGuard — unverified
    // users are redirected to /verify_email on any protected route.
    debugPrint('SplashScreen: Fetching user document...');
    final userModel = await AuthService().getUserData(user.uid);
    debugPrint('SplashScreen: User data: ${userModel?.email}');

    // Merge private nutrition PII (owner-only subcollection) so the
    // completeness check and OnboardingProvider get the full picture.
    debugPrint('SplashScreen: Fetching private nutrition data...');
    final privateNutrition = userModel != null
        ? await FirestoreService().getPrivateNutritionData(userModel.uid)
        : null;
    debugPrint('SplashScreen: Private nutrition data loaded.');
    final mergedModel = (userModel != null && privateNutrition != null)
        ? userModel.withPrivateNutrition(privateNutrition)
        : userModel;

    // Update UserProvider with the merged model immediately.
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setUser(mergedModel);

    if (!mounted) return;

    // Request ATT before any navigation.
    await ATTConsentService().requestIfNeeded();
    if (!mounted) return;

    final destination = OnboardingFlowResolver.resolve(mergedModel);

    // A logged-in but unfinished account completes onboarding via the V2 flow in
    // logged-in mode: it prefills from UserProvider (set above) and persists back
    // to the same uid instead of creating a new account. The flow owns the
    // prefill — see onboarding_flow_screen.dart.
    unawaited(Navigator.pushReplacementNamed(
      context,
      destination.route,
      arguments: destination.route == AppRoutes.onboardingV2
          ? OnboardingFlowScreen.loggedInCompletionArgs
          : null,
    ));
    // Drain any cold-start notification tap once /main is built.
    if (destination.route == AppRoutes.main) {
      PushNotificationService().drainPendingNavigation();
    }
  }

  void _checkShouldProceed() {
    if (_hasReachedMinimumTime && _isCacheComplete && !_isOffline) {
      if (mounted) {
        _navigateAfterSplash();
      }
    }
  }

  // Replaced by OnboardingFlowResolver.resolve() — kept in case any downstream
  // caller references this symbol until migrated. Delegates to the resolver.
  // ignore: unused_element
  bool _isOnboardingDataComplete(UserModel? userModel) {
    if (userModel == null) return false;
    final dest = OnboardingFlowResolver.resolve(userModel);
    return dest.route == AppRoutes.main;
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
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _iconInitialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _iconSecondSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

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

    _colorTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startGreetingTextAnimation();
      }
    });
  }

  Future<void> _startAnimations() async {
    if (!mounted) return;
    debugPrint('SplashScreen: Starting animations...');

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

    unawaited(_mainController.forward());
    debugPrint('SplashScreen: Animations complete.');
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
    unawaited(_startGreetingTextAnimation());
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
                          color: context.watch<ThemeProvider>().primaryColor,
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
                'Total Time: ${_startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds / 1000 : 0}s',
              ),
              Text(
                'Init Complete: ${_isCacheComplete ? "Yes" : "No"}',
              ),
              Text(
                'Min Time: ${_hasReachedMinimumTime ? "Yes" : "No"}',
              ),
              Text(
                'Offline: ${_isOffline ? "Yes" : "No"}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
