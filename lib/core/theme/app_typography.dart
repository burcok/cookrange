import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_palette.dart';

/// Cookrange Design System — semantic typography scale.
///
/// Theme-aware text styles built on Poppins (display/UI) with a consistent
/// scale. Sizes use `.sp` so they respect device scaling. Resolve via
/// `AppText.of(context)` then pick a role:
/// ```dart
/// Text('Title', style: AppText.of(context).headlineM);
/// ```
class AppText {
  final AppPalette _p;
  const AppText._(this._p);

  static AppText of(BuildContext context) => AppText._(AppPalette.of(context));
  static AppText forPalette(AppPalette p) => AppText._(p);

  static const String fontFamily = 'Poppins';

  // ── Display — hero numbers / splash ──
  TextStyle get displayL => TextStyle(
        fontFamily: fontFamily,
        fontSize: 40.sp,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.5,
        color: _p.textPrimary,
      );

  TextStyle get displayM => TextStyle(
        fontFamily: fontFamily,
        fontSize: 34.sp,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: -0.4,
        color: _p.textPrimary,
      );

  // ── Headline — screen / section titles ──
  TextStyle get headlineL => TextStyle(
        fontFamily: fontFamily,
        fontSize: 26.sp,
        fontWeight: FontWeight.bold,
        height: 1.2,
        letterSpacing: -0.3,
        color: _p.textPrimary,
      );

  TextStyle get headlineM => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22.sp,
        fontWeight: FontWeight.bold,
        height: 1.25,
        letterSpacing: -0.2,
        color: _p.textPrimary,
      );

  TextStyle get headlineS => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: _p.textPrimary,
      );

  // ── Title — card headers, list leads ──
  TextStyle get titleL => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: _p.textPrimary,
      );

  TextStyle get titleM => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: _p.textPrimary,
      );

  // ── Body — paragraphs, descriptions ──
  TextStyle get bodyL => TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: _p.textSecondary,
      );

  TextStyle get bodyM => TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: _p.textSecondary,
      );

  // ── Label — buttons, chips, captions ──
  TextStyle get labelL => TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: _p.textPrimary,
      );

  TextStyle get labelM => TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: _p.textSecondary,
      );

  TextStyle get labelS => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.2,
        color: _p.textTertiary,
      );

  /// All-caps overline (section eyebrows).
  TextStyle get overline => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 1.2,
        color: _p.textTertiary,
      );
}
