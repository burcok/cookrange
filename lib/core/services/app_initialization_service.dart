import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../firebase_options.dart';
import 'crashlytics_service.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'global_error_handler.dart';
import 'log_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai/ai_service.dart';

/// Comprehensive app initialization service that handles all startup tasks
/// with proper error handling, fallbacks, and user feedback.
class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'AppInitializationService';

  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initializationError;
  Map<String, dynamic> _initializationResults = {};
  Completer<InitializationResult>? _initCompleter;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get initializationError => _initializationError;
  Map<String, dynamic> get initializationResults => _initializationResults;

  /// Main initialization method with comprehensive error handling
  Future<InitializationResult> initialize() async {
    if (_isInitialized) {
      return InitializationResult.success(_initializationResults);
    }

    if (_isInitializing) {
      return _initCompleter!.future;
    }

    _isInitializing = true;
    _initCompleter = Completer<InitializationResult>();
    _initializationError = null;
    _initializationResults.clear();

    try {
      _log.info('Starting app initialization', service: _serviceName);

      // Step 1: Core Flutter setup
      await _initializeCore();

      // Step 2: Global error handling
      _initializeGlobalErrorHandling();

      // Step 3, 4, 5: Parallel initialization of independent core systems
      await Future.wait([
        _initializeFirebase(),
        _initializeLocalStorage(),
        _configureSystemUI(),
      ]);

      // Step 6: Services initialization
      await _initializeServices();

      // Step 7: Connectivity check
      await _checkConnectivity();

      _isInitialized = true;
      _log.info('App initialization completed successfully',
          service: _serviceName);

      return InitializationResult.success(_initializationResults);
    } catch (e, stackTrace) {
      _initializationError = e.toString();
      _log.error('App initialization failed',
          service: _serviceName, error: e, stackTrace: stackTrace);

      // Log to Crashlytics if available
      try {
        await CrashlyticsService().recordError(e, stackTrace,
            reason: 'App initialization failed', fatal: true);
      } catch (_) {
        // Ignore if Crashlytics is not available
      }

      return InitializationResult.failure(e.toString());
    } finally {
      _isInitializing = false;
      final result = _initializationError != null
          ? InitializationResult.failure(_initializationError!)
          : InitializationResult.success(_initializationResults);
      _initCompleter?.complete(result);
    }
  }

  /// Initialize core Flutter services
  Future<void> _initializeCore() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Configure debug vs release mode
      _configureDebugMode();

      // Load environment variables (Fixed path from assets/.env to .env)
      await dotenv.load(fileName: ".env");

      // Initialize AI Service
      final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
      AIService().initialize(apiKey: apiKey);

      _log.info('Core Flutter services initialized', service: _serviceName);
      _initializationResults['core'] = true;
    } catch (e) {
      _log.error('Failed to initialize core services',
          service: _serviceName, error: e);
      throw Exception('Core initialization failed: $e');
    }
  }

  /// Configure debug vs release mode settings
  void _configureDebugMode() {
    if (kReleaseMode) {
      // Disable debug print in release mode but keep critical logs
      debugPrint = (String? message, {int? wrapWidth}) {
        // Only log critical messages in release mode
        if (message != null &&
            (message.contains('ERROR') ||
                message.contains('FATAL') ||
                message.contains('CRITICAL'))) {
          print(message);
        }
      };
    }

    _log.info('Debug mode configuration: ${kDebugMode ? "DEBUG" : "RELEASE"}',
        service: _serviceName);
  }

  /// Initialize global error handling
  void _initializeGlobalErrorHandling() {
    try {
      GlobalErrorHandler().initialize();
      _log.info('Global error handling initialized', service: _serviceName);
      _initializationResults['global_error_handler'] = true;
    } catch (e) {
      _log.error('Failed to initialize global error handling',
          service: _serviceName, error: e);
      _initializationResults['global_error_handler'] = false;
      // Don't throw - error handling is not critical for startup
    }
  }

  /// Initialize Firebase with comprehensive error handling
  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        _log.info('Firebase already initialized in main()',
            service: _serviceName);
      }
      _log.info('Firebase initialization check complete',
          service: _serviceName);
      _initializationResults['firebase'] = true;
    } catch (e) {
      _log.error('Firebase initialization failed',
          service: _serviceName, error: e);
      _initializationResults['firebase'] = false;
      _initializationResults['firebase_error'] = e.toString();

      // Don't throw - allow app to continue in offline mode
      _log.warning(
          'App will continue in offline mode due to Firebase initialization failure',
          service: _serviceName);
    }
  }

  /// Initialize local storage with fallback mechanisms
  Future<void> _initializeLocalStorage() async {
    try {
      // Initialize StorageService (Hive)
      await StorageService().init();

      // Initialize SharedPreferences
      await SharedPreferences.getInstance();

      _log.info('Local storage initialized successfully',
          service: _serviceName);
      _initializationResults['local_storage'] = true;
    } catch (e) {
      _log.error('Local storage initialization failed',
          service: _serviceName, error: e);
      _initializationResults['local_storage'] = false;
      _initializationResults['local_storage_error'] = e.toString();

      // Don't throw - app can work with in-memory storage (if handled by StorageService fallback)
      _log.warning('App will use limited storage due to local storage failure',
          service: _serviceName);
    }
  }

  /// Configure system UI and orientation
  Future<void> _configureSystemUI() async {
    try {
      // Set orientation preferences
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Set initial system UI overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      _log.info('System UI configured successfully', service: _serviceName);
      _initializationResults['system_ui'] = true;
    } catch (e) {
      _log.error('System UI configuration failed',
          service: _serviceName, error: e);
      _initializationResults['system_ui'] = false;
      // Don't throw - this is not critical
    }
  }

  /// Initialize app services
  Future<void> _initializeServices() async {
    try {
      _log.info('Starting services initialization...', service: _serviceName);

      // Initialize independent services in parallel
      await Future.wait([
        _initCrashlytics(),
        _initAnalytics(),
        _initAuth(),
      ]);

      _log.info('App services initialized', service: _serviceName);
    } catch (e) {
      _log.error('Service initialization failed',
          service: _serviceName, error: e);
      _initializationResults['services'] = false;
      // Don't throw - app can work with limited services
    }
  }

  Future<void> _initCrashlytics() async {
    try {
      await CrashlyticsService().initialize();
      _initializationResults['crashlytics'] = true;
    } catch (e) {
      _initializationResults['crashlytics'] = false;
      _log.warning('Crashlytics service initialization failed',
          service: _serviceName, error: e);
    }
  }

  Future<void> _initAnalytics() async {
    try {
      await AnalyticsService().initialize();
      _initializationResults['analytics'] = true;
    } catch (e) {
      _initializationResults['analytics'] = false;
      _log.warning('Analytics service initialization failed',
          service: _serviceName, error: e);
    }
  }

  Future<void> _initAuth() async {
    try {
      await AuthService().initialize();
      _initializationResults['auth'] = true;
    } catch (e) {
      _initializationResults['auth'] = false;
      _log.warning('Auth service initialization failed',
          service: _serviceName, error: e);
    }
  }

  /// Check connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection =
          connectivityResult.any((r) => r != ConnectivityResult.none);

      _initializationResults['connectivity'] = hasConnection;
      _initializationResults['connectivity_type'] =
          connectivityResult.toString();

      _log.info('Connectivity check completed: $hasConnection',
          service: _serviceName);
    } catch (e) {
      _log.warning('Connectivity check failed',
          service: _serviceName, error: e);
      _initializationResults['connectivity'] = false;
      // Don't throw - connectivity is not critical for startup
    }
  }

  /// Get device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      return {
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'device_info': deviceInfo.toString(),
      };
    } catch (e) {
      _log.error('Failed to get device info', service: _serviceName, error: e);
      return {};
    }
  }

  /// Reset initialization state (for testing or recovery)
  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _initializationError = null;
    _initializationResults.clear();
  }
}

/// Result of app initialization
class InitializationResult {
  final bool isSuccess;
  final String? error;
  final Map<String, dynamic> results;

  InitializationResult._(this.isSuccess, this.error, this.results);

  factory InitializationResult.success(Map<String, dynamic> results) {
    return InitializationResult._(true, null, results);
  }

  factory InitializationResult.failure(String error) {
    return InitializationResult._(false, error, {});
  }
}
