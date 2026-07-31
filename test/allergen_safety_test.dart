import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/dish_model.dart';
import 'package:cookrange/core/models/ingredient_model.dart';
import 'package:cookrange/core/utils/allergen_safety.dart';

DishModel _dish(String name, List<String> ingredientNames) {
  final now = DateTime.now();
  return DishModel(
    id: name,
    name: name,
    nameEn: name,
    description: '',
    descriptionEn: '',
    calories: 100,
    protein: 1,
    carbs: 1,
    fat: 1,
    category: 'x',
    tags: const [],
    mealType: 'lunch',
    prepTimeMinutes: 5,
    cookTimeMinutes: 5,
    difficulty: 'easy',
    ingredients: ingredientNames
        .map((n) => Ingredient(name: n, amount: 1, unit: 'g', calories: 1))
        .toList(),
    instructions: const [],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AllergenSafety', () {
    test('expands allergy categories (dairy → milk)', () {
      final terms = AllergenSafety.buildUnsafeTerms(
          allergyIds: ['dairy'], avoidIngredients: []);
      expect(terms.contains('milk'), true);
    });

    test('includes literal avoid-ingredient terms', () {
      final terms = AllergenSafety.buildUnsafeTerms(
          allergyIds: [], avoidIngredients: ['peanut butter']);
      expect(terms.any((t) => t.contains('peanut')), true);
    });

    test('empty inputs → no unsafe terms', () {
      expect(
          AllergenSafety.buildUnsafeTerms(allergyIds: [], avoidIngredients: []),
          isEmpty);
    });

    test('filterSafe removes dishes containing a declared allergen', () {
      final dishes = [
        _dish('Latte', ['Milk', 'Coffee']),
        _dish('Black Coffee', ['Coffee', 'Water']),
      ];
      final safe = AllergenSafety.filterSafe(dishes,
          allergyIds: ['dairy'], avoidIngredients: []);
      expect(safe.map((d) => d.name).toList(), ['Black Coffee']);
    });

    test('no allergens → all dishes pass', () {
      final dishes = [
        _dish('A', ['Milk']),
        _dish('B', ['Egg']),
      ];
      final safe = AllergenSafety.filterSafe(dishes,
          allergyIds: [], avoidIngredients: []);
      expect(safe.length, 2);
    });
  });
}
