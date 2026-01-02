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

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final RecipeGenerationService _recipeService = RecipeGenerationService();
  MealPlan? _todayMealPlan;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _loadTodayMealPlan();
    _loadHydration();
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
      // For now, generating a single default recipe as a "plan" sample
      // Real app would generate 3 recipes or use a specific MealPlanGenerationService
      final recipe = await _recipeService.generateRecipe(
        ingredients: ["seasonal", "healthy"],
        targetCalories: 2000 / 3,
      );

      if (recipe != null) {
        final plan = MealPlan(
          date: DateTime.now(),
          meals: {'breakfast': recipe.id}, // simplified for POC
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF9),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading && userProvider.user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final userModel = userProvider.user;
          if (userModel == null) {
            return const Center(child: Text('User data not found.'));
          }
          return _buildFullHomeScreen(context, userModel);
        },
      ),
    );
  }

  Widget _buildFullHomeScreen(BuildContext context, UserModel userModel) {
    // ... (Keep the existing BMR/Macro logic) ...
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

    return RefreshIndicator(
      onRefresh: () async {
        final now = DateTime.now();
        if (_lastRefreshTime != null &&
            now.difference(_lastRefreshTime!).inSeconds < 3) {
          return;
        }
        _lastRefreshTime = now;
        await Future.wait([
          _loadTodayMealPlan(),
          context.read<UserProvider>().refreshUser(),
        ]);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          _scale(context, 24),
          _scale(context, 32),
          _scale(context, 24),
          _scale(context, 100),
        ),
        child: Column(
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
        ),
      ),
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

    return Container(
      padding: EdgeInsets.all(_scale(context, 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_scale(context, 24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              backgroundColor: const Color(0xFFEEEEEE),
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
              _macroInfoMini(context, "Carbs", "${macros['carbs']?.toInt()}g"),
              _macroInfoMini(context, "Fat", "${macros['fat']?.toInt()}g"),
            ],
          ),
        ],
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
              onPressed: () {
                // Future: Weekly plan view or edit
              },
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_scale(context, 24)),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(_scale(context, 16)),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined,
              size: _scale(context, 48), color: Colors.grey[400]),
          SizedBox(height: _scale(context, 16)),
          Text(
            "No meal plan for today yet",
            style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: _scale(context, 16)),
          ),
          SizedBox(height: _scale(context, 12)),
          ElevatedButton(
            onPressed: () => _generateMealPlan(user),
            child: Text("Generate Daily Plan",
                style: TextStyle(fontSize: _scale(context, 14))),
          ),
        ],
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
        child: Container(
          margin: EdgeInsets.only(bottom: _scale(context, 16)),
          padding: EdgeInsets.all(_scale(context, 16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_scale(context, 20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: _scale(context, 15),
                offset: Offset(0, _scale(context, 8)),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F1F1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_scale(context, 16)),
                child: Container(
                  width: _scale(context, 90),
                  height: _scale(context, 90),
                  color: Colors.grey[100],
                  child: recipe?.imageUrl != null
                      ? Image.network(recipe!.imageUrl!, fit: BoxFit.cover)
                      : Icon(Icons.restaurant,
                          color: Colors.grey[300], size: _scale(context, 30)),
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
      );
    }).toList();
  }
}
