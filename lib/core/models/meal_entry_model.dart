/// A single meal slot inside a `meal_plan_templates/{id}.days[]` entry
/// (Faz 3 §3.2). Replaces the bare `Map<String,String>` (mealType → dishId)
/// shape `DayMealPlan.meals` still uses today, which can only ever represent
/// one dish per meal type at a fixed portion of 1 — no free-text food, no
/// scaling, no per-meal note.
///
/// Deliberately has **no Firebase import** — it is a plain value type read by
/// [PlanNutritionCalculator] (`lib/core/utils/plan_nutrition_calculator.dart`),
/// which must stay Firebase-independent for full, fast unit-test coverage.
/// `meal_plan_template_model.dart` (which DOES import `cloud_firestore` for
/// `Timestamp`) is the only place that wraps this into a Firestore doc shape.
class MealEntry {
  /// References `dishes/{dishId}` — null for a free-text/custom entry.
  final String? dishId;

  /// Free-text food name (e.g. "elma") when there's no catalog dish to point
  /// at. At most one of [dishId]/[customFood] is meaningful at a time; both
  /// being null/empty is a malformed-but-tolerated empty slot.
  final String? customFood;

  /// Serving multiplier against the dish's per-serving nutrition (1.0 = one
  /// serving, as recorded on `DishModel`). Meaningless for a custom-food
  /// entry (no nutrition data to scale), but still stored for portion text
  /// like "2 dilim" a future UI might render.
  final double portion;

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'. Carried on the entry itself
  /// (unlike the old Map's mealType-as-key), so a day can hold more than one
  /// snack — the old shape could only ever have one entry per meal type.
  final String mealType;

  final String? note;

  const MealEntry({
    this.dishId,
    this.customFood,
    this.portion = 1.0,
    required this.mealType,
    this.note,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      dishId: json['dish_id'] as String?,
      customFood: json['custom_food'] as String?,
      portion: (json['portion'] as num?)?.toDouble() ?? 1.0,
      mealType: json['meal_type'] as String? ?? 'lunch',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dish_id': dishId,
        'custom_food': customFood,
        'portion': portion,
        'meal_type': mealType,
        'note': note,
      };

  MealEntry copyWith({
    String? dishId,
    String? customFood,
    double? portion,
    String? mealType,
    String? note,
  }) {
    return MealEntry(
      dishId: dishId ?? this.dishId,
      customFood: customFood ?? this.customFood,
      portion: portion ?? this.portion,
      mealType: mealType ?? this.mealType,
      note: note ?? this.note,
    );
  }
}
