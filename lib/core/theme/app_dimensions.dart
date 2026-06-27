import 'package:flutter/animation.dart';

/// Cookrange Design System — geometric & motion tokens.
///
/// Single source of truth for spacing, radius, elevation, sizing and motion.
/// Values are **design pixels** (base 375pt iPhone). Apply `.r` / `.w` / `.h`
/// (flutter_screenutil) at the call site so the system scales per device.
///
/// Rule R7: build the token once, reuse everywhere. Never hardcode magic numbers.
class AppSpacing {
  AppSpacing._();

  /// 2 — hairline gaps
  static const double xxxs = 2;

  /// 4 — tight inner padding
  static const double xxs = 4;

  /// 8 — default inner gap
  static const double xs = 8;

  /// 12 — compact block gap
  static const double sm = 12;

  /// 16 — standard padding (default screen/card padding)
  static const double md = 16;

  /// 20 — comfortable padding
  static const double lg = 20;

  /// 24 — section padding
  static const double xl = 24;

  /// 32 — section gap
  static const double xxl = 32;

  /// 48 — large vertical rhythm
  static const double xxxl = 48;

  /// Standard screen horizontal padding.
  static const double screenH = 20;

  /// Standard screen vertical padding.
  static const double screenV = 16;
}

/// Corner radii.
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;

  /// Fully rounded (pills, avatars).
  static const double full = 999;

  /// Default card radius.
  static const double card = 20;

  /// Default bottom-sheet top radius.
  static const double sheet = 28;

  /// Default button radius.
  static const double button = 14;

  /// Default input radius.
  static const double input = 14;
}

/// Sizing primitives.
class AppSize {
  AppSize._();

  /// Minimum touch target (a11y).
  static const double touchTarget = 48;

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 36;

  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double avatarXl = 96;

  static const double buttonHeight = 52;
  static const double buttonHeightSm = 40;

  static const double fabSize = 56;

  /// Drag handle for bottom sheets.
  static const double sheetHandleW = 36;
  static const double sheetHandleH = 4;
}

/// Elevation as opacity for soft, modern shadows (use with theme shadow color).
class AppElevation {
  AppElevation._();

  static const double blurSm = 8;
  static const double blurMd = 16;
  static const double blurLg = 28;

  static const double opacityLight = 0.06;
  static const double opacityMedium = 0.10;
  static const double opacityStrong = 0.18;

  static const Offset offsetSm = Offset(0, 2);
  static const Offset offsetMd = Offset(0, 6);
  static const Offset offsetLg = Offset(0, 12);
}

/// Motion tokens — durations & curves. Keep animations smooth, intentional, 60fps.
class AppMotion {
  AppMotion._();

  /// 120ms — micro feedback (taps, ripples).
  static const Duration instant = Duration(milliseconds: 120);

  /// 200ms — small state changes (toggles, chips).
  static const Duration fast = Duration(milliseconds: 200);

  /// 320ms — standard transitions (cards, sheets, page elements).
  static const Duration normal = Duration(milliseconds: 320);

  /// 480ms — entrances / hero-ish reveals.
  static const Duration slow = Duration(milliseconds: 480);

  /// 1200ms — ambient loops (shimmer, breathing glows).
  static const Duration ambient = Duration(milliseconds: 1200);

  /// Standard easing for most UI.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasized entrance.
  static const Curve emphasized = Curves.easeOutBack;

  /// Decelerate (incoming elements).
  static const Curve decelerate = Curves.easeOut;

  /// Accelerate (outgoing elements).
  static const Curve accelerate = Curves.easeIn;

  /// Springy, playful.
  static const Curve spring = Curves.elasticOut;
}
