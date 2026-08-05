import '../models/dish_model.dart';
import '../models/meal_entry_model.dart';

/// Immutable nutrition line: calories + macros (protein/carbs/fat) + fiber.
/// The additive unit [PlanNutritionCalculator] sums, scales and averages —
/// mirrors the field set `WeeklyMealPlanModel`/`DayMealPlan` already persist
/// (`totalCalories`/`macros`), plus `fiber`, which nothing on the existing
/// meal-plan pipeline tracked before this (Faz 3 §3.4).
///
/// Named `PlanNutritionTotals` (not the shorter `NutritionTotals`) because
/// `food_log_model.dart` already defines its own distinct `NutritionTotals`
/// (used by `FoodLog.sumLogs` — no `fiber`, no `+`/`scaled` operators, a
/// different domain: logged/eaten totals, not planned ones). Colliding on
/// the same bare name would make any future file that imports both
/// (plausible — comparing a day's PLANNED vs. LOGGED nutrition is an obvious
/// future screen) fail to compile with an ambiguous-import error.
class PlanNutritionTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const PlanNutritionTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  static const zero = PlanNutritionTotals();

  /// `{protein, carbs, fat}` — the exact shape `DayMealPlan.macros`/
  /// `WeeklyMealPlanModel.avgMacros` already use. `fiber` is deliberately
  /// NOT a key in here (it stays a sibling scalar field, like `calories`) so
  /// every existing consumer that iterates `.macros.entries` expecting
  /// exactly these three keys is unaffected by this addition.
  Map<String, double> get macros => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  PlanNutritionTotals operator +(PlanNutritionTotals other) =>
      PlanNutritionTotals(
        calories: calories + other.calories,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        fiber: fiber + other.fiber,
      );

  PlanNutritionTotals scaled(double factor) => PlanNutritionTotals(
        calories: calories * factor,
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
        fiber: fiber * factor,
      );
}

/// Per-day totals for a full plan, plus the week-level SUM and per-day
/// AVERAGE — the same two shapes `WeeklyMealPlanModel` already persists
/// (`total_calories` = sum across days, `avg_daily_calories`/`avg_macros` =
/// average per day).
class WeekNutritionTotals {
  final List<PlanNutritionTotals> perDay;
  final PlanNutritionTotals total;
  final PlanNutritionTotals average;

  const WeekNutritionTotals({
    required this.perDay,
    required this.total,
    required this.average,
  });
}

/// Where a nutrition total sits relative to its target — feeds the "colored
/// deviation indicator" every template/plan/offer-preview surface needs
/// (Faz 3 §3.3). A single shared tolerance band means "under" / "on target" /
/// "over" always means the same thing everywhere, instead of each screen
/// picking its own threshold.
enum NutritionDeviation { under, onTarget, over }

/// Single authority for meal-plan nutrition math (Faz 3 §3.4). Pure and
/// **Firebase-independent by design** (no `cloud_firestore` import, directly
/// or transitively — `MealEntry`/`DishModel` are plain value types) so it
/// gets full, fast unit-test coverage (`test/plan_nutrition_calculator_test.dart`).
///
/// Today, nutrition numbers come from three uncoordinated places — the LLM's
/// own (unverified) totals at generation time, and two hand-rolled
/// recomputation loops that used to live inline in
/// `WeeklyMealPlanService.swapMeal` (one for the swapped day, one for the
/// plan-level rollup) — which is exactly how S7 happened: the day's meals
/// changed but nobody remembered to also update the totals next to them.
/// This class is the first shared, tested authority; `swapMeal` is its first
/// real caller. Future callers (template builder, plan view, offer preview,
/// AI-output validation — where the calculated number wins over the LLM's
/// claimed one) are Faz 3 §3.3/later work, not built here.
class PlanNutritionCalculator {
  PlanNutritionCalculator._();

  /// Totals for one flat list of meal entries — typically one day.
  ///
  /// - An entry with no `dishId` (a free-text/custom-food entry, e.g. user
  ///   typed "elma") contributes **zero**: there is no nutrition data to look
  ///   up for free text. This is a deliberate, silent skip, not an error — a
  ///   custom-food entry is valid and expected, just uncounted.
  /// - A `dishId` that isn't in [dishCatalog] (a deleted dish, or one an
  ///   upstream filter — often `AllergenSafety` — already removed from the
  ///   pool) also contributes zero rather than throwing, mirroring
  ///   `WeeklyMealPlanService.swapMeal`'s pre-existing
  ///   `if (dish == null) continue;` guard.
  /// - `portion` scales every field linearly (1.0 = one serving, as recorded
  ///   on `DishModel`); `MealEntry`'s own constructor already defaults a
  ///   missing portion to 1.0, so it is used as given here.
  static PlanNutritionTotals calculateEntries(
    List<MealEntry> entries,
    Map<String, DishModel> dishCatalog,
  ) {
    var total = PlanNutritionTotals.zero;
    for (final entry in entries) {
      final dishId = entry.dishId;
      if (dishId == null || dishId.isEmpty) continue; // custom/free-text food
      final dish = dishCatalog[dishId];
      if (dish == null) continue; // unresolvable id — skip, don't throw
      total = total +
          PlanNutritionTotals(
            calories: dish.calories,
            protein: dish.protein,
            carbs: dish.carbs,
            fat: dish.fat,
            fiber: dish.fiber,
          ).scaled(entry.portion);
    }
    return total;
  }

  /// Per-day totals for a list of day-shaped entry lists, plus the week-level
  /// sum + average. Convenience wrapper around [calculateEntries] +
  /// [combineDays] for a caller that only has raw entries, not
  /// already-computed per-day totals.
  static WeekNutritionTotals calculateWeek(
    List<List<MealEntry>> days,
    Map<String, DishModel> dishCatalog,
  ) {
    final perDay = days
        .map((day) => calculateEntries(day, dishCatalog))
        .toList(growable: false);
    return combineDays(perDay);
  }

  /// Folds already-computed per-day totals into a week-level sum + average —
  /// for a caller (like `swapMeal`) that computes each day's totals as it
  /// goes and would otherwise have to re-walk every entry a second time (or,
  /// worse, re-implement this exact fold/average itself — the very
  /// duplication this class exists to remove).
  static WeekNutritionTotals combineDays(List<PlanNutritionTotals> perDay) {
    final total = perDay.fold<PlanNutritionTotals>(
        PlanNutritionTotals.zero, (sum, d) => sum + d);
    final average = perDay.isEmpty
        ? PlanNutritionTotals.zero
        : total.scaled(1 / perDay.length);
    return WeekNutritionTotals(perDay: perDay, total: total, average: average);
  }

  /// Classifies [actual] against [target] using a symmetric ±[tolerance]
  /// band (default 10%, matching the tolerance the AI-alternates prompt
  /// already implies for "close to target" macro math). A non-positive
  /// [target] (no goal set yet) always reads as [NutritionDeviation.onTarget]
  /// — there is nothing to deviate FROM, so the UI shouldn't paint a plan red
  /// or amber before the author has even set a goal.
  static NutritionDeviation classifyDeviation(
    double actual,
    double target, {
    double tolerance = 0.10,
  }) {
    if (target <= 0) return NutritionDeviation.onTarget;
    final lower = target * (1 - tolerance);
    final upper = target * (1 + tolerance);
    if (actual < lower) return NutritionDeviation.under;
    if (actual > upper) return NutritionDeviation.over;
    return NutritionDeviation.onTarget;
  }
}
