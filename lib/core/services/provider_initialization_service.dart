import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../providers/language_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/device_info_provider.dart';
import '../providers/user_provider.dart';
import '../services/navigation_provider.dart';

/// Service to manage provider initialization and optimization
class ProviderInitializationService {
  static final ProviderInitializationService _instance =
      ProviderInitializationService._internal();
  factory ProviderInitializationService() => _instance;
  ProviderInitializationService._internal();

  bool _isInitialized = false;
  final Map<String, dynamic> _initializationResults = {};

  // Getters
  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get initializationResults => _initializationResults;

  /// Create optimized provider list
  List<ChangeNotifierProvider> createProviders() {
    return [
      ChangeNotifierProvider(create: (_) => OnboardingProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => DeviceInfoProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
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
      ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider()),
      ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
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
