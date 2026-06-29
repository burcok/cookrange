import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_routes.dart';
import '../../../core/widgets/ds/ds.dart';

/// One marketing slide in the intro carousel.
class _Feature {
  final IconData icon;
  final Color accent;
  final String titleKey;
  final String subtitleKey;
  final bool premium;
  const _Feature(this.icon, this.accent, this.titleKey, this.subtitleKey,
      {this.premium = false});
}

/// Yazio-style first-run intro: centered wordmark + language toggle, an
/// auto-advancing swipeable feature carousel, dots, and the entry CTAs.
///
/// New (logged-out) flow: `Başla` → V2 onboarding; `Zaten hesabım var` → login.
/// Replay (from Settings): `isReplay = true` → `Başla` just pops.
class IntroScreen extends StatefulWidget {
  final bool isReplay;
  const IntroScreen({super.key, this.isReplay = false});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  // Looping carousel: start far from 0 so we can page both directions freely.
  static const int _kBase = 10000;
  final PageController _pageCtrl = PageController(initialPage: _kBase);
  Timer? _autoAdvance;
  int _index = 0;
  bool _started = false;

  static const List<_Feature> _features = [
    _Feature(Icons.auto_awesome_rounded, AppPalette.brand,
        'onboarding.v2.intro.features.ai_plan.title',
        'onboarding.v2.intro.features.ai_plan.subtitle'),
    _Feature(Icons.qr_code_scanner_rounded, AppPalette.sunsetA,
        'onboarding.v2.intro.features.scan.title',
        'onboarding.v2.intro.features.scan.subtitle'),
    _Feature(Icons.fitness_center_rounded, AppPalette.energyLight,
        'onboarding.v2.intro.features.gyms.title',
        'onboarding.v2.intro.features.gyms.subtitle'),
    _Feature(Icons.sports_rounded, AppPalette.sunsetC,
        'onboarding.v2.intro.features.coaches.title',
        'onboarding.v2.intro.features.coaches.subtitle'),
    _Feature(Icons.groups_2_rounded, AppPalette.brandSoft,
        'onboarding.v2.intro.features.community.title',
        'onboarding.v2.intro.features.community.subtitle'),
    _Feature(Icons.visibility_rounded, Color(0xFFE8A317),
        'onboarding.v2.intro.features.gym_presence.title',
        'onboarding.v2.intro.features.gym_presence.subtitle',
        premium: true),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.of(context).disableAnimations) {
      _started = true;
      _autoAdvance = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pageCtrl.hasClients) return;
        _pageCtrl.nextPage(
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _restartTimer() {
    if (MediaQuery.of(context).disableAnimations) return;
    _autoAdvance?.cancel();
    _autoAdvance = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      _pageCtrl.nextPage(
          duration: AppMotion.slow, curve: AppMotion.emphasized);
    });
  }

  void _start() {
    HapticFeedback.mediumImpact();
    unawaited(AnalyticsService().logEvent(
        name: 'intro_v2_start',
        parameters: {'is_replay': widget.isReplay.toString()}));
    if (widget.isReplay) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.pushNamed(context, AppRoutes.onboardingV2);
  }

  void _haveAccount() {
    HapticFeedback.selectionClick();
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final accent = _features[_index].accent;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Accent glow that crossfades with the active slide.
          Positioned(
            top: -80.h,
            left: -40.w,
            right: -40.w,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                child: Container(
                  key: ValueKey(_index),
                  height: 320.h,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.85,
                      colors: [accent.withValues(alpha: 0.16), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar: wordmark (center) + language toggle (right) ──
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'cookrange',
                        style: t.headlineM.copyWith(
                          fontFamily: 'Lexend',
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: widget.isReplay
                            ? _CircleIconButton(
                                icon: Icons.close_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              )
                            : const _LanguageToggle(),
                      ),
                      if (widget.isReplay)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(width: 36.r),
                        ),
                    ],
                  ),
                ),
                // ── Carousel ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (raw) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = raw % _features.length);
                      _restartTimer();
                    },
                    itemBuilder: (context, raw) {
                      final f = _features[raw % _features.length];
                      return _FeatureSlide(
                        feature: f,
                        premiumLabel:
                            l10n.translate('onboarding.v2.intro.premium_badge'),
                        reduceMotion: reduceMotion,
                      );
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                // ── Dots ──
                _Dots(
                  count: _features.length,
                  active: _index,
                  accent: primary,
                  reduceMotion: reduceMotion,
                ),
                SizedBox(height: AppSpacing.xl.h),
                // ── CTAs ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                  child: AppButton(
                    label: l10n.translate('onboarding.v2.intro.start'),
                    onPressed: _start,
                  ),
                ),
                if (!widget.isReplay) ...[
                  SizedBox(height: AppSpacing.xs.h),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _haveAccount,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm.r),
                      child: RichText(
                        text: TextSpan(
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                          children: [
                            TextSpan(
                                text: l10n.translate(
                                    'onboarding.v2.intro.have_account')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.md.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature slide ──────────────────────────────────────────────────────────

class _FeatureSlide extends StatelessWidget {
  final _Feature feature;
  final String premiumLabel;
  final bool reduceMotion;
  const _FeatureSlide({
    required this.feature,
    required this.premiumLabel,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IllustrationHero(
            icon: feature.icon,
            accent: feature.accent,
            premium: feature.premium,
            premiumLabel: premiumLabel,
          ),
          SizedBox(height: AppSpacing.xxl.h),
          Text(
            l10n.translate(feature.titleKey),
            textAlign: TextAlign.center,
            style: t.displayM.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            l10n.translate(feature.subtitleKey),
            textAlign: TextAlign.center,
            style: t.bodyL.copyWith(color: palette.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _IllustrationHero extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool premium;
  final String premiumLabel;
  const _IllustrationHero({
    required this.icon,
    required this.accent,
    required this.premium,
    required this.premiumLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return SizedBox(
      width: 240.r,
      height: 240.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft halo
          Container(
            width: 240.r,
            height: 240.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent.withValues(alpha: 0.16), Colors.transparent],
              ),
            ),
          ),
          // Gradient ring + frosted glass core
          Container(
            width: 188.r,
            height: 188.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [AppPalette.brand, accent, AppPalette.brand],
              ),
            ),
            padding: EdgeInsets.all(2.5.r),
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
                      colors: [palette.glassHighlight, palette.glassFill],
                    ),
                  ),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppPalette.brand, accent],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Icon(icon, size: 84.sp, color: AppPalette.brand),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Premium badge
          if (premium)
            Positioned(
              top: 6.r,
              right: 6.r,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF6C453), Color(0xFFE8A317)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8A317).withValues(alpha: 0.4),
                      blurRadius: 10.r,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12.r, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      premiumLabel,
                      style: t.labelS.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dots ─────────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  final Color accent;
  final bool reduceMotion;
  const _Dots({
    required this.count,
    required this.active,
    required this.accent,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.normal,
          curve: AppMotion.standard,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: on ? 22.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: on ? accent : palette.border,
            borderRadius: BorderRadius.circular(AppRadius.full.r),
          ),
        );
      }),
    );
  }
}

// ─── Language toggle ────────────────────────────────────────────────────────

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final lang = context.watch<LanguageProvider>();
    final current = lang.currentLocale.languageCode;

    Widget seg(String code, String label) {
      final on = current == code;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) {
            HapticFeedback.selectionClick();
            context.read<LanguageProvider>().setLanguage(code);
          }
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
          decoration: BoxDecoration(
            color: on ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.12),
                      blurRadius: 6.r,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: t.labelS.copyWith(
              color: on ? palette.textPrimary : palette.textTertiary,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('en', 'EN'), seg('tr', 'TR')],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36.r,
        height: 36.r,
        decoration: BoxDecoration(
          color: palette.surfaceVariant.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, size: 18.r, color: palette.textSecondary),
      ),
    );
  }
}
