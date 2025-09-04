import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class RouteGuard extends StatefulWidget {
  final Widget child;

  const RouteGuard({super.key, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  Future<UserModel?>? _userModelFuture;

  @override
  void initState() {
    super.initState();
    _userModelFuture = _getUserModel();
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
    return FutureBuilder<UserModel?>(
      future: _userModelFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final userModel = snapshot.data;
        final bool isLoggedIn = userModel != null;
        final bool onboardingCompleted =
            userModel?.onboardingCompleted ?? false;

        if (!isLoggedIn) {
          return widget.child;
        }

        final routeName = ModalRoute.of(context)?.settings.name;

        final bool shouldRedirectToHome =
            (routeName == '/login' || routeName == '/register') ||
                (routeName == '/onboarding' && onboardingCompleted);

        if (shouldRedirectToHome) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return widget.child;
      },
    );
  }
}
