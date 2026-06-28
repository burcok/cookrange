import 'package:flutter/material.dart';
import '../../theme/app_dimensions.dart';

/// Cookrange DS — page route transition builders.
///
/// All transitions use smooth easing curves (no spring/elastic overshoot).
/// Rule R5: target 60fps, no jank.
class AppTransitions {
  AppTransitions._();

  /// Slide up from bottom — full-screen sheets / detail screens.
  static Route<T> slideUp<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? const Duration(milliseconds: 360),
        reverseTransitionDuration:
            duration ?? const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim,
            curve: const Cubic(0.2, 0.0, 0.0, 1.0), // smooth deceleration
            reverseCurve: const Cubic(0.5, 0.0, 1.0, 1.0),
          )),
          child: child,
        ),
      );

  /// Slide horizontally — within-flow forward navigation.
  static Route<T> slideRight<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration:
            duration ?? const Duration(milliseconds: 250),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim,
            curve: AppMotion.standard,
            reverseCurve: AppMotion.accelerate,
          )),
          child: child,
        ),
      );

  /// Fade through — sibling-level screens (tabs, filters).
  static Route<T> fade<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration:
            duration ?? const Duration(milliseconds: 200),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppMotion.standard),
          child: child,
        ),
      );

  /// Fade + subtle scale — dialogs / modals promoted to full screen.
  static Route<T> fadeScale<T>(Widget page, {Duration? duration}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration ?? AppMotion.normal,
        reverseTransitionDuration:
            duration ?? const Duration(milliseconds: 220),
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: AppMotion.standard);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}
