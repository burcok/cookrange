import 'package:flutter/material.dart';

/// Cookrange Design System — semantic color roles.
///
/// One source of truth for every color *meaning* (surface, text, border, status…),
/// resolved per brightness. Kills scattered hardcoded hex like `0xFF2E3A59` /
/// `0xFF0D1117` across the codebase (Rule R6 + R7).
///
/// Usage:
/// ```dart
/// final p = AppPalette.of(context);
/// color: p.surface, // or p.textPrimary, p.border, p.success ...
/// ```
/// The brand/primary color stays dynamic via `ThemeProvider.primaryColor`; this
/// palette covers everything *around* the brand color.
@immutable
class AppPalette {
  // ── Brand (static brand orange; live primary comes from ThemeProvider) ──
  static const Color brand = Color(0xFFF97300);
  static const Color brandSoft = Color(0xFFFFB266);

  // ── "Sunset Energy" bold gradient stops (warm) ──
  static const Color sunsetA = Color(0xFFFF8A3D);
  static const Color sunsetB = Color(0xFFF97300);
  static const Color sunsetC = Color(0xFFFF4E50);

  // ── Electric "energy" accent (cool counterpoint for fitness/progress) ──
  static const Color energyLight = Color(0xFF0FB9A6);
  static const Color energyDark = Color(0xFF2DD4BF);

  // ── Backgrounds ──
  final Color background; // app scaffold
  final Color surface; // cards, sheets
  final Color surfaceVariant; // subtle filled areas, inputs
  final Color surfaceElevated; // raised surfaces / menus

  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;

  // ── Lines & dividers ──
  final Color border;
  final Color divider;

  // ── Status ──
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // ── Macro accents (nutrition domain) ──
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color calories;

  // ── Electric energy accent (resolved per theme) ──
  final Color energy;
  final Color energySoft;

  // ── Misc ──
  final Color shadow;
  final Color scrim;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.energy,
    required this.energySoft,
    required this.shadow,
    required this.scrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const AppPalette light = AppPalette(
    background: Color(0xFFFCFBF9),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF4F5F8),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A2233),
    textSecondary: Color(0xFF5C6477),
    textTertiary: Color(0xFF98A0B0),
    textInverse: Color(0xFFFFFFFF),
    border: Color(0xFFE9EBF0),
    divider: Color(0xFFEFF1F5),
    success: Color(0xFF22A565),
    warning: Color(0xFFE8A317),
    error: Color(0xFFE5484D),
    info: Color(0xFF3B82F6),
    protein: Color(0xFF3B82F6),
    carbs: Color(0xFFF59E0B),
    fat: Color(0xFF8B5CF6),
    calories: Color(0xFFF97300),
    energy: energyLight,
    energySoft: Color(0xFFCBF3EE),
    shadow: Color(0xFF1A2233),
    scrim: Color(0x99000000),
    shimmerBase: Color(0xFFE8EAEF),
    shimmerHighlight: Color(0xFFF6F7F9),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceVariant: Color(0xFF1C2430),
    surfaceElevated: Color(0xFF1E2531),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFFA0AAB8),
    textTertiary: Color(0xFF6B7585),
    textInverse: Color(0xFF0D1117),
    border: Color(0xFF273140),
    divider: Color(0xFF222B36),
    success: Color(0xFF3DD68C),
    warning: Color(0xFFF5BE4A),
    error: Color(0xFFFF6166),
    info: Color(0xFF60A5FA),
    protein: Color(0xFF60A5FA),
    carbs: Color(0xFFFBBF24),
    fat: Color(0xFFA78BFA),
    calories: Color(0xFFFF9A4D),
    energy: energyDark,
    energySoft: Color(0xFF114B45),
    shadow: Color(0xFF000000),
    scrim: Color(0xB3000000),
    shimmerBase: Color(0xFF1C2430),
    shimmerHighlight: Color(0xFF273140),
  );

  /// Resolve the palette for the current theme brightness.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static AppPalette forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;

  bool get isDark => background == dark.background;
}

/// Convenience extension: `context.palette`.
extension AppPaletteX on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
