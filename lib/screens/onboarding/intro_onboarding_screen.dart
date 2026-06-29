import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';

class IntroOnboardingScreen extends StatefulWidget {
  /// When true, "Get Started" pops the route (replayed from Settings).
  /// When false (default), "Get Started" navigates to AppRoutes.onboarding.
  final bool isReplay;
  const IntroOnboardingScreen({super.key, this.isReplay = false});

  @override
  State<IntroOnboardingScreen> createState() => _IntroOnboardingScreenState();
}

class _IntroOnboardingScreenState extends State<IntroOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  static const _total = 5;

  // Per-page accent glow colors — use AppPalette static consts only.
  static const _accentColors = [
    AppPalette.brand,
    AppPalette.energyLight,
    AppPalette.sunsetC,
    AppPalette.sunsetA,
    AppPalette.brandSoft,
  ];

  static const _pages = [
    (Icons.restaurant_menu_rounded, 'intro.page1_title', 'intro.page1_subtitle'),
    (Icons.track_changes_rounded, 'intro.page2_title', 'intro.page2_subtitle'),
    (Icons.people_rounded, 'intro.page3_title', 'intro.page3_subtitle'),
    (Icons.fitness_center_rounded, 'intro.page4_title', 'intro.page4_subtitle'),
    (Icons.auto_awesome_rounded, 'intro.page5_title', 'intro.page5_subtitle'),
  ];

  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.ambient,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _skip() => _finish();

  void _finish() {
    unawaited(AnalyticsService().logEvent(
        name: 'intro_completed',
        parameters: {'page': _page, 'is_replay': widget.isReplay.toString()}));
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      _markIntroSeen();
      unawaited(Navigator.pushReplacementNamed(context, AppRoutes.onboarding));
    }
  }

  void _finishWithDiscover() {
    unawaited(AnalyticsService().logEvent(
        name: 'intro_completed',
        parameters: {
          'page': _page,
          'is_replay': widget.isReplay.toString(),
          'cta': 'find_gym',
        }));
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      _markIntroSeen();
      unawaited(Navigator.pushReplacementNamed(context, AppRoutes.discover));
    }
  }

  void _markIntroSeen() {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('intro_seen', true));
    final uid = context.read<UserProvider>().user?.uid;
    if (uid != null) {
      unawaited(FirestoreService().markIntroSeen(uid));
      final up = context.read<UserProvider>();
      if (up.user != null) up.setUser(up.user!.copyWith(introSeen: true));
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
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final accentColor = _accentColors[_page];

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // 1. Ambient glow blobs — soft radial circles behind everything
          Positioned.fill(
            child: _GlowLayer(
              accentColor: accentColor,
              controller: _glowCtrl,
              reduceMotion: reduceMotion,
            ),
          ),

          // 2. PageView
          PageView(
            controller: _pageCtrl,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _page = index);
            },
            children: List.generate(_total, (i) {
              final p = _pages[i];
              return _IntroPage(
                icon: p.$1,
                titleKey: p.$2,
                subtitleKey: p.$3,
                accentColor: _accentColors[i],
              );
            }),
          ),

          // 3. Skip button top-right
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
                              color: palette.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom controls
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
                    _Dots(
                        current: _page,
                        total: _total,
                        reduceMotion: reduceMotion),
                    SizedBox(height: 24.h),
                    _NavRow(
                      page: _page,
                      total: _total,
                      onNext: _next,
                      onDiscover: _finishWithDiscover,
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

// ─── _GlowLayer ───────────────────────────────────────────────────────────────

class _GlowLayer extends StatelessWidget {
  final Color accentColor;
  final AnimationController controller;
  final bool reduceMotion;

  const _GlowLayer({
    required this.accentColor,
    required this.controller,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return _StaticGlows(accentColor: accentColor);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value; // 0→1 breathing
        return _StaticGlows(accentColor: accentColor, breathe: t);
      },
    );
  }
}

