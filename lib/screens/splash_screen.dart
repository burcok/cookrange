import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/svg.dart' show SvgPicture;
import 'dart:async';
import '../core/services/analytics_service.dart';
import '../core/services/crashlytics_service.dart';
import '../core/localization/app_localizations.dart';
import 'onboarding/onboarding_screen.dart';
import '../widgets/date_picker_modal.dart';
import '../widgets/number_picker_modal.dart';
import '../widgets/gender_picker_modal.dart';
import '../widgets/language_selector.dart';
import '../widgets/custom_back_button.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final _analyticsService = AnalyticsService();
  bool _isInitialized = false;
  String? _error;
  bool _showSplash = true;
  Timer? _splashTimer;
  bool _isLoading = true;
  bool _isIconLoaded = false;
  bool _isTextLoaded = false;
  bool _isResourcesLoaded = false;
  DateTime? _startTime;
  bool _hasPrecachedImages = false;
  bool _shouldPreloadOnboardingImages = false;

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

    // Color transitions
    _backgroundColorAnimation = ColorTween(
      begin: Colors.white,
      end: const Color(0xFFFFB33A),
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    _iconColorAnimation = ColorTween(
      begin: const Color(0xFFFFB33A),
      end: const Color(0xFF171F34),
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    _textColorAnimation = ColorTween(
      begin: const Color(0xFFFFB33A),
      end: const Color(0xFF171F34),
    ).animate(
      CurvedAnimation(
        parent: _colorTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    // Greeting text animation
    _greetingTextOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _greetingTextController,
        curve: Curves.easeInOut,
      ),
    );

    _greetingTextSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 2.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _greetingTextController,
        curve: Curves.easeOutBack,
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
            // Cache widgets after all animations are complete
            _precacheWidgets();
          });
        });
      });
    });

    _splashTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isInitialized) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  void _startGreetingTextAnimation() {
    _greetingTextController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _greetingTextController.reverse().then((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            setState(() {
              if (_remainingMessageIndices.isEmpty) {
                // Tüm mesajlar gösterildiyse, tekrar başlat
                _remainingMessageIndices =
                    List.generate(_loadingMessages.length, (i) => i);
              }
              // Şu anki mesajı tekrar göstermemek için mevcut indexi çıkar
              _remainingMessageIndices.remove(_currentMessageIndex);
              if (_remainingMessageIndices.isNotEmpty) {
                _currentMessageIndex =
                    (_remainingMessageIndices..shuffle()).first;
              }
            });
            _startGreetingTextAnimation();
          });
        });
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context);
    _loadingMessages = List.generate(
        10, (index) => localizations.translate('splashLoadingMessage$index'));
    _remainingMessageIndices = List.generate(_loadingMessages.length, (i) => i);
    if (!_hasPrecachedImages) {
      _hasPrecachedImages = true;
      _isOnboardingCompleted().then((completed) {
        if (!completed) {
          _shouldPreloadOnboardingImages = true;
          _preloadImages();
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
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
      // 1. Firebase, Crashlytics, Analytics
      await CrashlyticsService().initialize();
      await AnalyticsService().initialize();
      // 2. Dotenv, SharedPreferences
      await _initializeEnvironment();
      await _initializePreferences();
      // 3. Asset ve font cache
      await _precacheAssets();
      // 4. Diğer preload işlemleri
      await _preloadResources();
      if (mounted) {
        setState(() {
          _isResourcesLoaded = true;
        });
        _checkInitializationComplete();
      }
    } catch (e, stack) {
      // Sadece logla, kullanıcıya gösterme
      print('Error during initialization: $e');
      print('Stack trace: $stack');
      await CrashlyticsService().log(e.toString());
      await CrashlyticsService().log(stack.toString());
      // Hata UI'da gösterilmeyecek
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
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
      const minimumDisplayTime = Duration(seconds: 5);

      if (elapsedTime < minimumDisplayTime) {
        // If less than 5 seconds have passed, wait for the remaining time
        Future.delayed(minimumDisplayTime - elapsedTime, () {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _isLoading = false;
              _showSplash = false;
            });
          }
        });
      } else {
        // If more than 5 seconds have passed, proceed immediately
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
            _showSplash = false;
          });
        }
      }
    }
  }

  Future<void> _precacheAssets() async {
    // Sık kullanılan görselleri ve fontları cache'le
    final imagePaths = [
      'assets/images/onboarding/onboarding-1.png',
      'assets/images/onboarding/onboarding-2-1.png',
      'assets/images/onboarding/onboarding-2-2.png',
      'assets/images/onboarding/onboarding-2-3.png',
      'assets/images/onboarding/onboarding-2-4.png',
      'assets/images/onboarding/onboarding-5.png',
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
    // Sadece gerekli widget'ları cache'le
    final widgets = [
      GenderPickerModal(
        selectedGender: null,
        onSelected: (_) {},
      ),
      const LanguageSelector(),
      CustomBackButton(onTap: () {}),
    ];
    for (final widget in widgets) {
      final overlay = Overlay.of(context);
      if (overlay != null) {
        final entry = OverlayEntry(builder: (_) => Material(child: widget));
        overlay.insert(entry);
        await Future.delayed(const Duration(milliseconds: 10));
        entry.remove();
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (connectivityResult == ConnectivityResult.none) {
      // Bağlantı yoksa kullanıcıya bildirim göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate('common.no_internet')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: localizations.translate('common.retry'),
              textColor: Colors.white,
              onPressed: _checkConnectivity,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash && _isInitialized) {
      return const OnboardingScreen();
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
                        _loadingMessages[_currentMessageIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Color(0xFF171F34),
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
