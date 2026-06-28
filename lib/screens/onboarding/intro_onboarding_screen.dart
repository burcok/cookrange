import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/app_routes.dart';

class IntroOnboardingScreen extends StatefulWidget {
  /// When true, "Get Started" pops the route (replayed from Settings).
  /// When false (default), "Get Started" navigates to AppRoutes.onboarding.
  final bool isReplay;
  const IntroOnboardingScreen({super.key, this.isReplay = false});

  @override
  State<IntroOnboardingScreen> createState() => _IntroOnboardingScreenState();
}

class _IntroOnboardingScreenState extends State<IntroOnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  static const _total = 5;

  // Gradient colors per page: [start, end]
  static const _gradients = [
    [Color(0xFFF97300), Color(0xFFFF4E50)],
    [Color(0xFF0D8F6F), Color(0xFF1ABC9C)],
    [Color(0xFF6C63FF), Color(0xFF9B59B6)],
    [Color(0xFF1A73E8), Color(0xFF0D47A1)],
    [Color(0xFFE91E63), Color(0xFFF97300)],
  ];

  static const _pages = [
    (Icons.restaurant_menu_rounded, 'intro.page1_title', 'intro.page1_subtitle'),
    (Icons.track_changes_rounded, 'intro.page2_title', 'intro.page2_subtitle'),
    (Icons.people_rounded, 'intro.page3_title', 'intro.page3_subtitle'),
    (Icons.fitness_center_rounded, 'intro.page4_title', 'intro.page4_subtitle'),
    (Icons.auto_awesome_rounded, 'intro.page5_title', 'intro.page5_subtitle'),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _skip() => _finish();

  void _finish() {
    unawaited(AnalyticsService().logEvent(name: 'intro_completed', parameters: {'page': _page, 'is_replay': widget.isReplay.toString()}));
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('intro_seen', true);
      });
      unawaited(Navigator.pushReplacementNamed(context, AppRoutes.onboarding));
    }
  }

  void _next() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_page < _total - 1) {
      _pageCtrl.nextPage(
        duration: reduceMotion ? Duration.zero : AppMotion.normal,
        curve: AppMotion.standard,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradStart = _gradients[_page][0];
    final gradEnd = _gradients[_page][1];
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Animated gradient background
          AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 400),
            curve: AppMotion.standard,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradStart, gradEnd],
              ),
            ),
          ),

          // 2. PageView
          PageView(
            controller: _pageCtrl,
            onPageChanged: (index) => setState(() => _page = index),
            children: _pages
                .map(
                  (p) => _IntroPage(
                    icon: p.$1,
                    titleKey: p.$2,
                    subtitleKey: p.$3,
                  ),
                )
                .toList(),
          ),

          // 3. Overlay UI
          // Skip button top-right
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: _page < _total - 1 ? 1.0 : 0.0,
                duration: reduceMotion ? Duration.zero : AppMotion.fast,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.xs.h,
                    right: AppSpacing.md.w,
                  ),
                  child: Semantics(
                    label: AppLocalizations.of(context).translate('intro.skip'),
                    button: true,
                    child: TextButton(
                      onPressed: _page < _total - 1 ? _skip : null,
                      child: Text(
                        AppLocalizations.of(context).translate('intro.skip'),
                        style: AppText.of(context).labelM.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl.w,
                  vertical: AppSpacing.xl.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(current: _page, total: _total, reduceMotion: reduceMotion),
                    SizedBox(height: 24.h),
                    _NavRow(
                      page: _page,
                      total: _total,
                      gradientStartColor: gradStart,
                      onNext: _next,
                      reduceMotion: reduceMotion,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _IntroPage ───────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  const _IntroPage({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        children: [
          SizedBox(height: 80.h),
          _IllustrationBox(icon: icon),
          SizedBox(height: 48.h),
          Text(
            l10n.translate(titleKey),
            textAlign: TextAlign.center,
            style: AppText.of(context).displayM.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.translate(subtitleKey),
            textAlign: TextAlign.center,
            style: AppText.of(context).bodyL.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

// ─── _IllustrationBox ─────────────────────────────────────────────────────────

class _IllustrationBox extends StatelessWidget {
  final IconData icon;
  const _IllustrationBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer faint ring
        Container(
          width: 200.r,
          height: 200.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        // Icon container
        Container(
          width: 140.r,
          height: 140.r,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32.r),
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 72.sp,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─── _Dots ────────────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int current;
  final int total;
  final bool reduceMotion;
  const _Dots({required this.current, required this.total, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${current + 1} of $total',
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
            curve: AppMotion.standard,
            width: isActive ? 24.w : 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.full.r),
            ),
          ),
        );
      }),
      ),
    );
  }
}

// ─── _NavRow ──────────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  final int page;
  final int total;
  final Color gradientStartColor;
  final VoidCallback onNext;
  final bool reduceMotion;

  const _NavRow({
    required this.page,
    required this.total,
    required this.gradientStartColor,
    required this.onNext,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = page == total - 1
        ? l10n.translate('intro.get_started')
        : l10n.translate('intro.next');

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
          onTap: onNext,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : AppMotion.fast,
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: AppText.of(context).labelL.copyWith(
                    color: gradientStartColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}
