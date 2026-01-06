import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/models/user_model.dart';
import '../../core/models/meal_plan_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/recipe_generation_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/admin_status_service.dart';
import '../../core/localization/app_localizations.dart';
import '../common/generic_error_screen.dart';
import '../recipe/recipe_detail_screen.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/widgets/main_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final StorageService _storageService = StorageService();
  final RecipeGenerationService _recipeService = RecipeGenerationService();
  MealPlan? _todayMealPlan;
  DateTime? _lastRefreshTime;

  // Custom Refresh State
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier(0.0);
  bool _isRefreshing = false;
  late AnimationController _refreshController;
  final double _refreshThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _loadTodayMealPlan();
    _loadHydration();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _pullDistanceNotifier.dispose();
    super.dispose();
  }

  void _loadHydration() {}

  Future<void> _loadTodayMealPlan() async {
    final now = DateTime.now();
    final plan = _storageService.getMealPlan(now);
    setState(() {
      _todayMealPlan = plan;
    });
  }

  Future<void> _generateMealPlan(UserModel user) async {
    try {
      final recipe = await _recipeService.generateRecipe(
        ingredients: ["seasonal", "healthy"],
        targetCalories: 2000 / 3,
      );

      if (recipe != null) {
        final plan = MealPlan(
          date: DateTime.now(),
          meals: {'breakfast': recipe.id},
          totalCalories: recipe.macros['calories'] ?? 0,
          totalMacros: recipe.macros,
        );
        await _storageService.saveMealPlan(plan);
        await _storageService.saveRecipe(recipe);
        if (mounted) await _loadTodayMealPlan();
      }
    } finally {
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

    try {
      final userId = context.read<UserProvider>().user?.uid;
      if (userId != null) {
        // Check ban status on refresh
        await AdminStatusService()
            .checkStatus(userId, forceRefresh: true)
            .then((status) {
          if (status == AdminStatus.banned) {
            AdminStatusService().notifyBanned(userId);
          }
        });
      }

      await Future.wait([
        _loadTodayMealPlan(),
        context.read<UserProvider>().refreshUser(),
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
                    SizedBox(
                      height: 0.7.sh,
                      child: const Center(child: CircularProgressIndicator()),
                    )
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
                    transform: Matrix4.identity()..scale(currentScale),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeHeader(context, userModel, l10n),
        SizedBox(height: 32.h),
        Text(
          l10n.translate('home.nutrition_title'),
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E3A59),
          ),
        ),
        SizedBox(height: 16.h),
        _buildNutritionCard(context, adjustedTDEE, macros, l10n),
        SizedBox(height: 32.h),
        _buildMealPlanSection(context, userModel, l10n),
        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _buildWelcomeHeader(
      BuildContext context, UserModel userModel, AppLocalizations l10n) {
    final displayName = userModel.displayName?.split(' ').first ??
        (userModel.email?.split('@').first) ??
        'User';
    final currentTime = DateTime.now();
    final hour = currentTime.hour;
    final greeting = hour < 12
        ? l10n.translate('home.good_morning')
        : hour < 18
            ? l10n.translate('home.good_afternoon')
            : l10n.translate('home.good_evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "☀️",
              style: TextStyle(fontSize: 18.sp),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 36.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E3A59),
            ),
            children: [
              TextSpan(text: l10n.translate('home.hello')),
              TextSpan(
                text: "$displayName!",
                style: TextStyle(
                    color: context.watch<ThemeProvider>().primaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(BuildContext context, double targetCalories,
      Map<String, double> macros, AppLocalizations l10n) {
    const currentCalories = 1350;
    final targetCalInt = targetCalories.toInt();
    final progress = (currentCalories / targetCalInt).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Optimized sigma
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20.r,
                offset: Offset(0, 10.h),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('home.calories'),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E3A59),
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 18.sp, color: Colors.grey),
                      children: [
                        TextSpan(
                          text: "$currentCalories",
                          style: TextStyle(
                            color: context.watch<ThemeProvider>().primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: l10n.translate('home.kcal',
                              variables: {'target': targetCalInt.toString()}),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10.h,
                  backgroundColor: Colors.black.withAlpha(10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      context.watch<ThemeProvider>().primaryColor),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroInfoMini(context, l10n.translate('home.macros.protein'),
                      "${macros['protein']?.toInt()}g"),
                  _macroInfoMini(context, l10n.translate('home.macros.carbs'),
                      "${macros['carbs']?.toInt()}g"),
                  _macroInfoMini(context, l10n.translate('home.macros.fat'),
                      "${macros['fat']?.toInt()}g"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroInfoMini(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
            color: const Color(0xFF2E3A59),
          ),
        ),
      ],
    );
  }

  Widget _buildMealPlanSection(
      BuildContext context, UserModel user, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translate('home.meal_plan_title'),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E3A59),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                l10n.translate('home.edit'),
                style: TextStyle(
                  color: context.watch<ThemeProvider>().primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        if (_todayMealPlan == null)
          _buildEmptyPlanState(context, user, l10n)
        else
          ..._buildMealsList(l10n),
      ],
    );
  }

  Widget _buildEmptyPlanState(
      BuildContext context, UserModel user, AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20.r,
                offset: Offset(0, 10.h),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant_outlined,
                  size: 48.w, color: const Color(0xFF2E3A59).withAlpha(150)),
              SizedBox(height: 16.h),
              Text(
                l10n.translate('home.no_meal_plan'),
                style: TextStyle(
                    color: const Color(0xFF2E3A59),
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => _generateMealPlan(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.watch<ThemeProvider>().primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text(l10n.translate('home.generate_plan'),
                    style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMealsList(AppLocalizations l10n) {
    return _todayMealPlan!.meals.entries.map((entry) {
      final recipe = _storageService.getRecipe(entry.value);
      return GestureDetector(
        onTap: () {
          if (recipe != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(recipe: recipe)),
            );
          }
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white
                .withAlpha(240), // Increased opacity since we lost blur
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  width: 90.w,
                  height: 90.w,
                  color: Colors.grey[100]!.withAlpha(100),
                  child: recipe?.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe!.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 200, // Optimize memory usage
                          memCacheHeight: 200,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        )
                      : Icon(Icons.restaurant,
                          color: Colors.grey[300], size: 30.w),
                ),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toBeginningOfSentenceCase(entry.key) ?? entry.key,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      recipe?.title ?? l10n.translate('home.loading_recipe'),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E3A59),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      l10n.translate('home.calories_suffix', variables: {
                        'count': (recipe?.macros['calories']?.toInt() ?? 0)
                            .toString()
                      }),
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
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
