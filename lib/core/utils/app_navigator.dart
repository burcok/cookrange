import 'package:flutter/material.dart';

/// Central wrapper around the inner (in-app) Navigator.
///
/// Widgets that live **outside** the inner Navigator's subtree (SideMenu,
/// VoiceAssistantOverlay, QuickActionsSheet) use [AppNavigator] to push routes
/// while keeping the navbar (QuickActionsSheet) visible.
///
/// Full-screen routes that must cover the navbar (cameras, scanners) should
/// still be pushed via [Navigator.of(context, rootNavigator: true)] or the
/// normal [Navigator.of(context)] from a widget outside the inner navigator.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> innerKey =
      GlobalKey<NavigatorState>(debugLabel: 'innerNav');

  static NavigatorState? get _state => innerKey.currentState;

  static bool get canPop => _state?.canPop() ?? false;

  /// Push [screen] into the in-app Navigator — navbar stays visible.
  static Future<T?> push<T>(Widget screen) {
    final nav = _state;
    if (nav == null) return Future.value();
    return nav.push<T>(MaterialPageRoute(builder: (_) => screen));
  }

  /// Pop the top in-app route.
  static void pop() => _state?.pop();

  /// Pop all in-app routes back to the tab host.
  static void popToTabHost() => _state?.popUntil((route) => route.isFirst);
}
