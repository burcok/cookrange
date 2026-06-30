import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../services/admin_status_service.dart';
import '../../screens/auth/account_suspended_screen.dart';
import '../../screens/onboarding/v2/onboarding_completion.dart';
import '../../screens/onboarding/v2/onboarding_flow_screen.dart';
import 'app_routes.dart';

/// RouteGuard - SIMPLIFIED VERSION
///
/// PERFORMANCE FIX: This version does NOT make Firestore calls on every route.
/// Instead, it uses the already-cached UserProvider state.
///
/// The user data is loaded ONCE in SplashScreen._runBackgroundInitialization().
/// All subsequent route checks use the cached Provider state.
class RouteGuard extends StatefulWidget {
  final Widget child;

  const RouteGuard({super.key, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<bool>? _banSubscription;
  AdminStatus? _realtimeAdminStatus;
  bool _authInitialized = false;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _setupBanListener();

    // Mark as initialized if we have a current user already
    if (AuthService().currentUser != null) {
      _authInitialized = true;
    }

    // Check auth state on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_authInitialized) {
        // If no user exists after first frame, we know auth state
        _authInitialized = true;
        if (mounted) setState(() {});
      }
    });
  }

  void _setupAuthListener() {
    _authSubscription = AuthService().authStateChanges.listen((user) {
      if (!mounted) return;
      // Just trigger a rebuild when auth state changes
      setState(() {
        _authInitialized = true;
      });
    });
  }

  void _setupBanListener() {
    final userId = AuthService().currentUser?.uid;
    if (userId != null) {
      _banSubscription =
          AdminStatusService().onBanStatusChanged.listen((isBanned) {
        if (mounted) {
          setState(() {
            _realtimeAdminStatus =
                isBanned ? AdminStatus.banned : AdminStatus.ok;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _banSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle ban status first (real-time check)
    if (_realtimeAdminStatus == AdminStatus.banned) {
      return const AccountSuspendedScreen();
    }

    // Wait for auth to be initialized
    if (!_authInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // While onboarding is being finalized (account just created / logged-in
    // completion), stay inert: render the current route and let
    // OnboardingCompletion drive navigation to plan generation. Without this,
    // the `authStateChanges` rebuild would redirect the register screen to
    // onboarding before the (slow) finalize navigates. See ONBOARDING_V2 §8.
    if (OnboardingCompletion.isFinalizing) {
      return widget.child;
    }

    // Get current user from Firebase Auth (synchronous)
    final firebaseUser = AuthService().currentUser;
    final routeName = ModalRoute.of(context)?.settings.name;

    // PERFORMANCE FIX: Use cached UserProvider instead of Firestore call
    final userProvider = context.watch<UserProvider>();
    final userModel = userProvider.user;
    final isLoading = userProvider.isLoading;

    // If UserProvider is still loading (from SplashScreen), show loading
    if (isLoading && firebaseUser != null && !_isAuthRoute(routeName)) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // --- Navigation Logic ---

    // A. Logged Out checks
    if (firebaseUser == null) {
      if (_isAuthRoute(routeName)) {
        return widget.child;
      }

      // Redirect to login
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.login, (route) => false);
          }
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    // B. Logged In Check: Redirect away from Auth screens
    if (_isAuthRoute(routeName)) {
      if (userModel == null && isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final completed = userModel?.onboardingCompleted == true;
            final hasPlan = userModel?.mealPlanGenerated == true;
            final dest = !completed
                ? AppRoutes.onboardingV2
                : !hasPlan
                    ? AppRoutes.mealPlanGeneration
                    : AppRoutes.main;
            Navigator.pushNamedAndRemoveUntil(
              context,
              dest,
              (route) => false,
              arguments: !completed
                  ? OnboardingFlowScreen.loggedInCompletionArgs
                  : null,
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // C. Hard email-verification gate. Email-auth accounts must verify before
    //    using the app. Social-auth accounts (Google, Apple) have emailVerified=true
    //    already, so they pass through immediately.
    if (!firebaseUser.emailVerified &&
        routeName != AppRoutes.verifyEmail &&
        routeName != AppRoutes.mealPlanGeneration) {
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.verifyEmail, (route) => false);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // D. Onboarding Check (only if we have user data). A logged-in but
    //    unfinished account is sent to the V2 flow in logged-in mode.
    if (userModel != null &&
        !userModel.onboardingCompleted &&
        routeName != AppRoutes.onboardingV2 &&
        routeName != AppRoutes.intro &&
        routeName != AppRoutes.mealPlanGeneration) {
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.onboardingV2,
              (route) => false,
              arguments: OnboardingFlowScreen.loggedInCompletionArgs,
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // E. Meal plan gate — onboarding is complete but the first AI plan hasn't
    //    been generated yet. This catches every login path including the
    //    "exit verify_email → verify from email client → login" flow.
    //    mealPlanGenerated is set to true by MealPlanGenerationScreen on
    //    success, so this gate fires at most once per account.
    if (userModel != null &&
        userModel.onboardingCompleted &&
        !userModel.mealPlanGenerated &&
        routeName != AppRoutes.mealPlanGeneration &&
        routeName != AppRoutes.verifyEmail) {
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.mealPlanGeneration, (route) => false);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // F. All checks passed, render the child
    return widget.child;
  }

  bool _isAuthRoute(String? routeName) {
    return routeName == AppRoutes.login ||
        routeName == AppRoutes.register ||
        routeName == AppRoutes.forgotPassword ||
        routeName == AppRoutes.priorityOnboarding;
  }
}
