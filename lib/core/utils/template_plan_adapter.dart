import '../models/meal_entry_model.dart';

/// Faz 3 §3.5 — adapts a `MealPlanTemplate`'s days (`List<MealEntry>`, which
/// can hold multiple entries per meal type, portions, and free-text/custom
/// food) into the legacy `DayMealPlan.meals` shape (`Map<String,String>`,
/// mealType -> dishId) that the LIVE `meal_plans/current` doc still uses.
///
/// Pure and **Firebase-independent by design** (no `cloud_firestore` import,
/// directly or transitively), so it gets full, fast unit-test coverage
/// (`test/template_plan_adapter_test.dart`) — the same discipline
/// `PlanNutritionCalculator` already established for this file's neighbor.
///
/// **Why this conversion exists at all, and what it deliberately loses:**
/// `DayMealPlan.meals`/`WeeklyMealPlanModel` were NOT migrated to the richer
/// `MealEntry` shape in Faz 3 §3.2/§3.4 (confirmed by reading
/// `WeeklyMealPlanService.swapMeal`, which still reads/writes
/// `Map<String,String>` today) — only `MealPlanTemplate` got the richer type.
/// Accepting an offer (§3.5) is therefore the first place a `MealEntry` list
/// has to be squeezed back down into the older shape, and that squeeze is
/// lossy in two specific, deliberate, documented ways:
/// - A **custom-food entry** (`dishId == null`) has nothing for
///   `Map<String,String>` to hold (it only ever maps mealType -> a dish id)
///   — it is silently dropped from the legacy `meals` map.
/// - **Two-or-more entries for the SAME meal type on the same day** (a
///   template day can legitimately have two snacks — `MealEntry`'s own doc
///   comment calls this out as new, intentional capability) collapse to
///   ONE slot; the LAST entry for that meal type wins, matching plain
///   `Map` construction semantics rather than inventing a silent
///   first-wins rule.
///
/// **This does NOT affect the numbers.** Whoever calls this MUST compute
/// `total_calories`/`macros`/`fiber` from the ORIGINAL, full-fidelity
/// `List<MealEntry>` via `PlanNutritionCalculator` (which has no such
/// blind spot) — never by re-deriving totals from this method's lossy
/// output. `WeeklyMealPlanService.adoptTemplate` does exactly that: this
/// class only ever supplies the per-slot `meals` map for legacy rendering,
/// not the totals.
class TemplatePlanAdapter {
  TemplatePlanAdapter._();

  /// mealType -> dishId. See class doc for the two documented, deliberate
  /// lossy cases (custom-food entries dropped; same-mealType duplicates
  /// resolve last-wins).
  static Map<String, String> collapseMealsToLegacyMap(List<MealEntry> meals) {
    final out = <String, String>{};
    for (final entry in meals) {
      final dishId = entry.dishId;
      if (dishId == null || dishId.isEmpty) continue; // custom food — dropped
      out[entry.mealType] = dishId;
    }
    return out;
  }

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// English weekday name for a template's 0=Monday..6=Sunday [dayIndex] —
  /// matches `DayMealPlan.dayName`'s existing convention ("Monday, Tuesday,
  /// etc.", verified unused by any renderer today — `home.dart`'s day
  /// selector derives its own label from `date` via `DateFormat`, not this
  /// field — so correctness here is about schema consistency, not display).
  /// Out-of-range indices clamp rather than throw, since a malformed
  /// template shouldn't crash an accept flow over a cosmetic field.
  static String weekdayName(int dayIndex) {
    if (dayIndex < 0) return _weekdayNames.first;
    if (dayIndex >= _weekdayNames.length) return _weekdayNames.last;
    return _weekdayNames[dayIndex];
  }
}
