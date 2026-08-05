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

  group('AllergenSafety - real onboarding "allergy_*" ids', () {
    // Onboarding (lib/core/constants/onboarding_options.dart) stores the
    // user's declared allergies with an "allergy_" prefix, e.g.
    // "allergy_wheat" — not the bare "wheat"/"gluten" category label. Every
    // one of the 9 stored ids must expand to its category's synonym terms.
    test('every stored onboarding allergy id expands to its category terms',
        () {
      final expectations = <String, String>{
        'allergy_dairy': 'milk',
        'allergy_eggs': 'egg',
        'allergy_fish': 'salmon',
        'allergy_shellfish': 'shrimp',
        'allergy_tree_nuts': 'almond',
        'allergy_peanuts': 'peanut',
        'allergy_wheat': 'flour',
        'allergy_soy': 'tofu',
        'allergy_sesame': 'tahini',
      };
      expectations.forEach((id, expectedTerm) {
        final terms = AllergenSafety.buildUnsafeTerms(
            allergyIds: [id], avoidIngredients: []);
        expect(terms.contains(expectedTerm), true,
            reason: '"$id" should expand to include "$expectedTerm"');
      });
    });

    // Regression test for the gluten/wheat synonym-key mismatch: the
    // `_synonyms` map's whole-grain group was keyed only as 'gluten', which
    // is never a substring of the stored id "allergy_wheat", so the group
    // never expanded for a declared wheat allergy (unlike the other 8
    // allergens, whose synonym key IS a substring of their stored id).
    test('allergy_wheat expands to the full gluten/wheat term set', () {
      final terms = AllergenSafety.buildUnsafeTerms(
          allergyIds: ['allergy_wheat'], avoidIngredients: []);
      for (final term in [
        'gluten',
        'wheat',
        'flour',
        'bread',
        'barley',
        'rye',
        'pasta',
        'bulgur',
        'buğday',
        'ekmek',
        'makarna',
        'arpa',
      ]) {
        expect(terms.contains(term), true, reason: 'missing "$term"');
      }
    });

    test(
        'filterSafe removes a dish whose only wheat signal is a Turkish '
        '"buğday" ingredient (e.g. whole-wheat pasta) for allergy_wheat', () {
      final dishes = [
        _dish('Ev Yapımı Soslu Etli Makarna', [
          'Tam Buğday Penne/Burgu Makarna',
          'Dana Kuşbaşı',
          'Taze Domates Sosu',
        ]),
        _dish('Izgara Tavuk & Sebze', ['Tavuk Göğsü', 'Zeytinyağı', 'Kabak']),
      ];
      final safe = AllergenSafety.filterSafe(dishes,
          allergyIds: ['allergy_wheat'], avoidIngredients: []);
      expect(safe.map((d) => d.name).toList(), ['Izgara Tavuk & Sebze']);
    });

    test(
        'filterSafe removes a dish whose only wheat signal is the English '
        '"flour" ingredient for allergy_wheat', () {
      final dishes = [
        _dish('Pancakes', ['Flour', 'Milk', 'Egg']),
        _dish('Rice Bowl', ['Rice', 'Chicken', 'Vegetables']),
      ];
      final safe = AllergenSafety.filterSafe(dishes,
          allergyIds: ['allergy_wheat'], avoidIngredients: []);
      expect(safe.map((d) => d.name).toList(), ['Rice Bowl']);
    });

    test(
        'known limitation (documented, not a regression target): a bare '
        '2-letter "Un" (Turkish "flour") ingredient in isolation is not '
        'matched — terms under 3 chars are dropped to avoid false '
        'positives on unrelated words that merely contain "un" as a '
        'substring (e.g. "Yunan Yoğurdu"/Greek yogurt, "Yulaf Unu"/oat '
        'flour, "Muz (Olgun)"/ripe banana, "Olgun Avokado"/ripe avocado — '
        'all present in the real dish catalog). Every real wheat-flour '
        'ingredient in the catalog spells out "buğday" or "ekmek" '
        'alongside "un" (e.g. "Tam Buğday Unu"), so this is not a '
        'practical gap today — see the two tests above.', () {
      final dishes = [
        _dish('Sadece Un', ['Un']),
      ];
      final safe = AllergenSafety.filterSafe(dishes,
          allergyIds: ['allergy_wheat'], avoidIngredients: []);
      expect(safe.length, 1);
    });
  });
}