class _StaticGlows extends StatelessWidget {
  final Color accentColor;
  final double breathe;

  const _StaticGlows({required this.accentColor, this.breathe = 0.5});

  @override
  Widget build(BuildContext context) {
    // Breathing scale: 0.92 → 1.08
    final scale = 0.92 + breathe * 0.16;

    return Stack(
      children: [
        // Top-right primary glow
        Positioned(
          top: -60.r,
          right: -80.r,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 320.r,
              height: 320.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom-left secondary glow (brand color, softer)
        Positioned(
          bottom: -40.r,
          left: -60.r,
          child: Transform.scale(
            scale: 1.0 + (1.0 - breathe) * 0.12,
            child: Container(
              width: 260.r,
              height: 260.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppPalette.brand.withValues(alpha: 0.13),
                    AppPalette.brand.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Center subtle fill
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 200.r,
              height: 200.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.07),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── _IntroPage ───────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final Color accentColor;

  const _IntroPage({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
      child: Column(
        children: [
          SizedBox(height: 80.h),
          _IllustrationBox(icon: icon, accentColor: accentColor),
          SizedBox(height: 48.h),
          Text(
            l10n.translate(titleKey),
            textAlign: TextAlign.center,
            style: AppText.of(context).displayM.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.translate(subtitleKey),
            textAlign: TextAlign.center,
            style: AppText.of(context).bodyL.copyWith(
                  color: palette.textSecondary,
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
  final Color accentColor;

  const _IllustrationBox({
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ambient glow halo
        Container(
          width: 230.r,
          height: 230.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accentColor.withValues(alpha: 0.12),
                accentColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),

        // Gradient border ring + frosted glass circle
        Container(
          width: 200.r,
          height: 200.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppPalette.brand,
                accentColor,
                AppPalette.brand,
              ],
            ),
          ),
          padding: EdgeInsets.all(2.r),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppPalette.glassBlurDefault,
                sigmaY: AppPalette.glassBlurDefault,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.glassFill,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.glassHighlight,
                      palette.glassFill,
                    ],
                  ),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppPalette.brand, accentColor],
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Icon(
                      icon,
                      size: 72.sp,
                      color: AppPalette.brand,
                    ),
                  ),
                ),
              ),
            ),
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

  const _Dots({
    required this.current,
    required this.total,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      label: 'Page ${current + 1} of $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isActive = i == current;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: AppMotion.standard,
              width: isActive ? 24.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: isActive ? AppPalette.brand : palette.border,
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
  final VoidCallback onNext;
  final VoidCallback onDiscover;
  final bool reduceMotion;

  const _NavRow({
    required this.page,
    required this.total,
    required this.onNext,
    required this.onDiscover,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final isLast = page == total - 1;

    if (isLast) {
      // Last slide: dual CTA — primary (meal plan) + ghost (find gym)
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: l10n.translate('onboarding.intro.cta_meal_plan'),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onNext();
            },
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: l10n.translate('onboarding.intro.cta_find_gym'),
            variant: AppButtonVariant.ghost,
            onPressed: () {
              HapticFeedback.lightImpact();
              onDiscover();
            },
          ),
        ],
      );
    }

    // Non-last slides: existing Next arrow button
    final label = l10n.translate('intro.next');
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onNext();
            },
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppMotion.fast,
              curve: AppMotion.standard,
              padding: EdgeInsets.symmetric(
                horizontal: 28.w,
                vertical: 16.h,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full.r),
                gradient: LinearGradient(
                  colors: palette.isDark
                      ? [
                          palette.surfaceElevated,
                          palette.surfaceElevated,
                        ]
                      : [AppPalette.brand, AppPalette.sunsetA],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.brand.withValues(alpha: 0.18),
                    blurRadius: 12.r,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                label,
                style: AppText.of(context).labelL.copyWith(
                      color: palette.isDark
                          ? AppPalette.brand
                          : palette.textInverse,
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
