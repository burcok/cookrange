import 'package:cookrange/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/svg.dart' show SvgPicture;
import 'dart:async';
import '../core/services/analytics_service.dart';
import '../core/services/crashlytics_service.dart';
import '../core/services/device_info_service.dart';
import '../core/localization/app_localizations.dart';
import '../widgets/gender_picker_modal.dart';
import '../widgets/custom_back_button.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/date_picker_modal.dart';
import '../widgets/number_picker_modal.dart';
import '../core/services/auth_service.dart';
import '../core/providers/device_info_provider.dart';
import 'package:provider/provider.dart';
import '../core/providers/onboarding_provider.dart';
import '../core/models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _isInitialized = false;
  bool _showSplash = true;
  Timer? _splashTimer;
  Timer? _connectivityTimer;
  int _countdownSeconds = 10;
  bool _isIconLoaded = false;
  bool _isTextLoaded = false;
  bool _isResourcesLoaded = false;
  DateTime? _startTime;
  DateTime? _cacheStartTime;
  bool _hasPrecachedImages = false;
  bool _shouldPreloadOnboardingImages = false;
  bool _isCacheComplete = false;
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
    _checkConnectivity();
    _initialize();
    _initializeAnimations();
    _setupConnectivityListener();
    _startConnectivityTimer();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result != ConnectivityResult.none && _isOffline) {
        setState(() {
          _isOffline = false;
        });
        _removeNoInternetOverlay();
        _connectivityTimer?.cancel();
        // Bağlantı geldiğinde kaldığımız yerden devam et
        if (!_isInitialized) {
          _initialize();
        }
      } else if (result == ConnectivityResult.none && !_isOffline) {
        setState(() {
          _isOffline = true;
        });
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
    _overlayEntry?.remove();
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

    Overlay.of(context).insert(_overlayEntry!);
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
    if (!_hasPrecachedImages) {
      _hasPrecachedImages = true;
      _isOnboardingCompleted().then((completed) {
        if (!completed) {
          _shouldPreloadOnboardingImages = true;
          // _preloadImages(); // ANR hatasına neden olabilecek resim ön yükleme işlemi test için kapatıldı.
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
    _splashTimer?.cancel();
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
      // 1. Run independent initializations in parallel
      await Future.wait([
        CrashlyticsService().initialize(),
        AnalyticsService().initialize(),
        AuthService().initialize(),
        _initializeEnvironment(),
        _initializePreferences(),
        _preloadResources(),
      ]);

      // This part depends on context, so it runs after initializations
      if (!mounted) return;

      // Initialize device info provider
      final deviceInfoProvider =
          Provider.of<DeviceInfoProvider>(context, listen: false);
      await deviceInfoProvider.initialize();

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
      print('Error during initialization: $e');
      print('Stack trace: $stack');
      await CrashlyticsService().log(e.toString());
      await CrashlyticsService().log(stack.toString());
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isCacheComplete = true;
        });
      }
    }
  }

  Future<void> _initializeEnvironment() async {
    await dotenv.load(fileName: ".env");
  }

  Future<void> _initializePreferences() async {
    await SharedPreferences.getInstance();
  }

  Future<void> _preloadResources() async {
    // Preload all necessary resources here
    await Future.wait<void>([
      _preloadFonts(),
      _preloadData(),
    ]);
  }

  Future<void> _preloadImages() async {
    // Preload onboarding images only if needed
    if (!_shouldPreloadOnboardingImages) return;
    final imagePaths = [
      'assets/images/onboarding/onboarding-1.png',
      'assets/images/onboarding/onboarding-2-1.png',
      'assets/images/onboarding/onboarding-2-2.png',
      'assets/images/onboarding/onboarding-2-3.png',
      'assets/images/onboarding/onboarding-2-4.png',
      'assets/images/onboarding/onboarding-5.png',
      // Add other image paths that need to be preloaded
    ];
    for (final path in imagePaths) {
      await precacheImage(AssetImage(path), context);
    }
  }

  Future<void> _preloadFonts() async {
    // Preload fonts
    await Future.wait<void>([
      // Add font preloading if needed
    ]);
  }

  Future<void> _preloadData() async {
    // Preload any necessary data
    await Future.wait<void>([
      // Add data preloading tasks here
    ]);
  }

  Future<bool> _isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    // Adjust the key according to your onboarding completion logic
    return prefs.getBool('onboarding_completed') ?? false;
  }

  void _checkInitializationComplete() {
    if (_isResourcesLoaded) {
      final elapsedTime = DateTime.now().difference(_startTime!);
      const minimumDisplayTime = Duration(seconds: 2);

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

  void _checkShouldProceed() async {
    if (_hasReachedMinimumTime && _isCacheComplete && !_isOffline) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        final user = AuthService().currentUser;
        print('User: $user');
        if (user == null) {
          // No user, go to login screen
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        if (!user.emailVerified) {
          // User exists but email is not verified
          Navigator.pushReplacementNamed(context, '/verify_email');
          return;
        }

        // User exists, check their data
        final userModel = await AuthService().getUserData(user.uid);
        print('User data: ${userModel?.email}');

        if (_isOnboardingDataComplete(userModel)) {
          // User has completed all onboarding, go to home
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // User has not completed onboarding, go to onboarding
          if (userModel?.onboardingData != null) {
            Provider.of<OnboardingProvider>(context, listen: false)
                .initializeFromFirestore(userModel!.onboardingData!);
          }
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
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
    return onboardingData['gender'] != null &&
        onboardingData['birth_date'] != null &&
        onboardingData['height'] != null &&
        onboardingData['weight'] != null &&
        onboardingData['target_weight'] != null &&
        (primaryGoals is List
            ? primaryGoals.isNotEmpty
            : primaryGoals != null) &&
        onboardingData['cooking_level'] != null &&
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
      print('Device info sent to Firebase Analytics successfully');
    } catch (e) {
      print('Error sending device info to Firebase Analytics: $e');
      // Hata durumunda crashlytics'e log at
      await CrashlyticsService()
          .log('Error sending device info to Firebase Analytics: $e');
    }
  }

  Future<void> _precacheAssets() async {
    // Sık kullanılan görselleri ve fontları cache'le
    final imagePaths = [
      'assets/images/onboarding/onboarding-1.png',
      'assets/images/splash/cookrange-icon.svg',
      'assets/images/splash/cookrange-text.svg',
      // ... diğer assetler ...
    ];
    for (final path in imagePaths) {
      if (!path.endsWith('.svg')) {
        await precacheImage(AssetImage(path), context);
      }
    }
    // Fontlar pubspec.yaml ile otomatik cache'lenir, ekstra gerek yok.
  }

  Future<void> _precacheWidgets() async {
    if (!mounted) return;

    // Widget'ları build et ve hemen kaldır
    final overlay = Overlay.of(context);

    // Tüm widget'ları tek bir overlay entry'de build et
    final entry = OverlayEntry(
      builder: (_) => Opacity(
        opacity: 0.0,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              GenderPickerModal(
                selectedGender: null,
                onSelected: (_) {},
              ),
              DatePickerModal(
                initialDate: DateTime.now(),
                minDate: DateTime(1900),
                maxDate: DateTime.now(),
                onSelected: (_) {},
              ),
              const NumberPickerModal(
                title: 'Select Number',
                min: 0,
                max: 100,
                initialValue: 0,
                unit: '',
              ),
              CustomBackButton(onTap: () {}),
            ],
          ),
        ),
      ),
    );

    // Widget'ları build et ve hemen kaldır
    overlay.insert(entry);
    entry.remove();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;

    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _isOffline = true;
        _countdownSeconds = 10;
      });
      // Bağlantı yoksa kullanıcıya bildirim göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetOverlay();
      });
    } else {
      setState(() {
        _isOffline = false;
      });
      _removeNoInternetOverlay();
      _connectivityTimer?.cancel();
      // Bağlantı geldiğinde proceed kontrolü yap
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

  void _startAnimations() {
    _iconInitialController.forward().then((_) {
      _iconSecondSlideController.forward().then((_) {
        // Start text fade and icon shrink animations simultaneously
        Future.wait([
          _textFadeController.forward(),
          _iconShrinkController.forward(),
        ]).then((_) {
          _colorTransitionController.forward().then((_) {
            // Start the main controller for transition
            _mainController.forward();
            // Cache widgets after starting the transition
            if (mounted) {
              // _precacheWidgets();
            }
          });
        });
      });
    });
  }

  void _startGreetingTextAnimation() {
    _greetingTextController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _greetingTextController.reverse().then((_) {
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 100), () {
                setState(() {
                  if (_remainingMessageIndices.isEmpty) {
                    _remainingMessageIndices =
                        List.generate(_loadingMessages.length, (i) => i);
                  }
                  _remainingMessageIndices.remove(_currentMessageIndex);
                  if (_remainingMessageIndices.isNotEmpty) {
                    _currentMessageIndex =
                        (_remainingMessageIndices..shuffle()).first;
                  }
                });
                _startGreetingTextAnimation();
              });
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      _mainController.forward().then((_) {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
      });
    }

    if (!_showSplash) {
      // This part will now be handled by the _checkShouldProceed logic
      // Return a placeholder while navigating
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                                    width:
                                        MediaQuery.of(context).size.width * 0.8,
                                    height:
                                        MediaQuery.of(context).size.width * 0.8,
                                    placeholderBuilder: (context) {
                                      if (!_isIconLoaded) {
                                        _isIconLoaded = true;
                                        if (_isTextLoaded) {
                                          _startAnimations();
                                        }
                                      }
                                      return Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        height:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        color: Colors.grey.withOpacity(0.2),
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
                              width: MediaQuery.of(context).size.width * 0.45,
                              placeholderBuilder: (context) {
                                if (!_isTextLoaded) {
                                  _isTextLoaded = true;
                                  if (_isIconLoaded) {
                                    _startAnimations();
                                  }
                                }
                                return Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.45,
                                  height: 50,
                                  color: Colors.grey.withOpacity(0.2),
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
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                // Debug information
                if (kDebugMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assets Loaded: ${_isIconLoaded && _isTextLoaded ? "Yes" : "No"}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Icon Initial: ${(_iconInitialController.value * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Icon Shrink: ${(_iconShrinkController.value * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Text Fade: ${(_textFadeController.value * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Color Transition: ${(_colorTransitionController.value * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Time: ${_startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds / 1000 : 0} seconds',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Cache Time: ${_cacheStartTime != null ? DateTime.now().difference(_cacheStartTime!).inMilliseconds / 1000 : 0} seconds',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Min Duration: 4 seconds',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Cache Complete: ${_isCacheComplete ? "Yes" : "No"}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Min Time Reached: ${_hasReachedMinimumTime ? "Yes" : "No"}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Offline Mode: ${_isOffline ? "Yes" : "No"}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
