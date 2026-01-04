import 'package:flutter/material.dart';
import '../../core/services/admin_status_service.dart';
import '../../core/services/auth_service.dart';
import 'route_guard.dart';

class BanCheckNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkBanStatus(route.navigator?.context);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _checkBanStatus(newRoute?.navigator?.context);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Optional: check on pop too if coming back to a screen requires re-auth
    _checkBanStatus(previousRoute?.navigator?.context);
  }

  Future<void> _checkBanStatus(BuildContext? context) async {
    if (context == null) return;

    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    // Check ban status with force refresh false (to be fast)
    // or true (if we want to be very strict, but user asked for checks on actions/nav)
    // The user said "any operation" and "swipe/nav".
    // We'll use cached check for speed but rely on the logic in AdminStatusService to refresh if needed.
    // However, user specifically asked for check "on any action".
    // To be safe, we might want forceRefresh: true on critical paths or
    // just rely on the fact that we are calling it frequently.

    final status =
        await AdminStatusService().checkStatus(userId, forceRefresh: true);

    if (status == AdminStatus.banned) {
      // Find the RouteGuard state to trigger the banned screen,
      // OR navigate directly if we are outside RouteGuard context
      // But triggering RouteGuard rebuild is cleaner if it's in the tree.

      // Since RouteGuard wraps the main app content, we can try to find it.
      // But simpler is to navigate to a banned screen route if not already there.

      // Check if we are already on Banned Screen to avoid loop
      // This is hard to detect with just Route, so we check the widget type or route name
      // assuming we named it '/account_suspended' or similar if reachable via named route.
      // But we are using RouteGuard to return the widget.

      // If we are strictly using RouteGuard, we should ideally notify it.
      // Since we don't have easy access to RouteGuard state from here without a provider,
      // We will define a global GlobalKey or a Stream/Notifier for "Force Ban"
      // that RouteGuard listens to, instead of the Firestore stream.

      // Let's use a simpler approach:
      // Add a method to AdminStatusService that RouteGuard subscribes to (local stream),
      // and this Observer calls that method.

      AdminStatusService().notifyBanned(userId);
    }
  }
}
