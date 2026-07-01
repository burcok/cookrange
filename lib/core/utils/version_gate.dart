import 'dart:io' show Platform;

import '../models/app_config_model.dart';

/// Compares two semantic versions ("x.y.z"). Missing parts count as 0.
///
/// Returns <0 if [a] < [b], 0 if equal, >0 if [a] > [b]. Non-numeric or
/// build-suffixed segments (e.g. "1.2.3+4") are parsed leniently: only the
/// leading integer of each dot-part is used, anything else counts as 0.
int compareVersions(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va < vb ? -1 : 1;
  }
  return 0;
}

List<int> _parse(String v) {
  return v
      .trim()
      .split('.')
      .map((part) {
        final match = RegExp(r'^\d+').firstMatch(part.trim());
        return match == null ? 0 : (int.tryParse(match.group(0)!) ?? 0);
      })
      .toList();
}

/// Version-gating helpers over the remote [AppConfig]. All platform-aware:
/// picks the iOS or Android thresholds based on the running platform.
class VersionGate {
  const VersionGate._();

  /// Platform-appropriate minimum supported version from config.
  static String minSupported(AppConfig config) {
    return Platform.isIOS
        ? config.version.minSupportedIos
        : config.version.minSupportedAndroid;
  }

  /// Platform-appropriate latest version from config.
  static String latest(AppConfig config) {
    return Platform.isIOS
        ? config.version.latestIos
        : config.version.latestAndroid;
  }

  /// Platform-appropriate store URL from config.
  static String storeUrl(AppConfig config) {
    return Platform.isIOS
        ? config.version.iosStoreUrl
        : config.version.androidStoreUrl;
  }

  /// True when [currentVersion] is below the platform minimum — this account
  /// MUST update (hard gate). Requires [forceUpdate] to be enabled in config;
  /// this keeps the gate a deliberate admin action, never an accident.
  static bool isBelowMinimum(AppConfig config, String currentVersion) {
    if (!config.version.forceUpdate) return false;
    final min = minSupported(config);
    if (min.isEmpty || min == '0.0.0') return false;
    return compareVersions(currentVersion, min) < 0;
  }

  /// True when a newer version than [currentVersion] exists in the store
  /// (soft update hint — the user can dismiss it).
  static bool isUpdateAvailable(AppConfig config, String currentVersion) {
    final l = latest(config);
    if (l.isEmpty || l == '0.0.0') return false;
    return compareVersions(currentVersion, l) < 0;
  }
}
