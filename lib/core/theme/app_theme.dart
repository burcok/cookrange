import 'package:flutter/material.dart';
import '../../constants.dart' as c;

// 1. ColorScheme extension: Tüm constants renkleri burada
extension CustomColorScheme on ColorScheme {
  Color get onboardingTitleColor =>
      brightness == Brightness.dark ? c.onboardingTitleDark : c.onboardingTitle;
  Color get onboardingSubtitleColor => brightness == Brightness.dark
      ? c.onboardingSubtitleDark
      : c.onboardingSubtitle;
  Color get onboardingNextButtonColor => brightness == Brightness.dark
      ? c.onboardingNextButtonColorDark
      : c.onboardingNextButtonColor;
  Color get onboardingNextButtonBorderColor => brightness == Brightness.dark
      ? c.onboardingNextButtonBorderColorDark
      : c.onboardingNextButtonBorderColor;
  Color get onboardingOptionBgColor => brightness == Brightness.dark
      ? c.onboardingOptionBgColorDark
      : c.onboardingOptionBgColor;
  Color get onboardingOptionTextColor => brightness == Brightness.dark
      ? c.onboardingOptionTextColorDark
      : c.onboardingOptionTextColor;
  Color get onboardingOptionSelectedBgColor => brightness == Brightness.dark
      ? c.onboardingOptionSelectedBgColorDark
      : c.onboardingOptionSelectedBgColor;
  // Diğer constants renkleri için de aynı şekilde ekleyin...
  Color get schemaPreferredColor => brightness == Brightness.dark
      ? c.schemaPreferredColorDark
      : c.schemaPreferredColor;
  Color get primaryColorCustom =>
      brightness == Brightness.dark ? c.primaryColorDark : c.primaryColor;
  Color get secondaryColorCustom =>
      brightness == Brightness.dark ? c.secondaryColorDark : c.secondaryColor;
  Color get titleColor => brightness == Brightness.dark ? c.titleDark : c.title;
  Color get subtitleColor =>
      brightness == Brightness.dark ? c.subtitleDark : c.subtitle;
  Color get backgroundColor2 => brightness == Brightness.dark
      ? c.backgroundColor2Dark
      : c.backgroundColor2;
}

// 2. Light ve dark colorScheme oluştur
const ColorScheme lightColorScheme = ColorScheme.light(
  primary: c.primaryColor,
  secondary: c.secondaryColor,
  background: c.backgroundColorLight,
  surface: c.backgroundColor2,
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onBackground: c.title,
  onSurface: c.subtitle,
  error: Colors.red,
  onError: Colors.white,
);

const ColorScheme darkColorScheme = ColorScheme.dark(
  primary: c.primaryColorDark,
  secondary: c.secondaryColorDark,
  background: c.backgroundColorDark,
  surface: c.backgroundColor2Dark,
  onPrimary: Colors.black,
  onSecondary: Colors.black,
  onBackground: c.titleDark,
  onSurface: c.subtitleDark,
  error: Colors.red,
  onError: Colors.black,
);

// 3. ThemeData'lar
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: c.backgroundColorLight,
        fontFamily: 'Poppins',
        useMaterial3: true,
        extensions: [lightAppColors],
      );

  static ThemeData get darkTheme => ThemeData(
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: c.backgroundColorDark,
        fontFamily: 'Poppins',
        useMaterial3: true,
        extensions: [darkAppColors],
      );
}

class AppColors extends ThemeExtension<AppColors> {
  final Color schemaPreferredColor;
  final Color schemaPreferredColorDark;
  final Color primaryColor;
  final Color primaryColorDark;
  final Color secondaryColor;
  final Color secondaryColorDark;
  final Color title;
  final Color titleDark;
  final Color subtitle;
  final Color subtitleDark;
  final Color backgroundColorLight;
  final Color backgroundColorDark;
  final Color backgroundColor2;
  final Color backgroundColor2Dark;
  final Color onboardingTitleColor;
  final Color onboardingTitleColorDark;
  final Color onboardingSubtitleColor;
  final Color onboardingSubtitleColorDark;
  final Color onboardingNextButtonColor;
  final Color onboardingNextButtonColorDark;
  final Color onboardingOptionBgColor;
  final Color onboardingOptionBgColorDark;
  final Color onboardingOptionTextColor;
  final Color onboardingOptionTextColorDark;
  final Color onboardingOptionSelectedBgColor;
  final Color onboardingOptionSelectedBgColorDark;

