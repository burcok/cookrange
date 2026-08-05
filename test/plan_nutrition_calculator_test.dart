import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/dish_model.dart';
import 'package:cookrange/core/models/meal_entry_model.dart';
import 'package:cookrange/core/utils/plan_nutrition_calculator.dart';

DishModel _dish(
  String id, {
  double calories = 100,
  double protein = 10,
  double carbs = 10,
  double fat = 5,
  double fiber = 2,
}) {
  final now = DateTime.now();
  return DishModel(
    id: id,
    name: id,
    nameEn: id,
    description: '',
    descriptionEn: '',
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    fiber: fiber,
    category: 'x',
    tags: const [],
    mealType: 'lunch',
    prepTimeMinutes: 5,
    cookTimeMinutes: 5,
    difficulty: 'easy',
    ingredients: const [],
    instructions: const [],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PlanNutritionCalculator.calculateEntries', () {
    test('empty entry list returns zero, no crash', () {
      final totals = PlanNutritionCalculator.calculateEntries([], {});
      expect(totals.calories, 0);
      expect(totals.protein, 0);
      expect(totals.carbs, 0);
      expect(totals.fat, 0);
      expect(totals.fiber, 0);
    });

    test('sums multiple dishes at portion 1.0', () {
      final catalog = {
        'a': _dish('a',
            calories: 300, protein: 20, carbs: 30, fat: 10, fiber: 4),
        'b': _dish('b',
            calories: 500, protein: 25, carbs: 60, fat: 15, fiber: 6),
      };
      final entries = [
        const MealEntry(dishId: 'a', mealType: 'breakfast'),
        const MealEntry(dishId: 'b', mealType: 'lunch'),
      ];
      final totals = PlanNutritionCalculator.calculateEntries(entries, catalog);
      expect(totals.calories, closeTo(800, 0.001));
      expect(totals.protein, closeTo(45, 0.001));
      expect(totals.carbs, closeTo(90, 0.001));
      expect(totals.fat, closeTo(25, 0.001));
      expect(totals.fiber, closeTo(10, 0.001));
    });

    test('portion scaling: 2x portion doubles every field, 0.5x halves it', () {
      final catalog = {
        'a':
            _dish('a', calories: 400, protein: 20, carbs: 40, fat: 10, fiber: 8)
      };
      final doublePortion = PlanNutritionCalculator.calculateEntries(
        [const MealEntry(dishId: 'a', mealType: 'lunch', portion: 2.0)],
        catalog,
      );
      expect(doublePortion.calories, closeTo(800, 0.001));
      expect(doublePortion.protein, closeTo(40, 0.001));
      expect(doublePortion.fiber, closeTo(16, 0.001));

      final halfPortion = PlanNutritionCalculator.calculateEntries(
        [const MealEntry(dishId: 'a', mealType: 'lunch', portion: 0.5)],
        catalog,
      );
      expect(halfPortion.calories, closeTo(200, 0.001));
      expect(halfPortion.protein, closeTo(10, 0.001));
      expect(halfPortion.fiber, closeTo(4, 0.001));
    });

    test('a default (unspecified) portion is treated as 1.0', () {
      final catalog = {'a': _dish('a', calories: 250)};
      final totals = PlanNutritionCalculator.calculateEntries(
        [const MealEntry(dishId: 'a', mealType: 'lunch')],
        catalog,
      );
      expect(totals.calories, closeTo(250, 0.001));
    });

    test(
        'custom/free-text food entries (no dishId) contribute zero, not an error',
        () {
      final catalog = {'a': _dish('a', calories: 300)};
      final entries = [
        const MealEntry(dishId: 'a', mealType: 'breakfast'),
        const MealEntry(customFood: 'elma', mealType: 'snack', portion: 1.0),
      ];
      final totals = PlanNutritionCalculator.calculateEntries(entries, catalog);
      // Only the catalog dish counts — the free-text "elma" entry is silently
      // uncounted (no nutrition data exists for it), not a crash or a
      // rejected calculation.
      expect(totals.calories, closeTo(300, 0.001));
    });

    test(
        'an entry with an empty-string dishId is treated the same as no dishId',
        () {
      final totals = PlanNutritionCalculator.calculateEntries(
        [const MealEntry(dishId: '', mealType: 'snack')],
        {'a': _dish('a', calories: 300)},
      );
      expect(totals.calories, 0);
    });

    test(
        'allergen-adjacent: a dishId not present in the catalog (deleted, or '
        'already filtered out upstream by AllergenSafety) contributes zero, '
        'does not throw', () {
      final catalog = {'a': _dish('a', calories: 300)};
      final entries = [
        const MealEntry(dishId: 'a', mealType: 'breakfast'),
        const MealEntry(dishId: 'does_not_exist', mealType: 'lunch'),
      ];
      expect(
        () => PlanNutritionCalculator.calculateEntries(entries, catalog),
        returnsNormally,
      );
      final totals = PlanNutritionCalculator.calculateEntries(entries, catalog);
      expect(totals.calories, closeTo(300, 0.001));
    });

    test(
        'an entirely empty dish catalog (e.g. every candidate filtered out) '
        'yields all zeros for any entries', () {
      final entries = [
        const MealEntry(dishId: 'a', mealType: 'breakfast'),
        const MealEntry(dishId: 'b', mealType: 'lunch'),
      ];
      final totals = PlanNutritionCalculator.calculateEntries(entries, {});
      expect(totals.calories, 0);
      expect(totals.fiber, 0);
    });

    test(
        'swap: recomputing after swapping one meal slot reflects the NEW '
        'dish, not a stale copy of the old totals (S7 regression guard)', () {
      final catalog = {
        'breakfast_light': _dish('breakfast_light',
            calories: 300, protein: 10, carbs: 30, fat: 8),
        'breakfast_heavy': _dish('breakfast_heavy',
            calories: 800, protein: 30, carbs: 90, fat: 30),
        'lunch': _dish('lunch', calories: 600, protein: 35, carbs: 60, fat: 20),
      };

      final before = PlanNutritionCalculator.calculateEntries([
        const MealEntry(dishId: 'breakfast_light', mealType: 'breakfast'),
        const MealEntry(dishId: 'lunch', mealType: 'lunch'),
      ], catalog);
      expect(before.calories, closeTo(900, 0.001));

      // Swap breakfast_light -> breakfast_heavy, exactly what swapMeal does
      // to the meals map before recomputing.
      final after = PlanNutritionCalculator.calculateEntries([
        const MealEntry(dishId: 'breakfast_heavy', mealType: 'breakfast'),
        const MealEntry(dishId: 'lunch', mealType: 'lunch'),
      ], catalog);
      expect(after.calories, closeTo(1400, 0.001));
      expect(after.calories, isNot(closeTo(before.calories, 0.001)));
    });
  });

  group('PlanNutritionCalculator.calculateWeek / combineDays', () {
    test(
        'empty days list returns zero total and zero average (no divide-by-zero)',
        () {
      final week = PlanNutritionCalculator.calculateWeek([], {});
      expect(week.perDay, isEmpty);
      expect(week.total.calories, 0);
      expect(week.average.calories, 0);
    });

    test('sums across days for the total, averages per day for the average',
        () {
      final catalog = {
        'a': _dish('a',
            calories: 1000, protein: 60, carbs: 100, fat: 30, fiber: 10),
      };
      final days = List.generate(
        4,
        (_) => [const MealEntry(dishId: 'a', mealType: 'lunch')],
      );
      final week = PlanNutritionCalculator.calculateWeek(days, catalog);
      expect(week.perDay.length, 4);
      expect(week.total.calories, closeTo(4000, 0.001));
      expect(week.average.calories, closeTo(1000, 0.001));
      expect(week.average.fiber, closeTo(10, 0.001));
    });

    test(
        'an empty day (rest day / no meals logged) contributes zero without '
        'skewing the day count used for the average', () {
      final catalog = {'a': _dish('a', calories: 1000)};
      final days = [
        [const MealEntry(dishId: 'a', mealType: 'lunch')],
        <MealEntry>[], // empty day
      ];
      final week = PlanNutritionCalculator.calculateWeek(days, catalog);
      expect(week.perDay.length, 2);
      expect(week.total.calories, closeTo(1000, 0.001));
      expect(week.average.calories, closeTo(500, 0.001)); // 1000 / 2 days
    });

    test(
        'combineDays folds already-computed per-day totals identically to '
        'calculateWeek (the path swapMeal actually calls, to avoid a second '
        'dish-catalog walk)', () {
      const perDay = [
        PlanNutritionTotals(
            calories: 1800, protein: 100, carbs: 200, fat: 60, fiber: 20),
        PlanNutritionTotals(
            calories: 2200, protein: 120, carbs: 250, fat: 70, fiber: 25),
      ];
      final week = PlanNutritionCalculator.combineDays(perDay);
      expect(week.total.calories, closeTo(4000, 0.001));
      expect(week.average.calories, closeTo(2000, 0.001));
      expect(week.average.protein, closeTo(110, 0.001));
      expect(week.average.fiber, closeTo(22.5, 0.001));
    });

    test('combineDays with an empty list returns zero, not NaN', () {
      final week = PlanNutritionCalculator.combineDays([]);
      expect(week.total.calories, 0);
      expect(week.average.calories, 0);
    });
  });

  group('PlanNutritionTotals', () {
    test('zero constant is all-zero', () {
      expect(PlanNutritionTotals.zero.calories, 0);
      expect(PlanNutritionTotals.zero.protein, 0);
      expect(PlanNutritionTotals.zero.carbs, 0);
      expect(PlanNutritionTotals.zero.fat, 0);
      expect(PlanNutritionTotals.zero.fiber, 0);
    });

    test('+ operator adds every field independently', () {
      const a = PlanNutritionTotals(
          calories: 100, protein: 10, carbs: 20, fat: 5, fiber: 3);
      const b = PlanNutritionTotals(
          calories: 200, protein: 15, carbs: 25, fat: 8, fiber: 4);
      final sum = a + b;
      expect(sum.calories, 300);
      expect(sum.protein, 25);
      expect(sum.carbs, 45);
      expect(sum.fat, 13);
      expect(sum.fiber, 7);
    });

    test('scaled multiplies every field by the same factor', () {
      const a = PlanNutritionTotals(
          calories: 100, protein: 10, carbs: 20, fat: 5, fiber: 3);
      final scaled = a.scaled(1.5);
      expect(scaled.calories, closeTo(150, 0.001));
      expect(scaled.protein, closeTo(15, 0.001));
      expect(scaled.fiber, closeTo(4.5, 0.001));
    });

    test(
        'macros getter exposes exactly protein/carbs/fat — not fiber — '
        'matching DayMealPlan.macros\' existing 3-key shape', () {
      const a = PlanNutritionTotals(
          calories: 100, protein: 10, carbs: 20, fat: 5, fiber: 3);
      expect(a.macros.keys.toSet(), {'protein', 'carbs', 'fat'});
      expect(a.macros['protein'], 10);
      expect(a.macros['carbs'], 20);
      expect(a.macros['fat'], 5);
    });
  });

  group('PlanNutritionCalculator.classifyDeviation (Faz 3 §3.3)', () {
    test('exact target is onTarget', () {
      expect(PlanNutritionCalculator.classifyDeviation(2000, 2000),
          NutritionDeviation.onTarget);
    });

    test('within default ±10% band is onTarget', () {
      expect(PlanNutritionCalculator.classifyDeviation(2090, 2000),
          NutritionDeviation.onTarget);
      expect(PlanNutritionCalculator.classifyDeviation(1910, 2000),
          NutritionDeviation.onTarget);
    });

    test('exactly on the band edge is onTarget (inclusive)', () {
      expect(PlanNutritionCalculator.classifyDeviation(2200, 2000),
          NutritionDeviation.onTarget);
      expect(PlanNutritionCalculator.classifyDeviation(1800, 2000),
          NutritionDeviation.onTarget);
    });

    test('just past the upper band is over', () {
      expect(PlanNutritionCalculator.classifyDeviation(2201, 2000),
          NutritionDeviation.over);
    });

    test('just past the lower band is under', () {
      expect(PlanNutritionCalculator.classifyDeviation(1799, 2000),
          NutritionDeviation.under);
    });

    test('zero actual against a real target is under, not a crash', () {
      expect(PlanNutritionCalculator.classifyDeviation(0, 2000),
          NutritionDeviation.under);
    });

    test('non-positive target always reads onTarget — no goal set yet', () {
      expect(PlanNutritionCalculator.classifyDeviation(5000, 0),
          NutritionDeviation.onTarget);
      expect(PlanNutritionCalculator.classifyDeviation(5000, -10),
          NutritionDeviation.onTarget);
    });

    test('custom tolerance narrows the band', () {
      expect(
          PlanNutritionCalculator.classifyDeviation(2101, 2000,
              tolerance: 0.05),
          NutritionDeviation.over);
      expect(
          PlanNutritionCalculator.classifyDeviation(2099, 2000,
              tolerance: 0.05),
          NutritionDeviation.onTarget);
    });
  });
}
