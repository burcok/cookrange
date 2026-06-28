import 'dart:async';
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
import '../../core/services/permission_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/repositories/meal_plan_repository.dart';
import '../../core/repositories/food_log_repository.dart';
import '../../core/repositories/dish_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/widgets/shareable_fitness_card.dart';
import '../common/generic_error_screen.dart';
import '../recipe/recipe_detail_screen.dart';
import 'widgets/tracking_card.dart';
import 'widgets/ai_insight_card.dart';
import 'widgets/role_quick_card.dart';
import 'widgets/meal_breakdown_card.dart';
import 'widgets/exercise_log_sheet.dart';
import 'widgets/meal_plan_comparison_sheet.dart';
import 'food_scan_screen.dart';
import '../../core/models/exercise_log_model.dart';
import '../../core/services/exercise_log_service.dart';
import '../../core/services/meal_plan_calendar_service.dart';
import '../../core/widgets/ds/ds.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/widgets/main_header.dart';
import 'nutrition_analytics_screen.dart';
import 'meal_plan_history_screen.dart';

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
  Map<String, NutritionTotals> _mealBreakdown = {};
  StreamSubscription<List<FoodLog>>? _foodLogSubscription;
  final Map<String, bool> _loggingInProgress = {};

  // Exercise logging state
  double _burnedCalories = 0;
  StreamSubscription<List<ExerciseLog>>? _exerciseSubscription;

  TestModeProvider? _testModeProvider;

  // Swap state — tracks which meal slot is currently swapping
  final Map<String, bool> _swapInProgress = {};

  // Streak milestone banner — dismissed per session
  bool _streakMilestoneDismissed = false;

  // Shareable card capture key
  final _shareCardKey = GlobalKey();

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
      // Notification primer — shown once, 3s after home loads so it doesn't
      // compete with the initial loading experience.
      Future.delayed(const Duration(seconds: 3), _maybeRequestNotifications);
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

  Future<void> _maybeRequestNotifications() async {
    if (!mounted) return;
    await PermissionService().requestNotifications(context);
  }

  void _subscribeToFoodLogs() {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return;
    _foodLogSubscription?.cancel();
    _exerciseSubscription?.cancel();

    _foodLogSubscription = _foodLogRepo.todayLogsStream(uid).listen((logs) {
      if (!mounted) return;
      setState(() {
        _consumed = FoodLog.sumLogs(logs);
        _loggedMealTypes = logs.map((l) => l.mealType).toSet();
        _mealBreakdown = _computeBreakdown(logs);
      });
    });

    _exerciseSubscription = ExerciseLogService().todayLogsStream(uid).listen((logs) {
      if (!mounted) return;
      setState(() => _burnedCalories = ExerciseLog.totalBurned(logs));
    });
  }

  Map<String, NutritionTotals> _computeBreakdown(List<FoodLog> logs) {
    final grouped = <String, List<FoodLog>>{};
    for (final l in logs) {
      grouped.putIfAbsent(l.mealType, () => []).add(l);
    }
    return grouped.map((k, v) => MapEntry(k, FoodLog.sumLogs(v)));
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
      if (mounted) AppSnackBar.error(context, 'Could not log meal: $e');
    } finally {
      if (mounted) setState(() => _loggingInProgress.remove(mealType));
    }
  }

  void _showShareCard(
    BuildContext context,
    AppLocalizations l10n,
    double target,
    Map<String, double> macros,
    int streak,
    String? displayName,
  ) {
    AppSheet.show(
      context: context,
      title: l10n.translate('home.share_progress'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShareableFitnessCard(
            repaintKey: _shareCardKey,
            consumedCalories: _consumed.calories,
            targetCalories: target,
            streakDays: streak,
            userName: displayName,
            protein: _consumed.protein,
            carbs: _consumed.carbs,
            fat: _consumed.fat,
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppButton(
            label: l10n.translate('home.share_progress'),
            icon: Icons.share_outlined,
            onPressed: () => ShareableFitnessCard.capture(
              _shareCardKey,
              text: 'Tracking my nutrition with Cookrange AI! #Cookrange',
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
        ],
      ),
    );
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
      if (mounted) AppSnackBar.error(context, 'Could not swap meal: $e');
    } finally {
      if (mounted) setState(() => _swapInProgress.remove(key));
    }
  }

  @override
  void dispose() {
    _testModeProvider?.removeListener(_onTestModeChanged);
    _foodLogSubscription?.cancel();
    _exerciseSubscription?.cancel();
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

  Future<void> _exportPlanToCalendar(AppLocalizations l10n) async {
    final plan = _weeklyPlan;
    if (plan == null) return;

    final dishNameMap = _dishCache.map((id, dish) => MapEntry(id, dish.name));
    final mealTypeLabels = {
      'breakfast': l10n.translate('food_scan.meal.breakfast'),
      'lunch': l10n.translate('food_scan.meal.lunch'),
      'dinner': l10n.translate('food_scan.meal.dinner'),
      'snack': l10n.translate('food_scan.meal.snack'),
    };

    try {
      await MealPlanCalendarService().exportToCalendar(
        plan: plan,
        dishNames: dishNameMap,
        mealTypeLabels: mealTypeLabels,
      );
    } catch (e) {
      if (mounted) AppSnackBar.error(context, l10n.translate('calendar.export_error'));
    }
  }

  Future<void> _generateWeeklyPlan(UserModel user, {bool forceRefresh = true}) async {
    setState(() => _isLoadingPlan = true);
    unawaited(AnalyticsService().logEvent(name: 'ai_meal_plan_started'));
    try {
      final plan = await _mealPlanRepo.getWeeklyPlan(user, forceRefresh: forceRefresh);
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
        Row(
          children: [
            Text(
              l10n.translate('home.nutrition_title'),
              style: AppText.of(context).headlineM,
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.share_outlined,
                  color: AppPalette.of(context).textSecondary, size: 20.r),
              onPressed: () => _showShareCard(
                context,
                l10n,
                adjustedTDEE,
                macros,
                streak,
                userModel.displayName,
              ),
              tooltip: l10n.translate('home.share_progress'),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildNutritionHero(context, adjustedTDEE, macros, l10n),
        SizedBox(height: 10.h),
        _buildScanFoodButton(context, l10n),
        if (goalMet) ...[
          SizedBox(height: 12.h),
          _buildGoalMetBanner(context, l10n),
        ],
        if (_mealBreakdown.isNotEmpty) ...[
          SizedBox(height: 16.h),
          MealBreakdownCard(breakdown: _mealBreakdown),
        ],
        SizedBox(height: 24.h),
        const TrackingCard(),
        if (userModel.userRole != UserRole.consumer) ...[
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: RoleQuickCard(user: userModel),
          ),
        ],
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: AiInsightCard(user: userModel),
        ),
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
                if (userModel.streakFreezeCount > 0) ...[
                  SizedBox(width: AppSpacing.xs.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.xs.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ac_unit_rounded,
                            size: 10.sp, color: Colors.blue),
                        SizedBox(width: 2.w),
                        Text(
                          '${userModel.streakFreezeCount}',
                          style: t.labelS.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
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
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.translate('food_scan.scan_btn'),
            icon: Icons.auto_awesome,
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.medium,
            onPressed: () async {
              final successText = l10n.translate('food_scan.log_success');
              final logged = await Navigator.of(context, rootNavigator: true)
                  .push<bool>(AppTransitions.slideUp(const FoodScanScreen()));
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              if (logged == true) AppSnackBar.success(context, successText);
            },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: AppButton(
            label: l10n.translate('exercise.log_button_short'),
            icon: Icons.fitness_center_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            onPressed: () async {
              await ExerciseLogSheet.show(context);
            },
          ),
        ),
      ],
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
          RepaintBoundary(
            child: AppCalorieRing(
              consumed: _consumed.calories,
              target: targetCalories,
              size: 188,
              caption: l10n.translate('home.kcal',
                  variables: {'target': targetCalInt.toString()}),
            ),
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
          if (_burnedCalories > 0) ...[
            SizedBox(height: AppSpacing.md.h),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.button.r),
                border: Border.all(
                    color: palette.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_rounded,
                      size: 14.sp, color: palette.success),
                  SizedBox(width: 6.w),
                  Text(
                    l10n.translate('exercise.burned_today',
                        variables: {
                          'kcal': _burnedCalories.toInt().toString()
                        }),
                    style: t.labelM.copyWith(
                        color: palette.success,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
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
      children: [
        Expanded(
          child: Text(
            l10n.translate('home.meal_plan_title'),
            style: t.headlineL.copyWith(color: palette.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Analytics — primary action, always visible
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const NutritionAnalyticsScreen())),
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_rounded,
                size: AppSize.iconSm, color: primary),
          ),
        ),

        SizedBox(width: AppSpacing.xs.w),

        // Overflow menu — keeps the header tidy regardless of plan state
        _MealHeaderMenu(
          l10n: l10n,
          primary: primary,
          palette: palette,
          showRegenerate: showRegenerate,
          user: user,
          onHistory: () async {
            final reloaded = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                    builder: (_) => const MealPlanHistoryScreen()));
            if (reloaded == true && user != null) {
              unawaited(_generateWeeklyPlan(user, forceRefresh: false));
            }
          },
          onCompare: showRegenerate && user != null
              ? () => unawaited(MealPlanComparisonSheet.show(
                    context,
                    user: user,
                    currentPlan: _weeklyPlan!,
                    onApplyAlternate: () => _generateWeeklyPlan(user),
                  ))
              : null,
          onCalendar: showRegenerate
              ? () => unawaited(_exportPlanToCalendar(l10n))
              : null,
          onRegenerate:
              showRegenerate && user != null ? () => _generateWeeklyPlan(user) : null,
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
      return RepaintBoundary(
        child: _MealCard(
        key: ValueKey('meal_${_selectedDayIndex}_$mealType'),
        dish: dish,
        mealLabel: mealLabel.isEmpty ? mealType : mealLabel,
        isLogged: isLogged,
        isLoggingNow: isLoggingNow,
        isSwapping: isSwapping,
        isToday: isToday,
        userId: userId,
        palette: palette,
        t: t,
        primary: primary,
        l10n: l10n,
        onTap: () => Navigator.push(
          context,
          AppTransitions.slideUp(RecipeDetailScreen(recipe: dish.toRecipe())),
        ),
        onLog: () => _logMeal(userId!, mealType, dish),
        onSwap: () => _showSwapSheet(l10n, mealType, _selectedDayIndex),
        ),
      );
    }).toList();
  }
}

// ── Meal section overflow menu ───────────────────────────────────────────────

class _MealHeaderMenu extends StatelessWidget {
  final AppLocalizations l10n;
  final Color primary;
  final AppPalette palette;
  final bool showRegenerate;
  final UserModel? user;
  final VoidCallback onHistory;
  final VoidCallback? onCompare;
  final VoidCallback? onCalendar;
  final VoidCallback? onRegenerate;

  const _MealHeaderMenu({
    required this.l10n,
    required this.primary,
    required this.palette,
    required this.showRegenerate,
    required this.user,
    required this.onHistory,
    this.onCompare,
    this.onCalendar,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MealAction>(
      onSelected: (action) {
        switch (action) {
          case _MealAction.history:
            onHistory();
          case _MealAction.compare:
            onCompare?.call();
          case _MealAction.calendar:
            onCalendar?.call();
          case _MealAction.regenerate:
            onRegenerate?.call();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: palette.surface,
      elevation: 4,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz_rounded, size: 20, color: primary),
      ),
      itemBuilder: (_) => [
        _menuItem(_MealAction.history, Icons.history_rounded,
            l10n.translate('meal_history.title')),
        if (showRegenerate) ...[
          _menuItem(_MealAction.compare, Icons.compare_arrows_rounded,
              l10n.translate('meal_compare.title')),
          _menuItem(_MealAction.calendar, Icons.calendar_month_rounded,
              l10n.translate('calendar.export_btn')),
          _menuItem(_MealAction.regenerate, Icons.refresh_rounded,
              l10n.translate('home.regenerate')),
        ],
      ],
    );
  }

  PopupMenuItem<_MealAction> _menuItem(
      _MealAction action, IconData icon, String label) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MealAction { history, compare, calendar, regenerate }

// ── Meal card ───────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final DishModel dish;
  final String mealLabel;
  final bool isLogged;
  final bool isLoggingNow;
  final bool isSwapping;
  final bool isToday;
  final String? userId;
  final AppPalette palette;
  final AppText t;
  final Color primary;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onLog;
  final VoidCallback onSwap;

  const _MealCard({
    super.key,
    required this.dish,
    required this.mealLabel,
    required this.isLogged,
    required this.isLoggingNow,
    required this.isSwapping,
    required this.isToday,
    required this.userId,
    required this.palette,
    required this.t,
    required this.primary,
    required this.l10n,
    required this.onTap,
    required this.onLog,
    required this.onSwap,
  });

  Widget _macroChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(label,
          style: t.labelS.copyWith(
              color: color, fontWeight: FontWeight.bold, fontSize: 10.sp)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            color: isLogged
                ? primary.withValues(alpha: 0.06)
                : palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: isLogged
                  ? primary.withValues(alpha: 0.3)
                  : palette.border.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.07),
                blurRadius: 12.r,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card.r),
                  bottomLeft: Radius.circular(AppRadius.card.r),
                ),
                child: SizedBox(
                  width: 100.w,
                  height: 110.h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      dish.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: dish.imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 220,
                              memCacheHeight: 220,
                              placeholder: (_, __) =>
                                  AppSkeletonBox(height: 110.h, width: 100.w),
                              errorWidget: (_, __, ___) => Container(
                                color: palette.surfaceVariant,
                                child: Icon(Icons.restaurant_rounded,
                                    color: primary.withValues(alpha: 0.4),
                                    size: 32.r),
                              ),
                            )
                          : Container(
                              color: palette.surfaceVariant,
                              child: Icon(Icons.restaurant_rounded,
                                  color: primary.withValues(alpha: 0.35),
                                  size: 32.r),
                            ),
                      // Swap button overlay
                      Positioned(
                        bottom: 6.h,
                        right: 6.w,
                        child: GestureDetector(
                          onTap: isSwapping ? null : onSwap,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: palette.scrim,
                              shape: BoxShape.circle,
                            ),
                            child: isSwapping
                                ? Padding(
                                    padding: EdgeInsets.all(6.r),
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(Icons.swap_horiz_rounded,
                                    color: Colors.white, size: 15.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w,
                      vertical: AppSpacing.sm.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meal type label
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 7.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              mealLabel,
                              style: t.labelS.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.sp),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs.h),
                      // Dish name
                      Text(
                        dish.name,
                        style: t.titleL.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs.h),
                      // Calories
                      Text(
                        '${dish.calories.toInt()} kcal',
                        style: t.labelM.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: AppSpacing.xs.h),
                      // Macro chips
                      Wrap(
                        spacing: 4.w,
                        runSpacing: 4.h,
                        children: [
                          _macroChip('${dish.protein.toInt()}g P',
                              palette.protein),
                          _macroChip('${dish.carbs.toInt()}g C',
                              palette.carbs),
                          _macroChip('${dish.fat.toInt()}g F',
                              palette.fat),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Log button
              if (userId != null && isToday)
                Padding(
                  padding: EdgeInsets.only(right: AppSpacing.md.w),
                  child: isLoggingNow
                      ? SizedBox(
                          width: 28.w,
                          height: 28.w,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: primary),
                        )
                      : GestureDetector(
                          onTap: isLogged ? null : onLog,
                          child: AnimatedContainer(
                            duration: AppMotion.normal,
                            width: 36.w,
                            height: 36.w,
                            decoration: BoxDecoration(
                              color: isLogged
                                  ? primary
                                  : palette.surfaceVariant,
                              shape: BoxShape.circle,
                              border: isLogged
                                  ? null
                                  : Border.all(
                                      color: palette.border, width: 1.5),
                            ),
                            child: Icon(
                              isLogged
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 18.sp,
                              color: isLogged
                                  ? Colors.white
                                  : palette.textSecondary,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
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
