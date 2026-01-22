import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/weekly_meal_plan_model.dart';
import '../models/user_model.dart';

import '../utils/calorie_calculator.dart';
import 'dish_service.dart';
import 'ai/ai_service.dart';
import 'ai/prompt_service.dart';

class WeeklyMealPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DishService _dishService = DishService();
  final AIService _aiService = AIService();
  final PromptService _promptService = PromptService();

  // Singleton
  static final WeeklyMealPlanService _instance =
      WeeklyMealPlanService._internal();
  factory WeeklyMealPlanService() => _instance;
  WeeklyMealPlanService._internal();

  /// Main method: Get existing valid plan or generate new one
  Future<WeeklyMealPlanModel?> getWeeklyMealPlan(UserModel user,
      {bool forceRefresh = false}) async {
    // 1. Check existing plan
    if (!forceRefresh) {
      final existingPlan = await _fetchUserMealPlan(user.uid);
      if (existingPlan != null && !existingPlan.isExpired) {
        // Also check if profile drastically changed => regenerate?
        final currentHash = _generateProfileHash(user);
        if (existingPlan.generationPromptHash == currentHash) {
          print('Using cached meal plan for user ${user.uid}');
          return existingPlan;
        } else {
          print('User profile changed, regenerating plan...');
        }
      }
    }

    // 2. Generate new plan
    return await _generateAndSaveMealPlan(user);
  }

  Future<WeeklyMealPlanModel?> _fetchUserMealPlan(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .doc('current')
          .get();
      if (doc.exists) {
        return WeeklyMealPlanModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error fetching meal plan: $e');
    }
    return null;
  }

  Future<WeeklyMealPlanModel?> _generateAndSaveMealPlan(UserModel user) async {
    try {
      print('Generating new AI meal plan for user ${user.uid}...');

      // 1. Gather Data
      final dishes = await _dishService.getAllDishes();
      if (dishes.isEmpty) {
        // Try seeding if empty?
        await _dishService.seedDatabase();
        // Then convert to list again
        // For now just return null if really empty
        if ((await _dishService.getAllDishes()).isEmpty) return null;
      }

      final userProfile = _extractUserProfile(user);
      final tdee = _calculateUserCalories(user, userProfile);

      // 2. Create Prompt
      final prompt = _promptService.generateWeeklyMealPlanPrompt(
        userProfile: userProfile,
        dailyCalorieTarget: tdee,
        availableDishes: dishes,
      );

      // 3. Call AI
      // We expect a valid JSON string
      final jsonResponse = await _aiService.generateJson(
          prompt: prompt,
          jsonStructure: '{ ... WeeklyMealPlanModel structure ... }');

      // 4. Parse Response
      final now = DateTime.now();
      // Calculate start of week (e.g., next Monday or today)
      final weekStart = DateTime(now.year, now.month, now.day);

      final daysList = (jsonResponse['days'] as List).map((d) {
        final offset = d['date_offset'] as int? ?? 0;
        return DayMealPlan(
          date: weekStart.add(Duration(days: offset)),
          dayName: d['day_name'] ?? '',
          meals: Map<String, String>.from(d['meals']),
          totalCalories: (d['total_calories'] as num).toDouble(),
          macros: (d['macros'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        );
      }).toList();

      final plan = WeeklyMealPlanModel(
        id: 'current', // or generate unique ID
        userId: user.uid,
        weekStartDate: weekStart,
        days: daysList,
        totalCalories: (jsonResponse['total_calories'] as num).toDouble(),
        avgDailyCalories:
            (jsonResponse['avg_daily_calories'] as num).toDouble(),
        avgMacros: (jsonResponse['avg_macros'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        generationPromptHash: _generateProfileHash(user),
        isAiGenerated: true,
      );

      // 5. Save to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc('current')
          .set(plan.toJson());

      // Also save to history? Optional.

      return plan;
    } catch (e) {
      print('Error generating meal plan: $e');
      return null;
    }
  }

  Map<String, dynamic> _extractUserProfile(UserModel user) {
    final data = user.onboardingData ?? {};
    // Safely extract fields, providing defaults
    return {
      'goal': _safeGet(data, 'primary_goals', 'maintain_weight'),
      'activity_level': _safeGet(data, 'activity_level', 'sedentary'),
      'restrictions': 'None', // Extract from data if available
      'dislikes': (data['disliked_foods'] as List?)
              ?.map((e) => e.toString())
              .join(', ') ??
          'None',
    };
  }

  String _safeGet(Map data, String key, String defaultVal) {
    if (data[key] == null) return defaultVal;
    if (data[key] is String) return data[key];
    if (data[key] is Map) return data[key]['value'] ?? defaultVal;
    return defaultVal;
  }

  double _calculateUserCalories(UserModel user, Map<String, dynamic> profile) {
    // Reuse CalorieCalculator logic here or approximate
    // Since CalorieCalculator requires specific types, we might need parsing.
    // For brevity, using a safe default or simple logic if CalorieCalculator is complex to instantiate.
    // Assuming CalorieCalculator has static methods:

    final data = user.onboardingData?['personal_info'];
    if (data == null) return 2000.0;

    final height = (data['height'] as num?)?.toDouble() ?? 170;
    final weight = (data['weight'] as num?)?.toDouble() ?? 70;
    final ageDate = DateTime.tryParse(data['birth_date']?.toString() ?? '') ??
        DateTime(1990);
    final age = DateTime.now().year - ageDate.year;
    final gender = data['gender']?.toString() ?? 'Male';
    final activity = profile['activity_level'].toString();
    final goal = profile['goal'].toString();

    final bmr = CalorieCalculator.calculateBMR(
        weight: weight, height: height, age: age, gender: gender);
    final tdee =
        CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: activity);
    return CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: goal);
  }

  String _generateProfileHash(UserModel user) {
    // Generate a hash based on critical logic fields to detect changes
    final data = user.onboardingData ?? {};
    final rawString =
        '${data['primary_goals']}-${data['activity_level']}-${data['disliked_foods']}';
    return md5.convert(utf8.encode(rawString)).toString();
  }
}
