import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'logging_navigator_observer.dart';
import '../utils/route_guard.dart';
import '../utils/app_routes.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home.dart';
import '../../screens/auth/verify_email.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/onboarding/priority_onboarding_screen.dart';
import '../../screens/main_scaffold.dart';
import '../widgets/error_fallback_widget.dart';

/// Service to manage route configuration and navigation
class RouteConfigurationService {
  static final RouteConfigurationService _instance =
      RouteConfigurationService._internal();
  factory RouteConfigurationService() => _instance;
  RouteConfigurationService._internal();

  /// Get all app routes with proper guards
  Map<String, WidgetBuilder> getRoutes() {
    return {
      AppRoutes.splash: (context) => const SplashScreen(),
      AppRoutes.login: (context) => const RouteGuard(child: LoginScreen()),
      AppRoutes.register: (context) =>
          const RouteGuard(child: RegisterScreen()),
      AppRoutes.home: (context) => const RouteGuard(child: HomeScreen()),
      AppRoutes.main: (context) => const MainScaffold(),
      AppRoutes.verifyEmail: (context) =>
          const RouteGuard(child: VerifyEmailScreen()),
      AppRoutes.onboarding: (context) =>
          const RouteGuard(child: OnboardingScreen()),
      AppRoutes.priorityOnboarding: (context) =>
          const RouteGuard(child: PriorityOnboardingScreen()),
      '/offline': (context) => const OfflineModeScreen(),
    };
  }

  /// Get route generator for unknown routes
  Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => const UnknownRouteScreen(),
      settings: settings,
    );
  }

  /// Get navigation observers
  List<NavigatorObserver> getNavigatorObservers() {
    return [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      LoggingNavigatorObserver(),
    ];
  }

  /// Get initial route
  String get initialRoute => AppRoutes.splash;

  /// Navigate to a route with proper error handling
  static Future<void> navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool clearStack = false,
  }) async {
    try {
      if (clearStack) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          routeName,
          (route) => false,
          arguments: arguments,
        );
      } else {
        Navigator.pushNamed(
          context,
          routeName,
          arguments: arguments,
        );
      }
    } catch (e) {
      // Log navigation error
      debugPrint('Navigation error: $e');
      // Fallback to home route
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  /// Replace current route
  static Future<void> replaceRoute(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      Navigator.pushReplacementNamed(
        context,
        routeName,
        arguments: arguments,
      );
    } catch (e) {
      debugPrint('Route replacement error: $e');
      // Fallback to home route
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  /// Go back with fallback
  static void goBack(BuildContext context, {dynamic result}) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      // If can't go back, navigate to home
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }
}

/// Offline mode screen
class OfflineModeScreen extends StatelessWidget {
  const OfflineModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.offline_bolt, size: 64),
            SizedBox(height: 16),
            Text('You are in offline mode'),
            SizedBox(height: 8),
            Text('Some features may not be available'),
          ],
        ),
      ),
    );
  }
}
