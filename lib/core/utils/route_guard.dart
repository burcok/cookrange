import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/admin_status_service.dart';

class RouteGuard extends StatefulWidget {
  final Widget child;

  const RouteGuard({super.key, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  Future<UserModel?>? _userModelFuture;
  Future<AdminStatus>? _adminStatusFuture;

  @override
  void initState() {
    super.initState();
    _userModelFuture = _getUserModel();
    _adminStatusFuture =
        AdminStatusService().checkStatus(AuthService().currentUser?.uid);
  }

  Future<UserModel?> _getUserModel() async {
    final authService = AuthService();
    if (authService.currentUser == null) {
      return null;
    }
    return await authService.getUserData(authService.currentUser!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _userModelFuture as Future<dynamic>,
        _adminStatusFuture as Future<dynamic>
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final userModel = snapshot.data?[0] as UserModel?;
        final adminStatus = snapshot.data?[1] as AdminStatus?;

        final bool isLoggedIn = userModel != null;
        final bool onboardingCompleted =
            userModel?.onboardingCompleted ?? false;
        final routeName = ModalRoute.of(context)?.settings.name;

        // 1. Logged Out checks
        if (!isLoggedIn) {
          // Allow login/register/onboarding (if not protected)
          // But main app routes should be protected
          // Assuming RouteGuard is wrapping protected routes mostly,
          // but if it's wrapping everything, we need to allow auth routes.
          // However, simple logic: if NOT logged in, return child (which might be LoginScreen)
          // If child is protected screen, we should redirect.
          // BUT, RouteGuard is usually used as `RouteGuard(child: HomeScreen)`.
          // If used there, and not logged in -> redirect to Login.
          // If used on LoginScreen -> redirect to Home if logged in.

          // If the guarded child IS the login/register screen, we just show it.
          // If the guarded child is a protected screen, we redirect.

          // We need a way to know if 'child' is public or private.
          // Simplified approach: RouteGuard is primarily for PROTECTED routes in this app architecture?
          // Looking at route_config: Login/Register ARE wrapped in RouteGuard.

          if (_isAuthRoute(routeName)) {
            return widget.child;
          }

          // If trying to access protected route but not logged in
          // (This usually shouldn't happen if routes are set up right, but safe fallback)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        // 2. Logged In Check: Redirect away from Auth screens
        if (isLoggedIn && _isAuthRoute(routeName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 3. Onboarding Check
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

        // 4. Admin Status Checks
        if (adminStatus != null && adminStatus != AdminStatus.ok) {
          return _buildAdminStatusScreen(adminStatus);
        }

        // 5. Email Verification Check
        // If route is already '/verify-email', allow it.
        // Else if user not verified, redirect.
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
        title = 'Account Suspended';
        message =
            'Your account has been suspended due to a violation of our terms.';
        icon = Icons.block;
        break;
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
              Icon(icon, size: 64, color: const Color(0xFFF97300)),
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
