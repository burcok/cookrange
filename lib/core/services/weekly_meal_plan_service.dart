import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/weekly_meal_plan_model.dart';
import '../models/user_model.dart';
import '../models/user_nutrition_profile.dart';
import '../utils/calorie_calculator.dart';
import '../utils/allergen_safety.dart';
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
      {bool forceRefresh = false, String locale = 'en'}) async {
    // 1. Check existing plan
    if (!forceRefresh) {
      final existingPlan = await _fetchUserMealPlan(user.uid);
      if (existingPlan != null && !existingPlan.isExpired) {
        // Also check if profile drastically changed => regenerate?
        final currentHash = _generateProfileHash(user);
        if (existingPlan.generationPromptHash == currentHash) {
          debugPrint('Using cached meal plan for user ${user.uid}');
          return existingPlan;
        } else {
          debugPrint('User profile changed, regenerating plan...');
        }
      }
    }

    // 2. Generate new plan
    return _generateAndSaveMealPlan(user, locale: locale);
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
      debugPrint('Error fetching meal plan: $e');
    }
    return null;
  }

  Future<WeeklyMealPlanModel?> _generateAndSaveMealPlan(UserModel user,
      {String locale = 'en'}) async {
    try {
      debugPrint('Generating new AI meal plan for user ${user.uid}...');

      // 1. Gather Data
      final dishes = await _dishService.getAllDishes();
      if (dishes.isEmpty) {
        // Try seeding if empty?
        await _dishService.seedDatabase();
        // Then convert to list again
        // For now just return null if really empty
        if ((await _dishService.getAllDishes()).isEmpty) return null;
      }

      final nutritionProfile = user.profile;
      final userProfile = _extractUserProfile(nutritionProfile);
      final tdee = _calculateUserCalories(nutritionProfile);

      // Deterministic life-safety filter: remove every dish containing a
      // declared allergen / avoid-ingredient BEFORE the AI sees the pool, so the
      // model can only ever select safe dishes (it picks by ID from this list).
      // This backstops the prompt's allergy instruction, which an LLM may ignore.
      final poolForAi = AllergenSafety.filterSafe(
        dishes,
        allergyIds: nutritionProfile.allergyIds,
        avoidIngredients: nutritionProfile.avoidIngredients,
      );
      if (poolForAi.isEmpty) {
        // Refuse to generate rather than risk serving an allergen-containing
        // plan. Caller surfaces the empty/error state.
        debugPrint('WeeklyMealPlan: no allergen-safe dishes for user '
            '${user.uid} — refusing to generate a potentially unsafe plan');
        return null;
      }

      // 2. Create Prompt
      final prompt = _promptService.generateWeeklyMealPlanPrompt(
        userProfile: userProfile,
        dailyCalorieTarget: tdee,
        availableDishes: poolForAi,
        locale: locale,
      );

      // 3. Call AI
      // We expect a valid JSON string
      final jsonResponse = await _aiService.generateJson(
          prompt: prompt,
          jsonStructure: '{ ... WeeklyMealPlanModel structure ... }', type: 'meal_plan');

      // 4. Parse Response
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day);

      final rawDays = jsonResponse['days'];
      if (rawDays is! List || rawDays.isEmpty) {
        debugPrint(
            'WeeklyMealPlanService: invalid or empty days in AI response');
        return null;
      }

      final daysList = <DayMealPlan>[];
      for (final d in rawDays) {
        if (d is! Map<String, dynamic>) continue;
        try {
          final offset = (d['date_offset'] as num?)?.toInt() ?? 0;
          final rawMeals = d['meals'];
          final meals = rawMeals is Map
              ? Map<String, String>.from(
                  rawMeals.map((k, v) => MapEntry(k.toString(), v.toString())))
              : <String, String>{};
          final rawMacros = d['macros'];
          final macros = rawMacros is Map
              ? rawMacros.map(
                  (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()))
              : <String, double>{};
          daysList.add(DayMealPlan(
            date: weekStart.add(Duration(days: offset)),
            dayName: d['day_name']?.toString() ?? '',
            meals: meals,
            totalCalories: (d['total_calories'] as num? ?? 0).toDouble(),
            macros: macros,
          ));
        } catch (e) {
          debugPrint('WeeklyMealPlanService: skipping malformed day: $e');
        }
      }

      if (daysList.isEmpty) {
        debugPrint(
            'WeeklyMealPlanService: no valid days parsed from AI response');
        return null;
      }

      final rawAvgMacros = jsonResponse['avg_macros'];
      final avgMacros = rawAvgMacros is Map
          ? rawAvgMacros.map(
              (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()))
          : <String, double>{};

      final plan = WeeklyMealPlanModel(
        id: 'current',
        userId: user.uid,
        weekStartDate: weekStart,
        days: daysList,
        totalCalories: (jsonResponse['total_calories'] as num? ?? 0).toDouble(),
        avgDailyCalories:
            (jsonResponse['avg_daily_calories'] as num? ?? 0).toDouble(),
        avgMacros: avgMacros,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        generationPromptHash: _generateProfileHash(user),
      );

      // 5. Save to Firestore as current plan
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc('current')
          .set(plan.toJson());

      // 6. Archive to history (keyed by week start date for dedup)
      final historyKey =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      unawaited(_firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_plan_history')
          .doc(historyKey)
          .set({
        ...plan.toJson(),
        'id': historyKey,
        'archivedAt': FieldValue.serverTimestamp()
      }).catchError((e) => debugPrint('History archive error: $e')));

      return plan;
    } catch (e) {
      debugPrint('Error generating meal plan: $e');
      return null;
    }
  }

  /// Replaces a single meal in the stored plan without regenerating the whole week.
  Future<WeeklyMealPlanModel?> swapMeal({
    required String userId,
    required DateTime dayDate,
    required String mealType,
    required String newDishId,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .doc('current');
      final doc = await docRef.get();
      if (!doc.exists) return null;

      final plan = WeeklyMealPlanModel.fromFirestore(doc);
      final updatedDays = plan.days.map((d) {
        final sameDay = d.date.year == dayDate.year &&
            d.date.month == dayDate.month &&
            d.date.day == dayDate.day;
        if (!sameDay) return d;
        final newMeals = Map<String, String>.from(d.meals);
        newMeals[mealType] = newDishId;
        return DayMealPlan(
          date: d.date,
          dayName: d.dayName,
          meals: newMeals,
          totalCalories: d.totalCalories,
          macros: d.macros,
        );
      }).toList();

      final updatedPlan = WeeklyMealPlanModel(
        id: plan.id,
        userId: plan.userId,
        weekStartDate: plan.weekStartDate,
        days: updatedDays,
        totalCalories: plan.totalCalories,
        avgDailyCalories: plan.avgDailyCalories,
        avgMacros: plan.avgMacros,
        createdAt: plan.createdAt,
        expiresAt: plan.expiresAt,
        generationPromptHash: plan.generationPromptHash,
      );

      await docRef.update({
        'days': updatedDays
            .map((d) => {
                  'date': Timestamp.fromDate(d.date),
                  'day_name': d.dayName,
                  'meals': d.meals,
                  'total_calories': d.totalCalories,
                  'macros': d.macros,
                })
            .toList(),
      });

      return updatedPlan;
    } catch (e) {
      debugPrint('WeeklyMealPlanService.swapMeal error: $e');
      return null;
    }
  }

  Map<String, dynamic> _extractUserProfile(UserNutritionProfile p) {
    final restrictions = [...p.dietaryRestrictionIds, ...p.allergyIds];
    final allDislikes = [...p.dislikedFoodKeys, ...p.avoidIngredients];
    return {
      'goal':
          p.primaryGoals.isNotEmpty ? p.primaryGoals.first : 'maintain_weight',
      'activity_level': p.activityLevel,
      'restrictions':
          restrictions.isNotEmpty ? restrictions.join(', ') : 'None',
      'allergies': p.allergyIds.isNotEmpty ? p.allergyIds.join(', ') : 'None',
      'dislikes': allDislikes.isNotEmpty ? allDislikes.join(', ') : 'None',
    };
  }

  double _calculateUserCalories(UserNutritionProfile p) {
    final height = p.heightCm?.toDouble() ?? 170;
    final weight = p.weightKg?.toDouble() ?? 70;
    final age = p.age ?? 30;
    final gender = p.gender ?? 'Male';
    final activity = p.activityLevel;
    final goal =
        p.primaryGoals.isNotEmpty ? p.primaryGoals.first : 'maintain_weight';

    final bmr = CalorieCalculator.calculateBMR(
        weight: weight, height: height, age: age, gender: gender);
    final tdee =
        CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: activity);
    return CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: goal);
  }

  String _generateProfileHash(UserModel user) {
    final p = user.profile;
    final rawString =
        '${p.primaryGoals}-${p.activityLevel}-${p.dislikedFoodKeys}-${p.avoidIngredients}-${p.allergyIds}-${p.dietaryRestrictionIds}';
    return md5.convert(utf8.encode(rawString)).toString();
  }

  /// Fetch paginated meal plan history (newest first).
  Future<List<WeeklyMealPlanModel>> getMealPlanHistory(
    String userId, {
    int limit = 10,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(userId)
          .collection('meal_plan_history')
          .orderBy('archivedAt', descending: true)
          .limit(limit);

      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      final snap = await query.get();
      return snap.docs
          .map((d) => WeeklyMealPlanModel.fromFirestore(d))
          .toList();
    } catch (e) {
      debugPrint('WeeklyMealPlanService.getMealPlanHistory error: $e');
      return [];
    }
  }

  /// Restore a historical plan as the current plan.
  Future<void> restorePlan(String userId, WeeklyMealPlanModel plan) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('meal_plans')
        .doc('current')
        .set(plan.toJson());
  }

  /// Generates 2 lightweight "what-if" macro alternatives for comparison.
  /// Does NOT write to Firestore — purely ephemeral.
  Future<List<PlanAlternate>> generatePlanAlternates(UserModel user,
      {String locale = 'en'}) async {
    final p = user.profile;
    final calories = _calculateUserCalories(p);
    final restrictions = [...p.dietaryRestrictionIds, ...p.allergyIds];
    final prompt = _promptService.generatePlanAlternatesPrompt(
      dailyCalorieTarget: calories,
      goal:
          p.primaryGoals.isNotEmpty ? p.primaryGoals.first : 'maintain_weight',
      activityLevel: p.activityLevel,
      restrictions: restrictions.isNotEmpty ? restrictions.join(', ') : 'None',
      locale: locale,
    );

    try {
      final json = await _aiService.generateJson(
        prompt: prompt,
        jsonStructure:
            '{"alternates":[{"name":"","description":"","avg_daily_calories":0,"avg_macros":{"protein":0,"carbs":0,"fat":0}}]}',
        type: 'meal_plan',
      );
      final list = json['alternates'] as List? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(PlanAlternate.fromJson)
          .where((a) => a.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('WeeklyMealPlanService.generatePlanAlternates error: $e');
      return [];
    }
  }
}
