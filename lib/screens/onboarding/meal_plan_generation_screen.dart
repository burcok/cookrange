import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/models/weekly_meal_plan_model.dart';
import '../../core/repositories/meal_plan_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';

/// Flagship interstitial shown after onboarding completion.
/// Generates the user's first weekly meal plan with an animated staged
/// progress experience, then navigates to /main on success.
class MealPlanGenerationScreen extends StatefulWidget {
  const MealPlanGenerationScreen({super.key});

  @override
  State<MealPlanGenerationScreen> createState() =>
      _MealPlanGenerationScreenState();
}

class _MealPlanGenerationScreenState extends State<MealPlanGenerationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _stageCtrl;
  late final AnimationController _successCtrl;

  late final Animation<double> _progressAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _stageSlide;
  late final Animation<double> _stageFade;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  int _stage = 0;
  bool _hasError = false;
  bool _done = false;
  // Signals _runFakeStages to stop once the real generation completes so it
  // doesn't race with _finishSuccess on the shared animation controllers.
  bool _finishing = false;

  // Captured in didChangeDependencies so _markMealPlanGenerated can call it
  // after the widget is unmounted (post-navigation).
  UserProvider? _userProvider;

  // Minimum stage durations (ms) — total ~3.5 s minimum visual time
  static const _stageDurations = [600, 700, 700, 600, 500, 400];

  // Expected generation window used to drive the progress bar at a constant
  // linear rate (0 → 0.95). Roughly a typical free-model plan generation; if it
  // finishes sooner the bar jumps to 100%, if later it holds at 0.95.
  static const int _expectedGenerationMs = 60000;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userProvider ??= context.read<UserProvider>();
  }

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _stageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _progressAnim =
        CurvedAnimation(parent: _progressCtrl, curve: Curves.linear);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _stageSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _stageCtrl, curve: Curves.easeOutCubic),
    );
    _stageFade = CurvedAnimation(parent: _stageCtrl, curve: Curves.easeIn);
    _successScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successFade = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);

    _stageCtrl.forward();
    _startGeneration();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _stageCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    final user = context.read<UserProvider>().user;
    final localeCode =
        context.read<LanguageProvider>().currentLocale.languageCode;

    // Drive the bar LINEARLY (constant rate) from 0 → 0.95 across the expected
    // generation window, so the percentage tracks real elapsed time instead of
    // easing/stalling at a fake value. On real success _finishSuccess takes it
    // 0.95 → 1.0; if generation runs longer than expected it simply holds at
    // 0.95 ("still working") rather than jumping around.
    unawaited(_progressCtrl.animateTo(0.95,
        duration: const Duration(milliseconds: _expectedGenerationMs)));

    // Advance fake UI stages in parallel with the real network call.
    unawaited(_runFakeStages());

    WeeklyMealPlanModel? plan;
    try {
      if (user == null) throw Exception('user-not-loaded');
      plan = await MealPlanRepository().getWeeklyPlan(
        user,
        forceRefresh: true,
        locale: localeCode,
      );
      if (!mounted) return;
      if (plan == null) throw Exception('plan-generation-failed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
      _progressCtrl.stop();
      _pulseCtrl.stop();
      return;
    }
    // Stop fake-stage loop before finishing so there's no concurrent controller use.
    _finishing = true;
    await _finishSuccess();
  }

  Future<void> _runFakeStages() async {
    for (int i = 0; i < _stageDurations.length - 1; i++) {
      await Future.delayed(Duration(milliseconds: _stageDurations[i]));
      if (!mounted || _hasError || _finishing) return;
      await _advanceStage(i + 1);
    }
  }

  Future<void> _advanceStage(int next) async {
    if (!mounted) return;
    _stageCtrl.reset();
    setState(() => _stage = next);
    await _stageCtrl.forward();
    if (!mounted) return;
    if (next < _stageDurations.length - 1) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  Future<void> _finishSuccess() async {
    await _advanceStage(5);
    if (!mounted) return;
    await _progressCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    if (!mounted) return;
    setState(() => _done = true);
    unawaited(HapticFeedback.mediumImpact());
    await _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Persist meal_plan_generated=true (awaited) so RouteGuard allows /main and
    // a live UserProvider re-fetch can't revert the flag before the write lands.
    await _markMealPlanGenerated();
    if (!mounted) return;

    unawaited(Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.main, (route) => false));
    unawaited(AnalyticsService()
        .logEvent(name: 'onboarding_plan_generated', parameters: {}));
  }

  /// Marks the onboarding meal-plan gate satisfied. Updates the in-memory
  /// UserProvider immediately AND awaits the Firestore write — the await is
  /// essential: UserProvider's live listener can re-fetch the user doc at any
  /// time (`_fetchAndMerge`), which would overwrite an in-memory-only flag with
  /// the stale stored `false` and bounce the user back here (the loop).
  Future<void> _markMealPlanGenerated() async {
    // Session-static gate: RouteGuard honours this immediately, immune to the
    // AuthService cache/re-fetch race that previously bounced users back here.
    AuthService.mealPlanGatePassed = true;
    // Drop the stale AuthService cache so any UserProvider re-fetch reads fresh.
    AuthService().invalidateUserCache();
    // In-memory first, so RouteGuard sees it on the very next build.
    try {
      final up = _userProvider;
      if (up?.user != null) {
        up!.setUser(up.user!.copyWith(mealPlanGenerated: true));
      }
    } catch (_) {}

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'meal_plan_generated': true}).timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('MealPlanGeneration: failed to set meal_plan_generated: $e');
    }
  }

  /// User chose to skip after an error. Persist the gate flag (awaited) BEFORE
  /// navigating so RouteGuard's meal-plan gate lets /main render instead of
  /// bouncing straight back here and re-triggering generation (the loop).
  Future<void> _skip() async {
    await _markMealPlanGenerated();
    if (!mounted) return;
    unawaited(Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.main, (route) => false));
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _stage = 0;
      _done = false;
    });
    _progressCtrl.reset();
    unawaited(_pulseCtrl.repeat(reverse: true));
    unawaited(_stageCtrl.forward());
    await _startGeneration();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: palette.background,
      body: _hasError
          ? _buildError(palette, l10n)
          : _buildMain(palette, l10n, reduceMotion),
    );
  }

  Widget _buildMain(
      AppPalette palette, AppLocalizations l10n, bool reduceMotion) {
    return Stack(
      children: [
        ...AppGradients.meshGlow(palette, AppPalette.brand),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildHero(palette, reduceMotion),
              SizedBox(height: 40.h),
              _buildStageLabel(palette, l10n, reduceMotion),
              SizedBox(height: 32.h),
              _buildProgressBar(palette),
              SizedBox(height: 12.h),
              _buildEta(palette, l10n),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero(AppPalette palette, bool reduceMotion) {
    if (_done) {
      return AnimatedBuilder(
        animation: _successCtrl,
        builder: (_, __) => Opacity(
          opacity: reduceMotion ? 1.0 : _successFade.value,
          child: Transform.scale(
            scale: reduceMotion ? 1.0 : _successScale.value,
            child: Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppPalette.brand, Color(0xFFFF4E50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.brand.withValues(alpha: 0.45),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 56.r),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: reduceMotion ? _progressCtrl : _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: reduceMotion ? 1.0 : _pulseAnim.value,
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurDefault,
            sigmaY: AppPalette.glassBlurDefault,
          ),
          child: Container(
            width: 120.r,
            height: 120.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.glassFill,
              border: Border.all(color: palette.glassStroke, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.brand.withValues(alpha: 0.25),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: AppPalette.brand,
                size: 52.r,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageLabel(
      AppPalette palette, AppLocalizations l10n, bool reduceMotion) {
    final titles = [
      l10n.translate('onboarding.generating.stage0'),
      l10n.translate('onboarding.generating.stage1'),
      l10n.translate('onboarding.generating.stage2'),
      l10n.translate('onboarding.generating.stage3'),
      l10n.translate('onboarding.generating.stage4'),
      l10n.translate('onboarding.generating.stage5'),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: Column(
        children: [
          Text(
            l10n.translate('onboarding.generating.heading'),
            style: AppText.of(context).titleL.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 24.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          AnimatedBuilder(
            animation: _stageCtrl,
            builder: (_, child) => Opacity(
              opacity: reduceMotion ? 1.0 : _stageFade.value,
              child: Transform.translate(
                offset: Offset(0, reduceMotion ? 0.0 : _stageSlide.value),
                child: child,
              ),
            ),
            child: Text(
              titles[_stage.clamp(0, 5)],
              style: AppText.of(context).bodyL.copyWith(
                    color: palette.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppPalette palette) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (_, __) {
          final pct = _progressAnim.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full.r),
                child: SizedBox(
                  height: 10.h,
                  child: Stack(
                    children: [
                      // Track background
                      Container(
                        width: double.infinity,
                        color: palette.surfaceVariant,
                      ),
                      // Gradient fill scaled to progress value
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _done
                                  ? [AppPalette.energyLight, AppPalette.brand]
                                  : [
                                      AppPalette.brand,
                                      const Color(0xFFFF4E50),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '${(pct * 100).round()}%',
                style: AppText.of(context).labelM.copyWith(
                      color: AppPalette.brand,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEta(AppPalette palette, AppLocalizations l10n) {
    return Text(
      l10n.translate('onboarding.generating.eta'),
      style: AppText.of(context).labelS.copyWith(color: palette.textTertiary),
    );
  }

  Widget _buildError(AppPalette palette, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppErrorState(
              title: l10n.translate('onboarding.generating.error_title'),
              message: l10n.translate('onboarding.generating.error_msg'),
              onRetry: _retry,
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: l10n.translate('onboarding.generating.skip'),
              onPressed: _skip,
              variant: AppButtonVariant.ghost,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
