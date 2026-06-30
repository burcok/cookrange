import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crashlytics_service.dart';

/// Manages iOS App Tracking Transparency (ATT) consent.
///
/// Call [requestIfNeeded] once per install (first launch after onboarding
/// is complete). On Android and debug builds this is a no-op.
class ATTConsentService {
  ATTConsentService._internal();
  static final ATTConsentService _instance = ATTConsentService._internal();
  factory ATTConsentService() => _instance;

  static const _prefKey = 'att_prompted';

  /// True when the OS tracking permission is granted (or on Android/debug).
  bool get analyticsEnabled {
    if (!Platform.isIOS || kDebugMode) return true;
    return _granted;
  }

  bool _granted = false;

  /// Shows the ATT system dialog if we haven't prompted yet.
  /// Safe to call multiple times — no-op after first prompt.
  Future<void> requestIfNeeded() async {
    if (!Platform.isIOS || kDebugMode) {
      _granted = true;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool(_prefKey) ?? false;

      if (alreadyPrompted) {
        // Reflect current permission state on re-launch.
        final status = await Permission.appTrackingTransparency.status;
        _granted = status.isGranted;
        debugPrint('ATT: already prompted — status=$status');
        return;
      }

      // Present the iOS system ATT dialog.
      final status = await Permission.appTrackingTransparency.request();
      _granted = status.isGranted;
      await prefs.setBool(_prefKey, true);
      debugPrint('ATT: user responded — status=$status');
    } catch (e, stack) {
      // Non-fatal; analytics just won't be enabled.
      _granted = false;
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ATTConsentService.requestIfNeeded'));
    }
  }
}
