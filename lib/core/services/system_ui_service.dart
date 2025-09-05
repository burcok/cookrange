import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to manage system UI overlay styles dynamically
/// based on theme changes and app state.
class SystemUIService {
  static final SystemUIService _instance = SystemUIService._internal();
  factory SystemUIService() => _instance;
  SystemUIService._internal();

  /// Update system UI overlay style based on theme brightness
  void updateSystemUIOverlayStyle(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: theme.dividerColor,
      ),
    );
  }

  /// Set system UI overlay style for specific screens
  void setSystemUIOverlayStyle({
    Color? statusBarColor,
    Brightness? statusBarIconBrightness,
    Brightness? statusBarBrightness,
    Color? systemNavigationBarColor,
    Brightness? systemNavigationBarIconBrightness,
    Color? systemNavigationBarDividerColor,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
        systemNavigationBarColor: systemNavigationBarColor,
        systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
        systemNavigationBarDividerColor: systemNavigationBarDividerColor,
      ),
    );
  }

  /// Set orientation preferences
  Future<void> setOrientationPreferences(
      List<DeviceOrientation> orientations) async {
    await SystemChrome.setPreferredOrientations(orientations);
  }

  /// Enable full screen mode
  void enableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Disable full screen mode
  void disableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Set system UI mode
  void setSystemUIMode(SystemUiMode mode) {
    SystemChrome.setEnabledSystemUIMode(mode);
  }
}
