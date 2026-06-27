import 'package:flutter/material.dart';
import '../../theme/app_dimensions.dart';

/// Cookrange DS — page route transition builders.
///
/// Usage:
/// ```dart
/// Navigator.push(context, AppTransitions.slideUp(RecipeDetailScreen()));
/// Navigator.push(context, AppTransitions.fade(NutritionScreen()));
/// Navigator.push(context, AppTransitions.sharedAxis(ProfileScreen(), axis: SharedAxisTransitionType.horizontal));
/// ```
class AppTransitions {
  AppTransitions._();

  /// Slide up from bottom — use for full-screen sheets / detail screens.
  static Route<T> slideUp<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration: duration ?? AppMotion.fast,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: AppMotion.emphasized)),
          child: child,
        ),
      );

  /// Slide horizontally — use for within-flow forward navigation.
  static Route<T> slideRight<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration: duration ?? AppMotion.fast,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: AppMotion.standard)),
          child: child,
        ),
      );

  /// Fade through — use for sibling-level screens (tabs, filters).
  static Route<T> fade<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration: duration ?? AppMotion.fast,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppMotion.standard),
          child: child,
        ),
      );

  /// Fade + scale — use for dialogs / modals promoted to full screen.
  static Route<T> fadeScale<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration: duration ?? AppMotion.fast,
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: AppMotion.spring);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}
