import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'logging_navigator_observer.dart';
import '../utils/route_guard.dart';
import '../utils/app_routes.dart';
import '../utils/ban_check_observer.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home.dart';
import '../../screens/auth/verify_email.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/onboarding/priority_onboarding_screen.dart';
import '../../screens/main_scaffold.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/chat/chat_detail_screen.dart';
import '../../screens/home/nutrition_analytics_screen.dart';
import '../../screens/home/meal_plan_history_screen.dart';
import '../../screens/chat/ai_chat_screen.dart';
import '../../screens/recipe/favorites_screen.dart';
import '../../screens/community/user_search_screen.dart';
import '../../screens/onboarding/v2/intro_screen.dart';
import '../../screens/onboarding/v2/onboarding_flow_screen.dart';
import '../../screens/onboarding/meal_plan_generation_screen.dart';
import '../../screens/discover/discover_hub_screen.dart';
import '../../screens/community/streak_squad_screen.dart';
import '../models/chat_model.dart';
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
      AppRoutes.main: (context) => const RouteGuard(child: MainScaffold()),
      AppRoutes.verifyEmail: (context) =>
          const RouteGuard(child: VerifyEmailScreen()),
      AppRoutes.priorityOnboarding: (context) =>
          const RouteGuard(child: PriorityOnboardingScreen()),
      AppRoutes.chatList: (context) =>
          const RouteGuard(child: ChatListScreen()),
      AppRoutes.forgotPassword: (context) =>
          const RouteGuard(child: ForgotPasswordScreen()),
      AppRoutes.nutritionAnalytics: (context) =>
          const RouteGuard(child: NutritionAnalyticsScreen()),
      AppRoutes.aiChat: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as String?;
        return RouteGuard(child: AIChatScreen(initialMessage: args));
      },
      AppRoutes.chatDetail: (context) {
        final chat = ModalRoute.of(context)!.settings.arguments as ChatModel;
        return RouteGuard(child: ChatDetailScreen(chat: chat));
      },
      AppRoutes.favorites: (context) =>
          const RouteGuard(child: FavoritesScreen()),
      AppRoutes.mealPlanHistory: (context) =>
          const RouteGuard(child: MealPlanHistoryScreen()),
      AppRoutes.userSearch: (context) =>
          const RouteGuard(child: UserSearchScreen()),
      // Pre-auth flow (unwrapped — no user exists yet).
      AppRoutes.intro: (context) => const IntroScreen(),
      AppRoutes.onboardingV2: (context) {
        // Default entry is pre-registration. Splash / route guard / verify-email
        // pass [loggedInCompletionArgs] when an authenticated-but-unfinished
        // account is sent here to complete onboarding against its own uid.
        final args = ModalRoute.of(context)?.settings.arguments;
        final loggedIn = args is Map &&
            args[OnboardingFlowScreen.loggedInCompletionArg] == true;
        return OnboardingFlowScreen(loggedInCompletion: loggedIn);
      },
      AppRoutes.discover: (context) =>
          const RouteGuard(child: DiscoverHubScreen()),
      AppRoutes.mealPlanGeneration: (context) =>
          const RouteGuard(child: MealPlanGenerationScreen()),
      AppRoutes.streakSquads: (context) =>
          const RouteGuard(child: StreakSquadScreen()),
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
      BanCheckNavigatorObserver(),
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
        unawaited(Navigator.pushNamedAndRemoveUntil(
          context,
          routeName,
          (route) => false,
          arguments: arguments,
        ));
      } else {
        unawaited(Navigator.pushNamed(
          context,
          routeName,
          arguments: arguments,
        ));
      }
    } catch (e) {
      // Log navigation error
      debugPrint('Navigation error: $e');
      // Fallback to home route
      unawaited(Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      ));
    }
  }

  /// Replace current route
  static Future<void> replaceRoute(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      unawaited(Navigator.pushReplacementNamed(
        context,
        routeName,
        arguments: arguments,
      ));
    } catch (e) {
      debugPrint('Route replacement error: $e');
      // Fallback to home route
      unawaited(Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      ));
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
