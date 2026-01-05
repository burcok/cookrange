import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/admin_status_service.dart';
import '../../screens/auth/account_suspended_screen.dart';
import '../../screens/common/generic_error_screen.dart';
import '../providers/theme_provider.dart';

class RouteGuard extends StatefulWidget {
  final Widget child;

  const RouteGuard({super.key, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  Future<UserModel?>? _userModelFuture;
  Future<AdminStatus>? _adminStatusFuture;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<bool>? _banSubscription;
  AdminStatus? _realtimeAdminStatus;

  bool _authInitialized = false;
  String? _lastUserId;
  Timer? _authDebounceTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Don't initialize futures here immediately if we expect auth stream to fire
    // But to be safe for "already logged in" state:
    final currentUser = AuthService().currentUser;
    if (currentUser != null) {
      _lastUserId = currentUser.uid;
      _initializeFutures(currentUser.uid);
      _authInitialized = true;
    }
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authSubscription = AuthService().authStateChanges.listen((user) {
      // Debounce auth changes to prevent rapid-fire updates
      _authDebounceTimer?.cancel();
      _authDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        final newUserId = user?.uid;

        // Only refresh if user actually changed or if we weren't initialized
        if (!_authInitialized || newUserId != _lastUserId) {
          setState(() {
            _authInitialized = true;
            _lastUserId = newUserId;
            _retryCount = 0; // Reset retry count on new user
            _initializeFutures(newUserId);
            _setupBanListener(newUserId);
          });
        }
      });
    });
  }

  void _setupBanListener(String? userId) {
    _banSubscription?.cancel();
    if (userId != null) {
      _banSubscription =
          AdminStatusService().onBanStatusChanged.listen((isBanned) {
        if (isBanned && _realtimeAdminStatus != AdminStatus.banned) {
          debugPrint('RouteGuard: Real-time ban detected for user $userId');
          if (mounted) {
            setState(() {
              _realtimeAdminStatus = AdminStatus.banned;
            });
          }
        } else if (!isBanned && _realtimeAdminStatus == AdminStatus.banned) {
          if (mounted) {
            setState(() {
              _realtimeAdminStatus = AdminStatus.ok;
            });
          }
        }
      });
    }
  }

  void _refreshState() {
    if (mounted) {
      setState(() {
        _retryCount = 0;
        _initializeFutures(AuthService().currentUser?.uid);
        _realtimeAdminStatus = null;
      });
    }
  }

  void _initializeFutures([String? explicitUserId]) {
    final userId = explicitUserId ?? AuthService().currentUser?.uid;

    if (userId == null) {
      _userModelFuture = Future.value(null);
      // Admin check might still be relevant for general maintenance,
      // but usually specific to user. We can check global anyway.
      _adminStatusFuture = _safeCheckAdminStatus(null);
    } else {
      _userModelFuture = _getUserModel(userId);
      _adminStatusFuture = _safeCheckAdminStatus(userId);
    }
  }

  Future<AdminStatus> _safeCheckAdminStatus(String? userId) async {
    try {
      // Use forceRefresh only if we are manually retrying or it's critical
      // For general nav, rely on cache to be fast
      return await AdminStatusService()
          .checkStatus(userId, forceRefresh: false);
    } catch (e) {
      debugPrint('RouteGuard: Error checking admin status: $e');
      return AdminStatus.ok;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _banSubscription?.cancel();
    _authDebounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<UserModel?> _getUserModel(String? uid) async {
    if (uid == null) return null;
    try {
      // Fetch user data
      final userModel = await AuthService().getUserData(uid);

      // Sync with UserProvider if mounted
      if (mounted && userModel != null) {
        // Use post-frame callback or simple check to avoid build-phase updates if called during build
        // But since this is async, it's safe.
        // We use 'listen: false' to just set the data without triggering a rebuild of RouteGuard necessarily
        // (though UserProvider will notify its listeners)
        Provider.of<UserProvider>(context, listen: false).setUser(userModel);
      }
      return userModel;
    } catch (e) {
      debugPrint('RouteGuard: Error fetching user data: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_realtimeAdminStatus == AdminStatus.banned) {
      return const AccountSuspendedScreen();
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _userModelFuture ?? Future.value(null),
        _adminStatusFuture ?? Future.value(AdminStatus.ok)
      ]),
      builder: (context, snapshot) {
        // 1. Waiting State
        // If not initialized yet, or futures are still pending
        if (!_authInitialized ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 2. Error State with Auto-Retry
        if (snapshot.hasError) {
          debugPrint(
              'RouteGuard Error: ${snapshot.error}\nStack: ${snapshot.stackTrace}');

          // Automatic temporary retry before showing scary error screen
          if (_retryCount < _maxRetries) {
            // Schedule a retry if not already scheduled
            if (_retryTimer == null || !_retryTimer!.isActive) {
              _retryTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _retryCount++;
                    debugPrint(
                        'RouteGuard: Auto-retrying initialization (Attempt $_retryCount)');
                    _initializeFutures(AuthService().currentUser?.uid);
                  });
                }
              });
            }
            // Show loading while we retry
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If retries exhausted, show actual error screen
          return GenericErrorScreen(
            onRetry: _refreshState,
            errorCode:
                'RG-500: ${snapshot.error.toString().length > 20 ? snapshot.error.toString().substring(0, 20) : snapshot.error.toString()}',
          );
        }

        // 3. Success State
        final userModel = snapshot.data?[0] as UserModel?;
        final adminStatus = snapshot.data?[1] as AdminStatus?;

        final bool isLoggedIn = userModel != null;
        final bool onboardingCompleted =
            userModel?.onboardingCompleted ?? false;
        final routeName = ModalRoute.of(context)?.settings.name;

        // --- Navigation Logic ---

        // A. Logged Out checks
        if (!isLoggedIn) {
          if (_isAuthRoute(routeName)) {
            return widget.child;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        // B. Logged In Check: Redirect away from Auth screens
        if (isLoggedIn && _isAuthRoute(routeName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Navigate to MAIN scaffold, not just Home
              Navigator.pushNamedAndRemoveUntil(
                  context, '/main', (route) => false);
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // C. Onboarding Check
        if (isLoggedIn && !onboardingCompleted && routeName != '/onboarding') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/onboarding', (route) => false);
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // D. Admin Status Checks
        if (adminStatus != null && adminStatus != AdminStatus.ok) {
          return _buildAdminStatusScreen(adminStatus);
        }

        // E. Email Verification Check
        if (isLoggedIn && routeName != '/verify-email') {
          final authService = AuthService();
          final user = authService.currentUser;
          if (user != null && !user.emailVerified) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/verify-email', (route) => false);
              }
            });
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
        }

        return widget.child;
      },
    );
  }

  bool _isAuthRoute(String? routeName) {
    return routeName == '/login' ||
        routeName == '/register' ||
        routeName == '/priority-onboarding';
  }

  Widget _buildAdminStatusScreen(AdminStatus status) {
    if (status == AdminStatus.banned) {
      return const AccountSuspendedScreen();
    }

    String title = 'Error';
    String message = 'Something went wrong';
    IconData icon = Icons.error_outline;

    switch (status) {
      case AdminStatus.maintenance:
        title = 'Under Maintenance';
        message =
            'We are currently performing scheduled maintenance. Please try again later.';
        icon = Icons.engineering;
        break;
      case AdminStatus.updateRequired:
        title = 'Update Required';
        message =
            'Please update to the latest version to continue using Cookrange.';
        icon = Icons.system_update;
        break;
      case AdminStatus.banned:
        return const AccountSuspendedScreen();
      default:
        break;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 64,
                  color: Provider.of<ThemeProvider>(context).primaryColor),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A59)),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
