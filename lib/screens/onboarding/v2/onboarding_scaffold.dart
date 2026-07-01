import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/ds/ds.dart';

/// Shared chrome for every Onboarding V2 page: brand glow background, a top
/// progress bar with an optional circular back button, the page body, and a
/// bottom gated "continue" button (+ optional secondary action).
///
/// Pages provide only their body and wire [onContinue] (null = gate not met →
/// button disabled). Keeps all 14 pages visually identical and 60fps-consistent.
class OnboardingScaffold extends StatelessWidget {
  /// Progress in [0, 1]. Drives the top bar fill.
  final double progress;

  /// The page body. Rendered inside an [Expanded]; wrap in a scroll view if tall.
  final Widget child;

  /// Back affordance. Null hides the circular back button (e.g. first page).
  final VoidCallback? onBack;

  /// Primary CTA. Null disables the button (the page's gate is not satisfied).
  final VoidCallback? onContinue;

  /// Primary CTA label. Defaults to the localized "Devam et".
  final String? continueLabel;

  /// Shows a spinner inside the primary CTA.
  final bool continueLoading;

  /// Optional action rendered below the primary CTA (e.g. "Ücretsiz devam et").
  final Widget? secondaryAction;

  /// Hide the primary CTA entirely (rare — e.g. auto-advancing pages).
  final bool showContinue;

  /// Horizontal padding for the body. Defaults to `AppSpacing.xl`.
  final EdgeInsets? contentPadding;

  /// Accent for the glow; defaults to the live brand color.
  final Color? accent;

  const OnboardingScaffold({
    super.key,
    required this.progress,
    required this.child,
    this.onBack,
    this.onContinue,
    this.continueLabel,
    this.continueLoading = false,
    this.secondaryAction,
    this.showContinue = true,
    this.contentPadding,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = accent ?? context.watch<ThemeProvider>().primaryColor;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Ambient brand glow behind the header.
          Positioned(
            top: -90.h,
            left: -40.w,
            right: -40.w,
            child: IgnorePointer(
              child: Container(
                height: 260.h,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.8,
                    colors: [
                      primary.withValues(alpha: 0.11),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ProgressHeader(
                  progress: progress.clamp(0.0, 1.0),
                  primary: primary,
                  onBack: onBack,
                  reduceMotion: reduceMotion,
                ),
                Expanded(
                  child: Padding(
                    padding: contentPadding ??
                        EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                    child: child,
                  ),
                ),
                if (showContinue || secondaryAction != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl.w,
                      AppSpacing.sm.h,
                      AppSpacing.xl.w,
                      AppSpacing.lg.h,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showContinue)
                          AppButton(
                            label: continueLabel ??
                                AppLocalizations.of(context).translate('common.continue'),
                            loading: continueLoading,
                            onPressed: (onContinue != null && !continueLoading)
                                ? () {
                                    HapticFeedback.lightImpact();
                                    onContinue!.call();
                                  }
                                : null,
                          ),
                        if (secondaryAction != null) ...[
                          SizedBox(height: AppSpacing.sm.h),
                          secondaryAction!,
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final double progress;
  final Color primary;
  final VoidCallback? onBack;
  final bool reduceMotion;

  const _ProgressHeader({
    required this.progress,
    required this.primary,
    required this.onBack,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl.w,
        AppSpacing.sm.h,
        AppSpacing.xl.w,
        AppSpacing.xs.h,
      ),
      child: Row(
        children: [
          // Reserve the slot so the bar doesn't shift when back is hidden.
          SizedBox(
            width: 36.r,
            height: 36.r,
            child: onBack == null
                ? null
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onBack!.call();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15.r,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full.r),
                      ),
                    ),
                    AnimatedContainer(
                      duration: reduceMotion ? Duration.zero : AppMotion.normal,
                      curve: AppMotion.emphasized,
                      width: constraints.maxWidth * progress,
                      height: 6.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full.r),
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.65)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
