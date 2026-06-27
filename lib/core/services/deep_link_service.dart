import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'crashlytics_service.dart';

/// Handles App Links (Android) and Universal Links (iOS) as well as the
/// custom `cookrange://` scheme.
///
/// URL scheme:
///   https://cookrange.app/recipe/{id}
///   https://cookrange.app/post/{id}
///   https://cookrange.app/user/{uid}
///   https://cookrange.app/challenge/{id}
///   cookrange://recipe/{id}  (custom scheme, dev/testing)
///
/// Usage:
///   1. Call [init] once from splash/main after auth is stable.
///   2. Pass a [navigatorKey] to route incoming links to any screen.
class DeepLinkService {
  DeepLinkService._internal();
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Handle the link that launched the app cold (if any).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('DeepLink: initial link = $initial');
        _route(initial);
      }
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'DeepLinkService.init initial'));
    }

    // Listen for links while the app is running.
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('DeepLink: incoming = $uri');
        _route(uri);
      },
      onError: (e, stack) {
        unawaited(CrashlyticsService()
            .recordError(e, stack, reason: 'DeepLinkService.uriLinkStream'));
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _route(Uri uri) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    final type = segments[0];
    final id = segments.length > 1 ? segments[1] : null;
    if (id == null || id.isEmpty) return;

    switch (type) {
      case 'recipe':
        nav.pushNamed('/recipe_detail', arguments: {'id': id});
      case 'post':
        nav.pushNamed('/post_detail', arguments: {'postId': id});
      case 'user':
        nav.pushNamed('/profile', arguments: {'uid': id});
      case 'challenge':
        nav.pushNamed('/challenge_detail', arguments: {'challengeId': id});
      case 'invite':
        nav.pushNamed('/settings', arguments: {'referral_code': id});
      default:
        debugPrint('DeepLink: unrecognised path segment "$type"');
    }
  }
}
