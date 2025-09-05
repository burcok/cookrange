import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../providers/language_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/device_info_provider.dart';
import 'log_service.dart';

/// Service to manage provider initialization and optimization
class ProviderInitializationService {
  static final ProviderInitializationService _instance =
      ProviderInitializationService._internal();
  factory ProviderInitializationService() => _instance;
  ProviderInitializationService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'ProviderInitializationService';

  bool _isInitialized = false;
  final Map<String, dynamic> _initializationResults = {};

  // Getters
  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get initializationResults => _initializationResults;

  /// Initialize all providers with proper error handling
  Future<void> initializeProviders(BuildContext context) async {
    if (_isInitialized) return;

    try {
      _log.info('Starting provider initialization', service: _serviceName);

      // Initialize device info provider first as it's needed by others
      await _initializeDeviceInfoProvider(context);

      // Initialize other providers
      await _initializeLanguageProvider(context);
      await _initializeOnboardingProvider(context);

      _isInitialized = true;
      _log.info('Provider initialization completed successfully',
          service: _serviceName);
    } catch (e, stackTrace) {
      _log.error('Provider initialization failed',
          service: _serviceName, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Initialize device info provider
  Future<void> _initializeDeviceInfoProvider(BuildContext context) async {
    try {
      final deviceInfoProvider =
          Provider.of<DeviceInfoProvider>(context, listen: false);
      await deviceInfoProvider.initialize();
      _initializationResults['device_info'] = true;
      _log.info('Device info provider initialized', service: _serviceName);
    } catch (e) {
      _initializationResults['device_info'] = false;
      _log.error('Failed to initialize device info provider',
          service: _serviceName, error: e);
      // Don't rethrow - device info is not critical
    }
  }

  /// Initialize language provider
  Future<void> _initializeLanguageProvider(BuildContext context) async {
    try {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      // Language provider doesn't need async initialization
      _initializationResults['language'] = true;
      _log.info('Language provider initialized', service: _serviceName);
    } catch (e) {
      _initializationResults['language'] = false;
      _log.error('Failed to initialize language provider',
          service: _serviceName, error: e);
    }
  }

  /// Initialize onboarding provider
  Future<void> _initializeOnboardingProvider(BuildContext context) async {
    try {
      final onboardingProvider =
          Provider.of<OnboardingProvider>(context, listen: false);
      // Onboarding provider doesn't need async initialization
      _initializationResults['onboarding'] = true;
      _log.info('Onboarding provider initialized', service: _serviceName);
    } catch (e) {
      _initializationResults['onboarding'] = false;
      _log.error('Failed to initialize onboarding provider',
          service: _serviceName, error: e);
    }
  }

  /// Create optimized provider list
  List<ChangeNotifierProvider> createProviders() {
    return [
      ChangeNotifierProvider(create: (_) => OnboardingProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => DeviceInfoProvider()),
    ];
  }

  /// Create provider list with proper typing
  List<ChangeNotifierProvider> createChangeNotifierProviders() {
    return [
      ChangeNotifierProvider<OnboardingProvider>(
          create: (_) => OnboardingProvider()),
      ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()),
      ChangeNotifierProvider<DeviceInfoProvider>(
          create: (_) => DeviceInfoProvider()),
    ];
  }

  /// Create provider with Firebase Analytics
  List<Provider> createFirebaseProviders() {
    return [
      Provider<FirebaseAnalytics>.value(value: FirebaseAnalytics.instance),
    ];
  }

  /// Reset initialization state
  void reset() {
    _isInitialized = false;
    _initializationResults.clear();
  }
}
