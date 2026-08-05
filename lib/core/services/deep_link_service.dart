import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/gym/gym_join_prompt_sheet.dart';
import '../../screens/onboarding/v2/onboarding_flow_screen.dart';
import '../localization/app_localizations.dart';
import '../providers/onboarding_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/ds/ds.dart';
import 'crashlytics_service.dart';
import 'gym_service.dart';
import 'referral_service.dart';

/// Handles App Links (Android) and Universal Links (iOS) as well as the
/// custom `cookrange://` scheme.
///
/// URL scheme:
///   https://cookrangeapp.com/recipe/{id}
///   https://cookrangeapp.com/post/{id}
///   https://cookrangeapp.com/user/{uid}
///   cookrange://recipe/{id}  (custom scheme, dev/testing)
///
/// QR check-in scheme (opaque URI emitted by GymQrScreen):
///   cookrange:checkin:{gymId}:{qrToken}
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

    // Opaque cookrange: URIs (e.g. cookrange:checkin:gymId:token) have no
    // path segments — their payload is in uri.path as colon-delimited parts.
    if (uri.scheme == 'cookrange' && !uri.hasAuthority) {
      _routeOpaque(uri, nav);
      return;
    }

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
      case 'invite':
        _handleInvite(id, nav);
      default:
        debugPrint('DeepLink: unrecognised path segment "$type"');
    }
  }

  /// Routes an `/invite/{code}` link (Faz 6 §6.3), per this state table:
  ///  - Signed-in session already exists → the code is NOT applied (invite
  ///    codes are new-signup only). Gently explained, discarded, written
  ///    nowhere.
  ///  - No session → the code is staged (in-memory into [OnboardingProvider]
  ///    + on-device via [ReferralService.savePendingCode], 7-day TTL so a
  ///    stale scan can't misattribute a signup weeks later) and the user is
  ///    routed into onboarding, where the referral step picks it up prefilled.
  ///    If onboarding is already the active screen, skip the navigation —
  ///    pushing a second [OnboardingFlowScreen] on top would look like the
  ///    user's in-progress answers were lost. The code alone is enough either
  ///    way; [OnboardingProvider] just picks it up reactively.
  /// Malformed/empty codes are silently ignored. Whether the staged code
  /// turns out invalid/expired/inactive is decided later — by
  /// [ReferralService.previewCode] at the referral step and, for real, by
  /// `applyReferral` at signup — never disrupting this routing step.
  void _handleInvite(String rawCode, NavigatorState nav) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;
    final ctx = nav.context;
    if (!ctx.mounted) return;

    if (FirebaseAuth.instance.currentUser != null) {
      debugPrint('DeepLink: invite code ignored — signed-in session exists');
      AppSnackBar.info(
        ctx,
        AppLocalizations.of(ctx)
            .translate('settings.referral.signed_in_notice'),
      );
      return;
    }

    unawaited(ReferralService().savePendingCode(code));
    ctx.read<OnboardingProvider>().setReferralCode(code);
    debugPrint('DeepLink: invite code $code staged for onboarding');

    if (!OnboardingFlowScreen.isActive) {
      nav.pushNamed(AppRoutes.onboardingV2);
    }
  }

  /// Routes opaque `cookrange:` URIs.
  /// Currently handles: `cookrange:checkin:{gymId}:{qrToken}`
  void _routeOpaque(Uri uri, NavigatorState nav) {
    final parts = uri.path.split(':');
    if (parts.isEmpty) return;

    switch (parts[0]) {
      case 'checkin':
        if (parts.length < 3) {
          debugPrint('DeepLink: malformed checkin URI – expected gymId:token');
          return;
        }
        final gymId = parts[1];
        final token = parts[2];
        if (gymId.isEmpty || token.isEmpty) return;
        unawaited(_handleGymCheckin(gymId, token, nav));
      default:
        debugPrint('DeepLink: unrecognised opaque type "${parts[0]}"');
    }
  }

  Future<void> _handleGymCheckin(
      String gymId, String token, NavigatorState nav) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('DeepLink: gym checkin ignored — user not signed in');
      return;
    }

    try {
      final member = await GymService().isMember(gymId, uid);

      final ctx = nav.context;
      if (!ctx.mounted) return;

      if (member) {
        await GymService().validateQRCheckIn(gymId, token);
        debugPrint('[DeepLink] QR check-in success gym=$gymId uid=$uid');
      } else {
        final gym = await GymService().getGym(gymId);
        if (gym == null) {
          debugPrint('[DeepLink] Gym $gymId not found');
          return;
        }
        if (!ctx.mounted) return;
        await GymJoinPromptSheet.show(
          ctx,
          gymId: gymId,
          gymName: gym.name,
          uid: uid,
          qrToken: token,
        );
      }
    } catch (e, stack) {
      debugPrint('[DeepLink] gym checkin error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'DeepLinkService._handleGymCheckin'));
    }
  }
}
