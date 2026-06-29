import 'package:flutter/material.dart';

/// Cookrange Design System — accessibility query helpers.
///
/// Centralises the two boolean queries used by glass/blur components so call
/// sites never duplicate `MediaQuery` lookups or guess the right API.
///
/// Usage:
/// ```dart
/// if (AccessibilityUtils.isHighContrast(context)) { … }
/// if (AccessibilityUtils.reduceTransparency(context)) { … }
/// if (AccessibilityUtils.reduceMotion(context)) { … }
/// ```
abstract final class AccessibilityUtils {
  AccessibilityUtils._();

  /// Returns true when the OS "Increase Contrast" (iOS) or
  /// "High Contrast" (Android) accessibility setting is enabled.
  ///
  /// Flutter surfaces this via [MediaQueryData.highContrast].
  static bool isHighContrast(BuildContext context) =>
      MediaQuery.highContrastOf(context);

  /// Returns true when the platform signals that transparent / blurred
  /// surfaces should be avoided.
  ///
  /// Flutter does not expose a separate "reduce transparency" API; instead
  /// `highContrast` covers both high-contrast *and* reduce-transparency
  /// system settings, so this is an intentional alias.
  static bool reduceTransparency(BuildContext context) =>
      MediaQuery.highContrastOf(context);

  /// Returns true when the OS "Reduce Motion" accessibility setting is on.
  ///
  /// When this is true, skip or shorten animations to avoid triggering
  /// motion sensitivity.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