  const AppColors({
    required this.schemaPreferredColor,
    required this.schemaPreferredColorDark,
    required this.primaryColor,
    required this.primaryColorDark,
    required this.secondaryColor,
    required this.secondaryColorDark,
    required this.title,
    required this.titleDark,
    required this.subtitle,
    required this.subtitleDark,
    required this.backgroundColorLight,
    required this.backgroundColorDark,
    required this.backgroundColor2,
    required this.backgroundColor2Dark,
    required this.onboardingTitleColor,
    required this.onboardingTitleColorDark,
    required this.onboardingSubtitleColor,
    required this.onboardingSubtitleColorDark,
    required this.onboardingNextButtonColor,
    required this.onboardingNextButtonColorDark,
    required this.onboardingOptionBgColor,
    required this.onboardingOptionBgColorDark,
    required this.onboardingOptionTextColor,
    required this.onboardingOptionTextColorDark,
    required this.onboardingOptionSelectedBgColor,
    required this.onboardingOptionSelectedBgColorDark,
  });

  @override
  AppColors copyWith({
    Color? schemaPreferredColor,
    Color? schemaPreferredColorDark,
    Color? primaryColor,
    Color? primaryColorDark,
    Color? secondaryColor,
    Color? secondaryColorDark,
    Color? title,
    Color? titleDark,
    Color? subtitle,
    Color? subtitleDark,
    Color? backgroundColorLight,
    Color? backgroundColorDark,
    Color? backgroundColor2,
    Color? backgroundColor2Dark,
    Color? onboardingTitleColor,
    Color? onboardingTitleColorDark,
    Color? onboardingSubtitleColor,
    Color? onboardingSubtitleColorDark,
    Color? onboardingNextButtonColor,
    Color? onboardingNextButtonColorDark,
    Color? onboardingOptionBgColor,
    Color? onboardingOptionBgColorDark,
    Color? onboardingOptionTextColor,
    Color? onboardingOptionTextColorDark,
    Color? onboardingOptionSelectedBgColor,
    Color? onboardingOptionSelectedBgColorDark,
  }) {
    return AppColors(
      schemaPreferredColor: schemaPreferredColor ?? this.schemaPreferredColor,
      schemaPreferredColorDark:
          schemaPreferredColorDark ?? this.schemaPreferredColorDark,
      primaryColor: primaryColor ?? this.primaryColor,
      primaryColorDark: primaryColorDark ?? this.primaryColorDark,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      secondaryColorDark: secondaryColorDark ?? this.secondaryColorDark,
      title: title ?? this.title,
      titleDark: titleDark ?? this.titleDark,
      subtitle: subtitle ?? this.subtitle,
      subtitleDark: subtitleDark ?? this.subtitleDark,
      backgroundColorLight: backgroundColorLight ?? this.backgroundColorLight,
      backgroundColorDark: backgroundColorDark ?? this.backgroundColorDark,
      backgroundColor2: backgroundColor2 ?? this.backgroundColor2,
      backgroundColor2Dark: backgroundColor2Dark ?? this.backgroundColor2Dark,
      onboardingTitleColor: onboardingTitleColor ?? this.onboardingTitleColor,
      onboardingTitleColorDark:
          onboardingTitleColorDark ?? this.onboardingTitleColorDark,
      onboardingSubtitleColor:
          onboardingSubtitleColor ?? this.onboardingSubtitleColor,
      onboardingSubtitleColorDark:
          onboardingSubtitleColorDark ?? this.onboardingSubtitleColorDark,
      onboardingNextButtonColor:
          onboardingNextButtonColor ?? this.onboardingNextButtonColor,
      onboardingNextButtonColorDark:
          onboardingNextButtonColorDark ?? this.onboardingNextButtonColorDark,
      onboardingOptionBgColor:
          onboardingOptionBgColor ?? this.onboardingOptionBgColor,
      onboardingOptionBgColorDark:
          onboardingOptionBgColorDark ?? this.onboardingOptionBgColorDark,
      onboardingOptionTextColor:
          onboardingOptionTextColor ?? this.onboardingOptionTextColor,
      onboardingOptionTextColorDark:
          onboardingOptionTextColorDark ?? this.onboardingOptionTextColorDark,
      onboardingOptionSelectedBgColor: onboardingOptionSelectedBgColor ??
          this.onboardingOptionSelectedBgColor,
      onboardingOptionSelectedBgColorDark:
          onboardingOptionSelectedBgColorDark ??
              this.onboardingOptionSelectedBgColorDark,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return this;
  }
}

const AppColors lightAppColors = AppColors(
  schemaPreferredColor: c.schemaPreferredColor,
  schemaPreferredColorDark: c.schemaPreferredColorDark,
  primaryColor: c.primaryColor,
  primaryColorDark: c.primaryColorDark,
  secondaryColor: c.secondaryColor,
  secondaryColorDark: c.secondaryColorDark,
  title: c.title,
  titleDark: c.titleDark,
  subtitle: c.subtitle,
  subtitleDark: c.subtitleDark,
  backgroundColorLight: c.backgroundColorLight,
  backgroundColorDark: c.backgroundColorDark,
  backgroundColor2: c.backgroundColor2,
  backgroundColor2Dark: c.backgroundColor2Dark,
  onboardingTitleColor: c.onboardingTitle,
  onboardingTitleColorDark: c.onboardingTitleDark,
  onboardingSubtitleColor: c.onboardingSubtitle,
  onboardingSubtitleColorDark: c.onboardingSubtitleDark,
  onboardingNextButtonColor: c.onboardingNextButtonColor,
  onboardingNextButtonColorDark: c.onboardingNextButtonColorDark,
  onboardingOptionBgColor: c.onboardingOptionBgColor,
  onboardingOptionBgColorDark: c.onboardingOptionBgColorDark,
  onboardingOptionTextColor: c.onboardingOptionTextColor,
  onboardingOptionTextColorDark: c.onboardingOptionTextColorDark,
  onboardingOptionSelectedBgColor: c.onboardingOptionSelectedBgColor,
  onboardingOptionSelectedBgColorDark: c.onboardingOptionSelectedBgColorDark,
);

const AppColors darkAppColors = AppColors(
  schemaPreferredColor: c.schemaPreferredColor,
  schemaPreferredColorDark: c.schemaPreferredColorDark,
  primaryColor: c.primaryColor,
  primaryColorDark: c.primaryColorDark,
  secondaryColor: c.secondaryColor,
  secondaryColorDark: c.secondaryColorDark,
  title: c.title,
  titleDark: c.titleDark,
  subtitle: c.subtitle,
  subtitleDark: c.subtitleDark,
  backgroundColorLight: c.backgroundColorLight,
  backgroundColorDark: c.backgroundColorDark,
  backgroundColor2: c.backgroundColor2,
  backgroundColor2Dark: c.backgroundColor2Dark,
  onboardingTitleColor: c.onboardingTitle,
  onboardingTitleColorDark: c.onboardingTitleDark,
  onboardingSubtitleColor: c.onboardingSubtitle,
  onboardingSubtitleColorDark: c.onboardingSubtitleDark,
  onboardingNextButtonColor: c.onboardingNextButtonColor,
  onboardingNextButtonColorDark: c.onboardingNextButtonColorDark,
  onboardingOptionBgColor: c.onboardingOptionBgColor,
  onboardingOptionBgColorDark: c.onboardingOptionBgColorDark,
  onboardingOptionTextColor: c.onboardingOptionTextColor,
  onboardingOptionTextColorDark: c.onboardingOptionTextColorDark,
  onboardingOptionSelectedBgColor: c.onboardingOptionSelectedBgColor,
  onboardingOptionSelectedBgColorDark: c.onboardingOptionSelectedBgColorDark,
);

class AppColorScheme extends ColorScheme {
  final Color onboardingTitleColor;
  final Color onboardingSubtitleColor;
  final Color schemaPreferredColor;

