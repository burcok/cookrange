import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/meal_entry_model.dart';
import 'package:cookrange/core/utils/template_plan_adapter.dart';

void main() {
  group('TemplatePlanAdapter.collapseMealsToLegacyMap', () {
    test('empty list returns empty map', () {
      expect(TemplatePlanAdapter.collapseMealsToLegacyMap(const []),
          <String, String>{});
    });

    test('one entry per meal type maps cleanly', () {
      final meals = [
        const MealEntry(dishId: 'd1', mealType: 'breakfast'),
        const MealEntry(dishId: 'd2', mealType: 'lunch'),
        const MealEntry(dishId: 'd3', mealType: 'dinner'),
      ];
      final map = TemplatePlanAdapter.collapseMealsToLegacyMap(meals);
      expect(map, {'breakfast': 'd1', 'lunch': 'd2', 'dinner': 'd3'});
    });

    test('custom-food (no dishId) entries are dropped, not crashed on', () {
      final meals = [
        const MealEntry(dishId: 'd1', mealType: 'breakfast'),
        const MealEntry(customFood: 'elma', mealType: 'snack'),
      ];
      final map = TemplatePlanAdapter.collapseMealsToLegacyMap(meals);
      expect(map, {'breakfast': 'd1'});
      expect(map.containsKey('snack'), isFalse);
    });

    test('an empty-string dishId is treated the same as null (dropped)', () {
      final meals = [
        const MealEntry(dishId: '', mealType: 'snack'),
      ];
      expect(TemplatePlanAdapter.collapseMealsToLegacyMap(meals),
          <String, String>{});
    });

    test('two entries for the same meal type: the LAST one wins', () {
      final meals = [
        const MealEntry(dishId: 'snack_a', mealType: 'snack'),
        const MealEntry(dishId: 'snack_b', mealType: 'snack'),
      ];
      final map = TemplatePlanAdapter.collapseMealsToLegacyMap(meals);
      expect(map['snack'], 'snack_b');
      expect(map.length, 1);
    });
  });

  group('TemplatePlanAdapter.weekdayName', () {
    test('maps 0..6 to Monday..Sunday', () {
      expect(TemplatePlanAdapter.weekdayName(0), 'Monday');
      expect(TemplatePlanAdapter.weekdayName(1), 'Tuesday');
      expect(TemplatePlanAdapter.weekdayName(2), 'Wednesday');
      expect(TemplatePlanAdapter.weekdayName(3), 'Thursday');
      expect(TemplatePlanAdapter.weekdayName(4), 'Friday');
      expect(TemplatePlanAdapter.weekdayName(5), 'Saturday');
      expect(TemplatePlanAdapter.weekdayName(6), 'Sunday');
    });

    test('out-of-range indices clamp instead of throwing', () {
      expect(TemplatePlanAdapter.weekdayName(-1), 'Monday');
      expect(TemplatePlanAdapter.weekdayName(99), 'Sunday');
    });
  });
}
