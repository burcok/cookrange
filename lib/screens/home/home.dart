import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/models/user_model.dart';
import '../../core/models/dish_model.dart';
import '../../core/models/food_log_model.dart';
import '../../core/models/weekly_meal_plan_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/admin_status_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/repositories/meal_plan_repository.dart';
import '../../core/repositories/food_log_repository.dart';
import '../../core/repositories/dish_repository.dart';
import '../../core/services/analytics_service.dart';
import '../common/generic_error_screen.dart';
import '../recipe/recipe_detail_screen.dart';
import 'widgets/tracking_card.dart';
import 'food_scan_screen.dart';
import '../../core/widgets/ds/ds.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/main_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final MealPlanRepository _mealPlanRepo = MealPlanRepository();
  final FoodLogRepository _foodLogRepo = FoodLogRepository();
  final DishRepository _dishRepo = DishRepository();

  WeeklyMealPlanModel? _weeklyPlan;
  int _selectedDayIndex = 0;
  bool _isLoadingPlan = false;

  // Cache for dishes to avoid repeated fetches
  final Map<String, DishModel> _dishCache = {};
  DateTime? _lastRefreshTime;

  // Food logging state — real-time consumed nutrition
  NutritionTotals _consumed = NutritionTotals.zero;
  Set<String> _loggedMealTypes = {};
  StreamSubscription<List<FoodLog>>? _foodLogSubscription;
  final Map<String, bool> _loggingInProgress = {};

  TestModeProvider? _testModeProvider;

  // Swap state — tracks which meal slot is currently swapping
  final Map<String, bool> _swapInProgress = {};

  // Streak milestone banner — dismissed per session
  bool _streakMilestoneDismissed = false;

  // Custom Refresh State
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier(0.0);
  bool _isRefreshing = false;
  late AnimationController _refreshController;
  final double _refreshThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testModeProvider = context.read<TestModeProvider>();
      _testModeProvider!.addListener(_onTestModeChanged);
      _loadWeeklyPlan();
      _subscribeToFoodLogs();
    });
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  void _onTestModeChanged() {
    if (!mounted) return;
    _subscribeToFoodLogs();
    _loadWeeklyPlan();
  }

  void _subscribeToFoodLogs() {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return;
    _foodLogSubscription?.cancel();

    _foodLogSubscription = _foodLogRepo.todayLogsStream(uid).listen((logs) {
      if (!mounted) return;
      setState(() {
        _consumed = FoodLog.sumLogs(logs);
        _loggedMealTypes = logs.map((l) => l.mealType).toSet();
      });
    });
  }

  Future<void> _logMeal(
      String userId, String mealType, DishModel dish) async {
    if (_loggingInProgress[mealType] == true) return;
    setState(() => _loggingInProgress[mealType] = true);
    try {
      await _foodLogRepo.logMeal(
        userId: userId,
        mealType: mealType,
        dish: dish,
      );
      unawaited(AnalyticsService().logEvent(
        name: 'food_logged',
        parameters: {
          'meal_type': mealType,
          'dish_id': dish.id,
          'calories': dish.calories,
        },
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log meal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingInProgress.remove(mealType));
    }
  }

  Future<void> _showSwapSheet(
      AppLocalizations l10n, String mealType, int dayIndex) async {
    final userId = context.read<UserProvider>().user?.uid;
    if (userId == null) return;
    if (_weeklyPlan == null || dayIndex >= _weeklyPlan!.days.length) return;

    final alternatives = await _dishRepo.getByMealType(mealType);
    final currentDishId = _weeklyPlan!.days[dayIndex].meals[mealType];
    final choices =
        alternatives.where((d) => d.id != currentDishId).toList();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SwapSheet(
        mealType: mealType,
        dishes: choices,
        l10n: l10n,
        onSelect: (dish) async {
          Navigator.of(ctx).pop();
          await _performSwap(
              userId: userId,
              dayIndex: dayIndex,
              mealType: mealType,
              newDish: dish);
        },
      ),
    );
  }

  Future<void> _performSwap({
    required String userId,
    required int dayIndex,
    required String mealType,
    required DishModel newDish,
  }) async {
    final key = '${dayIndex}_$mealType';
    if (_swapInProgress[key] == true) return;
    setState(() => _swapInProgress[key] = true);
    try {
      final day = _weeklyPlan!.days[dayIndex];
      final updated = await _mealPlanRepo.swapMeal(
        userId: userId,
        dayDate: day.date,
        mealType: mealType,
        newDishId: newDish.id,
      );
      if (!mounted) return;
      if (updated != null) {
        _dishCache[newDish.id] = newDish;
        setState(() => _weeklyPlan = updated);
      }
      unawaited(AnalyticsService().logEvent(
        name: 'meal_swapped',
        parameters: {'meal_type': mealType, 'new_dish_id': newDish.id},
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not swap meal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _swapInProgress.remove(key));
    }
  }

  @override
  void dispose() {
    _testModeProvider?.removeListener(_onTestModeChanged);
    _foodLogSubscription?.cancel();
    _refreshController.dispose();
    _pullDistanceNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyPlan() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoadingPlan = true);

    try {
      final plan = await _mealPlanRepo.getWeeklyPlan(user);
      if (plan != null) {
        final allDishIds = plan.days.expand((d) => d.meals.values).toSet();
        await _fetchDishes(allDishIds.toList());

        final now = DateTime.now();
        int initialIndex = plan.days.indexWhere((d) =>
            d.date.year == now.year &&
            d.date.month == now.month &&
            d.date.day == now.day);

        if (initialIndex == -1) initialIndex = 0;

        if (mounted) {
          setState(() {
            _dishCache.addAll(_dishRepo.snapshot);
            _weeklyPlan = plan;
            _selectedDayIndex = initialIndex;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  Future<void> _fetchDishes(List<String> ids) async {
    await _dishRepo.prefetch(ids);
  }

  Future<void> _generateWeeklyPlan(UserModel user) async {
    setState(() => _isLoadingPlan = true);
    unawaited(AnalyticsService().logEvent(name: 'ai_meal_plan_started'));
    try {
      final plan = await _mealPlanRepo.getWeeklyPlan(user, forceRefresh: true);
      if (plan != null) {
        unawaited(AnalyticsService().logEvent(
          name: 'ai_meal_plan_generated',
          parameters: {'days': plan.days.length},
        ));
        final allDishIds = plan.days.expand((d) => d.meals.values).toSet();
        await _fetchDishes(allDishIds.toList());
        if (mounted) {
          setState(() {
            _dishCache.addAll(_dishRepo.snapshot);
            _weeklyPlan = plan;
            _selectedDayIndex = 0;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
      if (mounted) await context.read<UserProvider>().refreshUser();
    }
  }

  Future<void> _onRefresh() async {
    final now = DateTime.now();

    // Safety check: if we are already refreshing, don't start another one
    // But if we hit the rate limit, we still need to reset the UI state
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inSeconds < 2) {
      _resetRefreshState();
      return;
    }

    _lastRefreshTime = now;

    // Add a safety timeout to ensure the refreshing state always clears
    bool timedOut = false;
    Future.delayed(const Duration(seconds: 10), () {
      if (_isRefreshing) {
        timedOut = true;
        _resetRefreshState();
      }
    });

    final userProvider = context.read<UserProvider>();
    try {
      final userId = userProvider.user?.uid;
      if (userId != null) {
        await AdminStatusService()
            .checkStatus(userId)
            .then((status) {
          if (status == AdminStatus.banned) {
            AdminStatusService().notifyBanned(userId);
          }
        });
      }

      await Future.wait([
        _loadWeeklyPlan(),
        userProvider.refreshUser(),
      ]);
    } finally {
      if (!timedOut) {
        _resetRefreshState();
      }
    }
  }

  void _resetRefreshState() {
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      _pullDistanceNotifier.value = 0.0;
      _refreshController.stop();
    }
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        // Implement dampened resistance for pulling
        // The further we pull, the harder it gets
        final rawPull = notification.metrics.pixels.abs();

        // Use a nonlinear transformation for pull distance
        // This provides more resistance as the user pulls further
        double dampenedPull;
        if (rawPull <= _refreshThreshold) {
          dampenedPull = rawPull;
        } else {
          // Beyond threshold, pull grows logarithmically
          dampenedPull = _refreshThreshold +
              (math.log(1 + (rawPull - _refreshThreshold) / 100) * 50);
        }

        _pullDistanceNotifier.value = dampenedPull;
      } else if (_pullDistanceNotifier.value != 0) {
        _pullDistanceNotifier.value = 0;
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullDistanceNotifier.value >= _refreshThreshold) {
        _startRefresh();
      } else {
        _pullDistanceNotifier.value = 0;
      }
    }
  }

  void _startRefresh() {
    setState(() {
      _isRefreshing = true;
    });
    _pullDistanceNotifier.value = _refreshThreshold;
    _refreshController.repeat();
    _onRefresh();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final userProvider = context.watch<UserProvider>();

    // Critical Error: No user data and not loading
    if (!userProvider.isLoading && userProvider.user == null) {
      return GenericErrorScreen(
        errorCode: 'HM-USER-NULL',
        onRetry: () => userProvider.refreshUser(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ...AppGradients.meshGlow(
            AppPalette.of(context),
            context.watch<ThemeProvider>().primaryColor,
          ),
          _buildMinimalGlassRefresh(context),
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleScrollNotification(notification);
              return false;
            },
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                  26.w, MediaQuery.of(context).padding.top + 24, 26.w, 120.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MainHeader(),
                  SizedBox(height: 32.h),
                  if (userProvider.isLoading && userProvider.user == null)
                    const AppSkeletonList()
                  else if (userProvider.user != null)
                    _buildHomeContent(context, userProvider.user!, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalGlassRefresh(BuildContext context) {
    return Positioned(
      top: 50.h,
      left: 0,
      right: 0,
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: _pullDistanceNotifier,
          builder: (context, pullDistance, child) {
            final double progress =
                (pullDistance / _refreshThreshold).clamp(0.0, 1.0);
            final double opacity = progress.clamp(0.0, 1.0);
            final double scale = 0.5 + (progress * 0.5);

            return Opacity(
              opacity: opacity,
              child: AnimatedBuilder(
                animation: _refreshController,
                builder: (context, child) {
                  final pulse = _isRefreshing
                      ? (math.sin(_refreshController.value * math.pi * 2) *
                          0.05)
                      : 0.0;
                  final currentScale = scale + pulse;
                  final rotation = _isRefreshing
                      ? _refreshController.value * 2 * math.pi
                      : progress * math.pi;

                  return Container(
                    width: 48.w,
                    height: 48.w,
                    transform: Matrix4.diagonal3Values(
                        currentScale, currentScale, 1.0),
                    transformAlignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(48.w, 48.w),
                          painter: _RefreshRingPainter(
                            progress: _isRefreshing ? 0.3 : progress,
                            rotation: rotation,
                            color: context.watch<ThemeProvider>().primaryColor,
                          ),
                        ),
                        Transform.rotate(
                          angle: rotation,
                          child: Icon(
                            Icons.refresh_rounded,
                            color: context.watch<ThemeProvider>().primaryColor,
                            size: 22.w,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeContent(
      BuildContext context, UserModel userModel, AppLocalizations l10n) {
    final onboardingData = userModel.onboardingData ?? {};
    final personalInfo = onboardingData.containsKey('personal_info') &&
            onboardingData['personal_info'] is Map
        ? onboardingData['personal_info'] as Map<String, dynamic>
        : onboardingData;

    final height = (personalInfo['height'] as num?)?.toDouble() ?? 170.0;
    final weight = (personalInfo['weight'] as num?)?.toDouble() ?? 70.0;

    final birthDateStr = personalInfo['birth_date'] as String?;
    final birthDate = birthDateStr != null
        ? DateTime.tryParse(birthDateStr) ??
            DateTime.now().subtract(const Duration(days: 365 * 30))
        : DateTime.now().subtract(const Duration(days: 365 * 30));

    final gender = personalInfo['gender'] as String? ?? 'Male';

    // Handle both old (Map) and new (String/ID) formats for activity_level
    final activityLevelRaw = onboardingData['activity_level'];
    final activityLevel = activityLevelRaw is Map
        ? (activityLevelRaw['value'] as String? ?? 'sedentary')
        : (activityLevelRaw as String? ?? 'sedentary');

    // Handle both old (List<Map>) and new (List<String/ID>) formats for primary_goals
    final primaryGoalsRaw = onboardingData['primary_goals'] as List<dynamic>?;
    String primaryGoal = 'maintain_weight';
    if (primaryGoalsRaw != null && primaryGoalsRaw.isNotEmpty) {
      final firstGoal = primaryGoalsRaw.first;
      primaryGoal = firstGoal is Map
          ? (firstGoal['value'] as String? ?? 'maintain_weight')
          : (firstGoal as String? ?? 'maintain_weight');
    }

    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    final bmr = CalorieCalculator.calculateBMR(
        weight: weight, height: height, age: age, gender: gender);
    final tdee =
        CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: activityLevel);
    final adjustedTDEE = CalorieCalculator.adjustTDEEForGoal(
        tdee: tdee, primaryGoal: primaryGoal);
    final macros = CalorieCalculator.calculateMacros(adjustedTDEE);

    final streak =
        (userModel.onboardingData?['streak'] as num?)?.toInt() ?? 0;
    final goalMet = adjustedTDEE > 0 &&
        _consumed.calories >= adjustedTDEE * 0.85;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeHeader(context, userModel, l10n, streak: streak),
        if (!_streakMilestoneDismissed &&
            const [7, 14, 30, 60, 100, 365].contains(streak)) ...[
          SizedBox(height: 12.h),
          _buildStreakMilestoneBanner(context, streak, l10n),
        ],
        SizedBox(height: 32.h),
        Text(
          l10n.translate('home.nutrition_title'),
          style: AppText.of(context).headlineM,
        ),
        SizedBox(height: 16.h),
        _buildNutritionHero(context, adjustedTDEE, macros, l10n),
        SizedBox(height: 10.h),
        _buildScanFoodButton(context, l10n),
        if (goalMet) ...[
          SizedBox(height: 12.h),
          _buildGoalMetBanner(context, l10n),
        ],
        SizedBox(height: 24.h),
        const TrackingCard(),
        SizedBox(height: 32.h),
        _buildMealPlanSection(context, userModel, l10n),
        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _buildWelcomeHeader(
      BuildContext context, UserModel userModel, AppLocalizations l10n,
      {int streak = 0}) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final displayName = userModel.displayName?.split(' ').first ??
        (userModel.email?.split('@').first) ??
        'User';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.translate('home.good_morning')
        : hour < 18
            ? l10n.translate('home.good_afternoon')
            : l10n.translate('home.good_evening');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: t.titleM.copyWith(color: palette.textSecondary),
              ),
              SizedBox(height: AppSpacing.xs.h),
              RichText(
                text: TextSpan(
                  style: t.displayM.copyWith(color: palette.textPrimary),
                  children: [
                    TextSpan(text: l10n.translate('home.hello')),
                    TextSpan(
                      text: '$displayName!',
                      style: TextStyle(color: primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (streak > 0)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: EdgeInsets.only(top: AppSpacing.xxs.h),
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full.r),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 15)),
                SizedBox(width: AppSpacing.xxs.w),
                Text(
                  l10n.translate('home.streak_days',
                      variables: {'count': '$streak'}),
                  style: t.labelM
                      .copyWith(fontWeight: FontWeight.bold, color: primary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGoalMetBanner(BuildContext context, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: palette.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 20)),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('home.goal_met'),
                  style: t.labelL.copyWith(
                      fontWeight: FontWeight.bold, color: palette.success),
                ),
                Text(
                  l10n.translate('home.goal_met_sub'),
                  style: t.labelS.copyWith(
                      color: palette.success.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMilestoneBanner(BuildContext context, int streak,
      AppLocalizations l10n) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('home.streak_milestone_title',
                      variables: {'count': '$streak'}),
                  style: t.labelL
                      .copyWith(fontWeight: FontWeight.bold, color: primary),
                ),
                Text(
                  l10n.translate('home.streak_milestone_subtitle',
                      variables: {'count': '$streak'}),
                  style: t.labelS
                      .copyWith(color: primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _streakMilestoneDismissed = true),
            child: Icon(Icons.close_rounded, size: 18, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFoodButton(BuildContext context, AppLocalizations l10n) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return AppButton(
      label: l10n.translate('food_scan.scan_btn'),
      icon: Icons.auto_awesome,
      variant: AppButtonVariant.tonal,
      size: AppButtonSize.medium,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final successText = l10n.translate('food_scan.log_success');
        final logged = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const FoodScanScreen()),
        );
        if (logged == true && mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(successText), backgroundColor: primary),
          );
        }
      },
    );
  }

  /// Bold "Sunset Energy" nutrition hero — animated gradient calorie ring +
  /// animated macro bars on a brand-washed surface. Design-system centerpiece.
  Widget _buildNutritionHero(BuildContext context, double targetCalories,
      Map<String, double> macros, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final targetCalInt = targetCalories.toInt();

    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.r),
      decoration: BoxDecoration(
        gradient: AppGradients.brandSoft(primary, dark: palette.isDark),
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: palette.isDark ? 0.18 : 0.12),
            blurRadius: AppElevation.blurLg.r,
            offset: AppElevation.offsetLg,
          ),
        ],
      ),
      child: Column(
        children: [
          AppCalorieRing(
            consumed: _consumed.calories,
            target: targetCalories,
            size: 188,
            caption: l10n.translate('home.kcal',
                variables: {'target': targetCalInt.toString()}),
          ),
          SizedBox(height: AppSpacing.xl.h),
          Row(
            children: [
              Expanded(
                child: _macroBar(
                    l10n.translate('home.macros.protein'),
                    _consumed.protein,
                    macros['protein'] ?? 0.0,
                    palette.protein,
                    t,
                    palette),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _macroBar(
                    l10n.translate('home.macros.carbs'),
                    _consumed.carbs,
                    macros['carbs'] ?? 0.0,
                    palette.carbs,
                    t,
                    palette),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: _macroBar(
                    l10n.translate('home.macros.fat'),
                    _consumed.fat,
                    macros['fat'] ?? 0.0,
                    palette.fat,
                    t,
                    palette),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double consumed, double target, Color color,
      AppText t, AppPalette palette) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: AppSpacing.xs.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: AppMotion.slow,
            curve: AppMotion.standard,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6.h,
              backgroundColor: palette.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('${consumed.toInt()} / ${target.toInt()}g',
              style: t.labelS),
        ),
      ],
    );
  }

  Widget _buildMealPlanSection(
      BuildContext context, UserModel user, AppLocalizations l10n) {
    if (_isLoadingPlan) {
      return const AppSkeletonList(itemCount: 5);
    }

    if (_weeklyPlan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, l10n),
          SizedBox(height: 16.h),
          _buildEmptyPlanState(context, user, l10n),
        ],
      );
    }

    final currentDay = _weeklyPlan!.days[_selectedDayIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, l10n, showRegenerate: true, user: user),
        SizedBox(height: 16.h),
        // Day Selector
        SizedBox(
          height: 80.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _weeklyPlan!.days.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final day = _weeklyPlan!.days[index];
              final isSelected = index == _selectedDayIndex;
              // Format date: "Mon", "12"
              final dayNameShort = DateFormat('E').format(day.date);
              final dayNum = DateFormat('d').format(day.date);

              final palette = AppPalette.of(context);
              final t = AppText.of(context);
              final primary = context.watch<ThemeProvider>().primaryColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = index),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 60.w,
                  decoration: BoxDecoration(
                    color: isSelected ? primary : palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg.r),
                    border: isSelected
                        ? null
                        : Border.all(color: palette.border),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.3),
                              blurRadius: AppElevation.blurMd.r,
                              offset: AppElevation.offsetMd,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNameShort,
                        style: t.labelM.copyWith(
                          color: isSelected
                              ? Colors.white
                              : palette.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xxs.h),
                      Text(
                        dayNum,
                        style: t.titleL.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24.h),
        // Meals List
        ..._buildMealsList(l10n, currentDay),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n,
      {bool showRegenerate = false, UserModel? user}) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.translate('home.meal_plan_title'),
          style: t.headlineL.copyWith(color: palette.textPrimary),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.nutritionAnalytics),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: AppSize.iconSm, color: primary),
                    SizedBox(width: AppSpacing.xxs.w),
                    Text(
                      l10n.translate('home.analytics_btn'),
                      style: t.labelM.copyWith(
                          fontWeight: FontWeight.w600, color: primary),
                    ),
                  ],
                ),
              ),
            ),
            if (showRegenerate && user != null) ...[
              SizedBox(width: AppSpacing.xxs.w),
              TextButton.icon(
                onPressed: () => _generateWeeklyPlan(user),
                icon: Icon(Icons.refresh_rounded,
                    size: AppSize.iconSm, color: primary),
                label: Text(
                  l10n.translate('home.regenerate'),
                  style: t.labelL
                      .copyWith(fontWeight: FontWeight.bold, color: primary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyPlanState(
      BuildContext context, UserModel user, AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.restaurant_outlined,
      title: l10n.translate('home.no_meal_plan'),
      actionLabel: l10n.translate('home.generate_plan'),
      onAction: () => _generateWeeklyPlan(user),
    );
  }

  List<Widget> _buildMealsList(AppLocalizations l10n, DayMealPlan day) {
    final mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
    final userId = context.read<UserProvider>().user?.uid;
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;

    return mealOrder.map((mealType) {
      if (!day.meals.containsKey(mealType)) return const SizedBox.shrink();

      final dishId = day.meals[mealType]!;
      final dish = _dishCache[dishId];

      if (dish == null) {
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md.h),
          child: AppSkeletonBox(height: 90.h),
        );
      }

      final isLogged = _loggedMealTypes.contains(mealType);
      final isLoggingNow = _loggingInProgress[mealType] == true;
      final swapKey = '${_selectedDayIndex}_$mealType';
      final isSwapping = _swapInProgress[swapKey] == true;

      final palette = AppPalette.of(context);
      final t = AppText.of(context);
      final primary = context.watch<ThemeProvider>().primaryColor;
      final mealLabel = l10n.translate('home.meal_type_$mealType');
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    RecipeDetailScreen(recipe: dish.toRecipe())),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.md.h),
              padding: EdgeInsets.all(AppSpacing.md.r),
              decoration: BoxDecoration(
                color: palette.surface.withValues(
                    alpha: palette.isDark ? 0.65 : 0.82),
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: AppElevation.blurMd.r,
                    offset: AppElevation.offsetSm,
                  ),
                ],
                border: Border.all(
                    color: palette.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 90.w,
                    height: 90.w,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg.r),
                          child: SizedBox(
                            width: 90.w,
                            height: 90.w,
                            child: dish.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: dish.imageUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    memCacheHeight: 200,
                                    placeholder: (context, url) =>
                                        AppSkeletonBox(
                                            height: 90.w, width: 90.w),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: palette.surfaceVariant,
                                          child: Icon(Icons.restaurant_rounded,
                                              color: primary
                                                  .withValues(alpha: 0.5),
                                              size: AppSize.iconLg.w),
                                        ),
                                  )
                                : Container(
                                    color: palette.surfaceVariant,
                                    child: Icon(Icons.restaurant_rounded,
                                        color: primary.withValues(alpha: 0.35),
                                        size: AppSize.iconLg.w),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 4.h,
                          right: 4.w,
                          child: GestureDetector(
                            onTap: isSwapping
                                ? null
                                : () => _showSwapSheet(
                                    l10n, mealType, _selectedDayIndex),
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              width: 26.w,
                              height: 26.w,
                              decoration: BoxDecoration(
                                color: palette.scrim,
                                shape: BoxShape.circle,
                              ),
                              child: isSwapping
                                  ? Padding(
                                      padding: EdgeInsets.all(5.r),
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Icon(Icons.swap_horiz_rounded,
                                      color: Colors.white,
                                      size: AppSize.iconXs.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealLabel.isEmpty ? mealType : mealLabel,
                          style: t.labelM.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          dish.name,
                          style: t.titleL.copyWith(
                              fontWeight: FontWeight.bold,
                              color: palette.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Row(
                          children: [
                            Text(
                              l10n.translate('home.calories_suffix',
                                  variables: {
                                    'count': dish.calories.toInt().toString()
                                  }),
                              style: t.bodyM.copyWith(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                            SizedBox(width: AppSpacing.sm.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs.w,
                                  vertical: 2.h),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs.r),
                              ),
                              child: Text(
                                '${dish.protein.toInt()}g P',
                                style: t.labelS.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (userId != null && isToday)
                    Padding(
                      padding: EdgeInsets.only(left: AppSpacing.xs.w),
                      child: isLoggingNow
                          ? SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : GestureDetector(
                              onTap: isLogged
                                  ? null
                                  : () => _logMeal(userId, mealType, dish),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                width: 32.w,
                                height: 32.w,
                                decoration: BoxDecoration(
                                  color: isLogged
                                      ? primary
                                      : palette.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isLogged
                                      ? Icons.check_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: AppSize.iconSm.sp,
                                  color: isLogged
                                      ? Colors.white
                                      : palette.textTertiary,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ── Swap bottom sheet ───────────────────────────────────────────────────────

class _SwapSheet extends StatelessWidget {
  final String mealType;
  final List<DishModel> dishes;
  final AppLocalizations l10n;
  final void Function(DishModel) onSelect;

  const _SwapSheet({
    required this.mealType,
    required this.dishes,
    required this.l10n,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(AppRadius.full.r),
              ),
            ),
          ),
          // Title row
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded,
                    color: primary, size: AppSize.iconMd),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('home.swap_meal_title'),
                        style: t.titleL.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary),
                      ),
                      Text(
                        l10n.translate('home.swap_meal_subtitle'),
                        style: t.labelS
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Divider(
              indent: AppSpacing.xl.w,
              endIndent: AppSpacing.xl.w,
              color: palette.divider),
          // Dish list
          dishes.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl.r),
                  child: Text(
                    l10n.translate('home.no_alternatives'),
                    style: t.bodyM
                        .copyWith(color: palette.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.xs.h),
                    itemCount: dishes.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: AppSpacing.xs.h),
                    itemBuilder: (context, i) {
                      final dish = dishes[i];
                      return AppCard(
                        onTap: () => onSelect(dish),
                        padding: EdgeInsets.all(AppSpacing.sm.r),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm.r),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: dish.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: dish.imageUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 120,
                                        errorWidget: (_, __, ___) =>
                                            Container(
                                              color: palette.surfaceVariant,
                                              child: Icon(
                                                  Icons.restaurant_rounded,
                                                  color: primary.withValues(
                                                      alpha: 0.4)),
                                            ),
                                      )
                                    : Container(
                                        color: palette.surfaceVariant,
                                        child: Icon(
                                            Icons.restaurant_rounded,
                                            color: primary
                                                .withValues(alpha: 0.4)),
                                      ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dish.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleM.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${dish.calories.toInt()} kcal · ${dish.protein.toInt()}g P',
                                    style: t.labelS.copyWith(
                                        color: palette.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color: primary.withValues(alpha: 0.7)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          SizedBox(height: AppSpacing.md.h),
        ],
      ),
    );
  }
}

class _RefreshRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final Color color;

  _RefreshRingPainter({
    required this.progress,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + rotation,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RefreshRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.rotation != rotation;
  }
}
