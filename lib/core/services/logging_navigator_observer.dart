import 'package:flutter/material.dart';
import 'log_service.dart';

/// NavigatorObserver that logs all navigation events
class LoggingNavigatorObserver extends NavigatorObserver {
  final LogService _log = LogService();
  final String _serviceName = 'Navigation';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(
      'Push',
      current: route.settings.name,
      previous: previousRoute?.settings.name,
      args: route.settings.arguments,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute(
      'Pop',
      current: previousRoute?.settings.name,
      previous: route.settings.name,
      isPop: true,
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRoute(
      'Replace',
      current: newRoute?.settings.name,
      previous: oldRoute?.settings.name,
      args: newRoute?.settings.arguments,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRoute(
      'Remove',
      current: route.settings.name,
      previous: previousRoute?.settings.name,
    );
  }

  void _logRoute(
    String action, {
    String? current,
    String? previous,
    Object? args,
    bool isPop = false,
  }) {
    final currentName = current ?? 'unnamed';
    final previousName = previous ?? 'unnamed';
    final argsStr = args != null ? ' | args: $args' : '';

    String message;
    if (isPop) {
      message = '$action: $previousName -> $currentName';
    } else {
      message = '$action: $currentName (from $previousName)$argsStr';
    }

    _log.info(message, service: _serviceName);
  }
}