  const AppColorScheme({
    required super.brightness,
    required super.primary,
    required super.onPrimary,
    required super.secondary,
    required super.onSecondary,
    required super.error,
    required super.onError,
    required super.background,
    required super.onBackground,
    required super.surface,
    required super.onSurface,
    required this.onboardingTitleColor,
    required this.onboardingSubtitleColor,
    required this.schemaPreferredColor,
  });

  factory AppColorScheme.light() {
    return const AppColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1E88E5),
      onPrimary: Colors.white,
      secondary: Color(0xFF2196F3),
      onSecondary: Colors.white,
      error: Color(0xFFB00020),
      onError: Colors.white,
      background: Colors.white,
      onBackground: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      onboardingTitleColor: Color(0xFF1E1E1E),
      onboardingSubtitleColor: Color(0xFF757575),
      schemaPreferredColor: Color(0xFF2196F3),
    );
  }

  factory AppColorScheme.dark() {
    return const AppColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF1E88E5),
      onPrimary: Colors.white,
      secondary: Color(0xFF2196F3),
      onSecondary: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      background: Color(0xFF121212),
      onBackground: Colors.white,
      surface: Color(0xFF121212),
      onSurface: Colors.white,
      onboardingTitleColor: Colors.white,
      onboardingSubtitleColor: Color(0xFFB0B0B0),
      schemaPreferredColor: Color(0xFF2196F3),
    );
  }
}
