import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import '../core/services/analytics_service.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _analyticsService = AnalyticsService();
  bool _isInitialized = false;
  String? _error;
  bool _showSplash = true;
  late final WebViewController _webViewController;
  bool _isWebViewLoaded = false;
  Timer? _splashTimer;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initialize();
    _initializeWebView();
    _splashTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isInitialized) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isWebViewLoaded = true;
              _isLoading = false;
              _retryCount = 0;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
              _error = 'WebView yüklenirken hata oluştu: ${error.description}';
            });
            
            // Retry logic
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(Duration(seconds: 2), () {
                if (mounted) {
                  _retryLoadWebView();
                }
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://embed.figma.com/proto/2Pxwm1TGUjWnDBrjbiVBEa/Cookrange?node-id=141-3222&p=f&scaling=scale-down&content-scaling=fixed&page-id=0%3A1&starting-point-node-id=141%3A3215&show-proto-sidebar=1&embed-host=share'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
  }

  void _retryLoadWebView() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      _webViewController.reload();
    }
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>([
        _initializeHive(),
        _initializeEnvironment(),
        _initializePreferences(),
      ]);

      await _analyticsService.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      print('Error during initialization: $e');
      print('Stack trace: $stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initializeHive() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    await Future.wait<void>([
      Hive.openBox('appBox'),
      Hive.openBox('userBox'),
      Hive.openBox('settingsBox'),
    ]);
  }

  Future<void> _initializeEnvironment() async {
    await dotenv.load(fileName: ".env");
  }

  Future<void> _initializePreferences() async {
    await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash && _isInitialized) {
      return const OnboardingScreen();
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            if (_isWebViewLoaded)
              IgnorePointer(
                child: WebViewWidget(controller: _webViewController),
              ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (_error != null)
              Positioned(
                bottom: 32,
                left: 32,
                right: 32,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Başlatma hatası: $_error',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 14,
                        ),
                      ),
                      if (_retryCount < _maxRetries)
                        TextButton(
                          onPressed: _retryLoadWebView,
                          child: Text(
                            'Tekrar Dene',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
