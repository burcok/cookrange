import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../services/admin_status_service.dart';
import '../../screens/auth/account_suspended_screen.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    // B. Logged In Check: Redirect away from Auth screens
    if (_isAuthRoute(routeName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // C. Email Verification Check
    if (routeName != '/verify-email' && !firebaseUser.emailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/verify-email', (route) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // D. Onboarding Check (only if we have user data)
    if (userModel != null &&
        !userModel.onboardingCompleted &&
        routeName != '/onboarding') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/onboarding', (route) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // E. All checks passed, render the child
    return widget.child;
  }

  bool _isAuthRoute(String? routeName) {
    return routeName == '/login' ||
        routeName == '/register' ||
        routeName == '/priority-onboarding';
  }
}
