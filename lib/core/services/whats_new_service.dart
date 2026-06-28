import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the app has been updated since the user last launched it.
///
/// Returns [shouldShow] == true exactly once per new version bump.
/// Skips the very first install (the intro tour covers that case).
class WhatsNewService {
  static final _instance = WhatsNewService._internal();
  factory WhatsNewService() => _instance;
  WhatsNewService._internal();

  static const _prefKey = 'whats_new_last_version';

  /// Returns true if the app version has bumped since last launch.
  ///
  /// Saves the new version so it only returns true once per version.
  /// Returns false on the very first install (intro handles that).
  Future<bool> shouldShow() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_prefKey);
      final current = '${info.version}+${info.buildNumber}';

      if (lastSeen == current) return false;
      await prefs.setString(_prefKey, current);

      // Don't show on very first install — intro tour covers that.
      return lastSeen != null;
    } catch (e) {
      debugPrint('WhatsNewService.shouldShow error: $e');
      return false;
    }
  }
}
