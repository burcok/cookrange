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
import '../utils/plan_nutrition_calculator.dart';
import '../utils/template_plan_adapter.dart';
import '../models/meal_entry_model.dart';
import '../models/meal_plan_template_model.dart';
import 'crashlytics_service.dart';
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
    if (!_aiService.isConfigured) {
      throw const AIFatalException('AI is not configured');
    }
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
          jsonStructure: '{ ... WeeklyMealPlanModel structure ... }',
          type: 'meal_plan');

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

      // 6. Archive to history (keyed by week start date for dedup) — see
      // archiveToHistory's own doc comment for why this snapshots THIS
      // (the just-written) plan rather than reading back the one it
      // replaced; Faz 3 §3.5's adoptTemplate is this method's second
      // caller (extracted rather than duplicated, so both stay in sync).
      unawaited(archiveToHistory(user.uid, plan));

      return plan;
    } on AIFatalException {
      rethrow;
    } catch (e) {
      debugPrint('Error generating meal plan: $e');
      return null;
    }
  }

  /// Snapshots [plan] into `meal_plan_history/{weekStartKey}` (dedup key =
  /// `plan.weekStartDate`, `YYYY-MM-DD`). Factored out of
  /// `_generateAndSaveMealPlan`'s old inline step 6 — Faz 3 §3.5's
  /// [adoptTemplate] is the second caller, and both now share this instead
  /// of each hand-rolling the same key derivation + write (which is
  /// precisely the class of duplication that caused S7).
  ///
  /// Note this snapshots whichever [plan] the caller passes — typically the
  /// plan THEY just wrote as current, not necessarily "the previous one" —
  /// see [adoptTemplate]'s doc comment for why that distinction matters and
  /// how it stays faithful to "archive the old plan" despite that.
  Future<void> archiveToHistory(String userId, WeeklyMealPlanModel plan) async {
    final weekStart = plan.weekStartDate;
    final historyKey = '${weekStart.year}-'
        '${weekStart.month.toString().padLeft(2, '0')}-'
        '${weekStart.day.toString().padLeft(2, '0')}';
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('meal_plan_history')
          .doc(historyKey)
          .set({
        ...plan.toJson(),
        'id': historyKey,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      debugPrint('WeeklyMealPlanService.archiveToHistory error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'WeeklyMealPlanService.archiveToHistory userId=$userId'));
    }
  }

  /// Public wrapper around [_generateProfileHash] — Faz 3 §3.5's
  /// [adoptTemplate] needs to stamp the member's CURRENT profile hash onto
  /// an accepted template's plan doc, so `getWeeklyMealPlan`'s cache check
  /// reads it as already up to date. Without this, the very next call to
  /// `getWeeklyMealPlan` would see a `generationPromptHash` that doesn't
  /// match `_generateProfileHash(user)` (an accepted template was never
  /// hashed against anything) and silently regenerate an unrelated AI plan
  /// in its place, discarding what the member just accepted.
  String computeCurrentProfileHash(UserModel user) =>
      _generateProfileHash(user);

  /// Faz 3 §3.5 accept flow: converts an offer's (or any template's)
  /// [templateDays] into a live `meal_plans/current` doc for [user].
  ///
  /// Archives whatever was previously current into `meal_plan_history`
  /// FIRST via [archiveToHistory] — "eski plan meal_plan_history'ye
  /// arşivlenir" — before overwriting it, so a member who accepts an offer
  /// never silently loses whatever plan they had (AI-generated or a prior
  /// accepted template alike). Nothing is written to history for the
  /// NEWLY-adopted plan itself here (unlike `_generateAndSaveMealPlan`,
  /// which does snapshot its own output) — deliberately, to avoid a
  /// same-day `historyKey` collision overwriting the just-archived outgoing
  /// plan when both happen to share today's date; the newly-adopted plan
  /// gets its own history snapshot naturally, the next time IT is replaced.
  ///
  /// Nutrition totals are computed from the full-fidelity `List<MealEntry>`
  /// via [PlanNutritionCalculator] — the single authority (§3.4) — BEFORE
  /// [TemplatePlanAdapter] collapses each day down to the legacy
  /// `Map<String,String>` shape `DayMealPlan.meals` still uses; see that
  /// adapter's doc comment for exactly what that collapse loses (custom-food
  /// entries, same-day duplicate snack slots) and why it never affects the
  /// persisted numbers.
  ///
  /// Days lay out as 7 consecutive dates starting TODAY (matching
  /// `_generateAndSaveMealPlan`'s own "weekStart = day of generation, not a
  /// calendar Monday" convention) — a template's `dayIndex` is ordinal
  /// (0..6), not tied to a specific calendar weekday, so "start today" is
  /// the only convention already established anywhere else in this file to
  /// reuse rather than invent a new one.
  Future<WeeklyMealPlanModel> adoptTemplate({
    required UserModel user,
    required List<TemplateDay> templateDays,
  }) async {
    final userId = user.uid;
    final dishes = await _dishService.getAllDishes();
    final dishCatalog = {for (final d in dishes) d.id: d};

    final existing = await _fetchUserMealPlan(userId);
    if (existing != null) {
      await archiveToHistory(userId, existing);
    }

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day);
    final sortedDays = [...templateDays]
      ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final dayTotals = <PlanNutritionTotals>[];
    final days = <DayMealPlan>[];
    for (var i = 0; i < sortedDays.length; i++) {
      final templateDay = sortedDays[i];
      final totals = PlanNutritionCalculator.calculateEntries(
          templateDay.meals, dishCatalog);
      dayTotals.add(totals);
      days.add(DayMealPlan(
        date: weekStart.add(Duration(days: i)),
        dayName: TemplatePlanAdapter.weekdayName(templateDay.dayIndex),
        meals: TemplatePlanAdapter.collapseMealsToLegacyMap(templateDay.meals),
        totalCalories: totals.calories,
        macros: totals.macros,
        fiber: totals.fiber,
      ));
    }

    final week = PlanNutritionCalculator.combineDays(dayTotals);
    final plan = WeeklyMealPlanModel(
      id: 'current',
      userId: userId,
      weekStartDate: weekStart,
      days: days,
      totalCalories: week.total.calories,
      avgDailyCalories: week.average.calories,
      avgMacros: week.average.macros,
      totalFiber: week.total.fiber,
      avgDailyFiber: week.average.fiber,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      generationPromptHash: computeCurrentProfileHash(user),
      isAiGenerated: false,
    );

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .doc('current')
          .set(plan.toJson());
      debugPrint('WeeklyMealPlanService.adoptTemplate: wrote current plan '
          'for uid=$userId (${days.length} days)');
      return plan;
    } catch (e, stack) {
      debugPrint('WeeklyMealPlanService.adoptTemplate error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'WeeklyMealPlanService.adoptTemplate userId=$userId'));
      rethrow;
    }
  }

  /// Replaces a single meal in the stored plan without regenerating the whole week.
  ///
  /// Faz 0 §0.7 (S7) fix: this used to copy the OLD day's total_calories/
  /// macros verbatim onto the new meal set — swapping a 300kcal breakfast
  /// for an 800kcal one left every displayed total wrong, at both the day
  /// and plan level. A same-session fix recomputed both inline here; Faz 3
  /// §3.4 replaces that hand-rolled recompute with `PlanNutritionCalculator`
  /// — the same shared, unit-tested authority the template builder, plan
  /// view, and offer preview will also use, instead of each reinventing this
  /// math (which is how S7 happened in the first place). This also fixes an
  /// N+1 read: the old loop awaited `getDishById` once per meal slot (up to
  /// 7 days × ~4 meals); the calculator takes a resolved `{id: DishModel}`
  /// map, so the dish catalog is now fetched once, up front.
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
      final dishes = await _dishService.getAllDishes();
      final dishCatalog = {for (final dish in dishes) dish.id: dish};

      final updatedDays = <DayMealPlan>[];
      final dayTotals = <PlanNutritionTotals>[];
      for (final d in plan.days) {
        final sameDay = d.date.year == dayDate.year &&
            d.date.month == dayDate.month &&
            d.date.day == dayDate.day;
        if (!sameDay) {
          updatedDays.add(d);
          dayTotals.add(PlanNutritionTotals(
            calories: d.totalCalories,
            protein: d.macros['protein'] ?? 0,
            carbs: d.macros['carbs'] ?? 0,
            fat: d.macros['fat'] ?? 0,
            fiber: d.fiber,
          ));
          continue;
        }

        final newMeals = Map<String, String>.from(d.meals);
        newMeals[mealType] = newDishId;

        // The legacy Map<String,String> shape has no portion field, so every
        // slot is treated as exactly one serving (portion: 1.0, MealEntry's
        // own default) — identical to what this loop always assumed;
        // nothing about the persisted calorie/macro numbers changes here,
        // only where the summation logic lives. `fiber` is new: never
        // tracked by this path before.
        final entries = newMeals.entries
            .map((e) => MealEntry(dishId: e.value, mealType: e.key))
            .toList();
        final totals =
            PlanNutritionCalculator.calculateEntries(entries, dishCatalog);
        dayTotals.add(totals);

        updatedDays.add(DayMealPlan(
          date: d.date,
          dayName: d.dayName,
          meals: newMeals,
          totalCalories: totals.calories,
          macros: totals.macros,
          fiber: totals.fiber,
        ));
      }

      // Plan-level totals: sum/average across all days, mirroring the shape
      // the AI produces at generation time — folded from the per-day totals
      // already computed above rather than re-walked from scratch.
      final week = PlanNutritionCalculator.combineDays(dayTotals);

      final updatedPlan = WeeklyMealPlanModel(
        id: plan.id,
        userId: plan.userId,
        weekStartDate: plan.weekStartDate,
        days: updatedDays,
        totalCalories: week.total.calories,
        avgDailyCalories: week.average.calories,
        avgMacros: week.average.macros,
        totalFiber: week.total.fiber,
        avgDailyFiber: week.average.fiber,
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
                  'fiber': d.fiber,
                })
            .toList(),
        'total_calories': week.total.calories,
        'avg_daily_calories': week.average.calories,
        'avg_macros': week.average.macros,
        'total_fiber': week.total.fiber,
        'avg_daily_fiber': week.average.fiber,
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

  // Faz 0 §0.7: the original six inputs (goals/activity/dislikes/avoid/
  // allergies/dietary restrictions) never included body composition, so a
  // user could log a weight/goal-weight change and the cached plan would
  // never be marked stale — the audit's "uyum motoru" (adaptation engine)
  // claim was hollow at the root, since calorie targets derive from these
  // fields (see _computeTargetCalories above) but a change to them alone
  // never invalidated the hash. Weight/height/age/gender/target weight are
  // added below. This is hash integrity only — the adaptation engine itself
  // (proactively regenerating when body data changes, vs. only on the next
  // scheduled refresh) is separate, out-of-scope work.
  String _generateProfileHash(UserModel user) {
    final p = user.profile;
    final rawString = '${p.primaryGoals}-${p.activityLevel}-'
        '${p.dislikedFoodKeys}-${p.avoidIngredients}-${p.allergyIds}-'
        '${p.dietaryRestrictionIds}-${p.weightKg}-${p.heightCm}-${p.age}-'
        '${p.gender}-${p.targetWeightKg}';
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
    } catch (e, stack) {
      debugPrint('WeeklyMealPlanService.getMealPlanHistory error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'WeeklyMealPlanService.getMealPlanHistory userId=$userId'));
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
    } on AIFatalException {
      rethrow;
    } catch (e) {
      debugPrint('WeeklyMealPlanService.generatePlanAlternates error: $e');
      return [];
    }
  }
}
