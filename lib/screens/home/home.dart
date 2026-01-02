import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/models/user_model.dart';
import '../../core/models/meal_plan_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/recipe_generation_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/navigation_provider.dart';
import '../recipe/recipe_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final RecipeGenerationService _recipeService = RecipeGenerationService();
  MealPlan? _todayMealPlan;
  DateTime? _lastRefreshTime;

  // Custom Refresh State
  double _pullDistance = 0.0;
  bool _isRefreshing = false;
  late AnimationController _refreshController;
  final double _refreshThreshold = 100.0; // Standard comfortable threshold

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
        _loadTodayMealPlan();
      }
    } finally {
      if (mounted) context.read<UserProvider>().refreshUser();
    }
  }

  double _scale(BuildContext context, double value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return value * (screenWidth / 390.0);
  }

  Future<void> _onRefresh() async {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inSeconds < 2) {
      return;
    }
    _lastRefreshTime = now;
    await Future.wait([
      _loadTodayMealPlan(),
      context.read<UserProvider>().refreshUser(),
    ]);
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _pullDistance = 0.0;
      });
      _refreshController.stop();
    }
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        setState(() {
          _pullDistance = notification.metrics.pixels.abs();
        });
      } else if (_pullDistance != 0) {
        setState(() {
          _pullDistance = 0;
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullDistance >= _refreshThreshold) {
        _startRefresh();
      } else {
        setState(() {
          _pullDistance = 0;
        });
      }
    }
  }

  void _startRefresh() {
    setState(() {
      _isRefreshing = true;
      _pullDistance = _refreshThreshold;
    });
    _refreshController.repeat();
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Modern Minimalist Glass Refresh Indicator
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
                _scale(context, 24),
                _scale(context, 32),
                _scale(context, 24),
                _scale(context, 120),
              ),
              child: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  if (userProvider.isLoading && userProvider.user == null) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  final userModel = userProvider.user;
                  if (userModel == null) {
                    return const Center(child: Text('User data not found.'));
                  }
                  return _buildHomeContent(context, userModel);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalGlassRefresh(BuildContext context) {
    final double progress = (_pullDistance / _refreshThreshold).clamp(0.0, 1.0);
    final double opacity = progress.clamp(0.0, 1.0);
    final double scale = 0.5 + (progress * 0.5);

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: AnimatedBuilder(
            animation: _refreshController,
            builder: (context, child) {
              final pulse = _isRefreshing
                  ? (math.sin(_refreshController.value * math.pi * 2) * 0.05)
                  : 0.0;
              final currentScale = scale + pulse;
              final rotation = _isRefreshing
                  ? _refreshController.value * 2 * math.pi
                  : progress * math.pi;

              return Container(
                width: _scale(context, 48),
                height: _scale(context, 48),
                transform: Matrix4.identity()..scale(currentScale),
                transformAlignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress / Refresh Ring
                    CustomPaint(
                      size: Size(_scale(context, 48), _scale(context, 48)),
                      painter: _RefreshRingPainter(
                        progress: _isRefreshing ? 0.3 : progress,
                        rotation: rotation,
                        color: const Color(0xFFF97300),
                      ),
                    ),

                    // Centered Icon
                    Transform.rotate(
                      angle: rotation,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: const Color(0xFFF97300),
                        size: _scale(context, 22),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, UserModel userModel) {
    final onboardingData = userModel.onboardingData ?? {};
    final height = (onboardingData['height'] as num?)?.toDouble() ?? 170.0;
    final weight = (onboardingData['weight'] as num?)?.toDouble() ?? 70.0;
    final birthDate = onboardingData['birth_date'] != null
        ? DateTime.parse(onboardingData['birth_date'] as String)
        : DateTime.now().subtract(const Duration(days: 365 * 30));
    final gender = onboardingData['gender'] as String? ?? 'Male';
    final activityLevel = (onboardingData['activity_level']
            as Map<String, dynamic>?)?['value'] as String? ??
        'Sedentary';
    final primaryGoal =
        (onboardingData['primary_goals'] as List<dynamic>?)?.isNotEmpty ?? false
            ? ((onboardingData['primary_goals'] as List<dynamic>).first
                    as Map<String, dynamic>)['value'] as String? ??
                'Maintain Weight'
            : 'Maintain Weight';

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
        _buildTopBar(context),
        SizedBox(height: _scale(context, 32)),
        _buildWelcomeHeader(context, userModel),
        SizedBox(height: _scale(context, 32)),
        Text(
          "Nutrition",
          style: TextStyle(
            fontSize: _scale(context, 22),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E3A59),
          ),
        ),
        SizedBox(height: _scale(context, 16)),
        _buildNutritionCard(context, adjustedTDEE, macros),
        SizedBox(height: _scale(context, 32)),
        _buildMealPlanSection(context, userModel),
        SizedBox(height: _scale(context, 32)),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final nav = context.read<NavigationProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.menu, size: 28, color: Colors.black),
          onPressed: () => nav.toggleMenu(true),
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, size: 28, color: Colors.black),
          onPressed: () => nav.setIndex(3),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, UserModel userModel) {
    final displayName =
        userModel.displayName ?? (userModel.email?.split('@').first) ?? 'User';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Good Morning ",
              style: TextStyle(
                fontSize: _scale(context, 18),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "☀️",
              style: TextStyle(fontSize: _scale(context, 18)),
            ),
          ],
        ),
        SizedBox(height: _scale(context, 8)),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: _scale(context, 36),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E3A59),
            ),
            children: [
              const TextSpan(text: "Hello "),
              TextSpan(
                text: "$displayName!",
                style: const TextStyle(color: Color(0xFFF97300)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(
      BuildContext context, double targetCalories, Map<String, double> macros) {
    const currentCalories = 1350;
    final targetCalInt = targetCalories.toInt();
    final progress = (currentCalories / targetCalInt).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_scale(context, 24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(_scale(context, 24)),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(_scale(context, 24)),
            border: Border.all(color: Colors.white.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: _scale(context, 20),
                offset: Offset(0, _scale(context, 10)),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Calories",
                    style: TextStyle(
                      fontSize: _scale(context, 18),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E3A59),
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: _scale(context, 18), color: Colors.grey),
                      children: [
                        TextSpan(
                          text: "$currentCalories",
                          style: const TextStyle(
                            color: Color(0xFFF97300),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: " /$targetCalInt kCal",
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
              SizedBox(height: _scale(context, 20)),
              ClipRRect(
                borderRadius: BorderRadius.circular(_scale(context, 10)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: _scale(context, 10),
                  backgroundColor: Colors.black.withAlpha(10),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFF97300)),
                ),
              ),
              SizedBox(height: _scale(context, 24)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroInfoMini(
                      context, "Protein", "${macros['protein']?.toInt()}g"),
                  _macroInfoMini(
                      context, "Carbs", "${macros['carbs']?.toInt()}g"),
                  _macroInfoMini(context, "Fat", "${macros['fat']?.toInt()}g"),
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
            fontSize: _scale(context, 14),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: _scale(context, 8)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _scale(context, 20),
            color: const Color(0xFF2E3A59),
          ),
        ),
      ],
    );
  }

  Widget _buildMealPlanSection(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Meal Plan",
              style: TextStyle(
                fontSize: _scale(context, 22),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E3A59),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "Edit",
                style: TextStyle(
                  color: const Color(0xFFF97300),
                  fontWeight: FontWeight.bold,
                  fontSize: _scale(context, 16),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _scale(context, 16)),
        if (_todayMealPlan == null)
          _buildEmptyPlanState(context, user)
        else
          ..._buildMealsList(),
      ],
    );
  }

  Widget _buildEmptyPlanState(BuildContext context, UserModel user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_scale(context, 16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(_scale(context, 24)),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(_scale(context, 24)),
            border: Border.all(color: Colors.white.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: _scale(context, 20),
                offset: Offset(0, _scale(context, 10)),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant_outlined,
                  size: _scale(context, 48),
                  color: const Color(0xFF2E3A59).withAlpha(150)),
              SizedBox(height: _scale(context, 16)),
              Text(
                "No meal plan for today yet",
                style: TextStyle(
                    color: const Color(0xFF2E3A59),
                    fontWeight: FontWeight.bold,
                    fontSize: _scale(context, 16)),
              ),
              SizedBox(height: _scale(context, 12)),
              ElevatedButton(
                onPressed: () => _generateMealPlan(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97300),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Generate Daily Plan",
                    style: TextStyle(fontSize: _scale(context, 14))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMealsList() {
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_scale(context, 20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              margin: EdgeInsets.only(bottom: _scale(context, 16)),
              padding: EdgeInsets.all(_scale(context, 16)),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(140),
                borderRadius: BorderRadius.circular(_scale(context, 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: _scale(context, 15),
                    offset: Offset(0, _scale(context, 8)),
                  ),
                ],
                border: Border.all(color: Colors.white.withAlpha(80)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_scale(context, 16)),
                    child: Container(
                      width: _scale(context, 90),
                      height: _scale(context, 90),
                      color: Colors.grey[100]!.withAlpha(100),
                      child: recipe?.imageUrl != null
                          ? Image.network(recipe!.imageUrl!, fit: BoxFit.cover)
                          : Icon(Icons.restaurant,
                              color: Colors.grey[300],
                              size: _scale(context, 30)),
                    ),
                  ),
                  SizedBox(width: _scale(context, 20)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toBeginningOfSentenceCase(entry.key) ?? entry.key,
                          style: TextStyle(
                            fontSize: _scale(context, 15),
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: _scale(context, 6)),
                        Text(
                          recipe?.title ?? "Loading recipe...",
                          style: TextStyle(
                            fontSize: _scale(context, 18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3A59),
                          ),
                        ),
                        SizedBox(height: _scale(context, 6)),
                        Text(
                          "${recipe?.macros['calories']?.toInt() ?? 0} calories",
                          style: TextStyle(
                            fontSize: _scale(context, 15),
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

    // Draw the arc based on progress
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
