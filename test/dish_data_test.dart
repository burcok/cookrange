import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/data/dish_data.dart';

/// Faz 3 §3.6 — pure data-integrity checks on the dish seed catalog. No
/// Firebase dependency (ADR-004), so this can actually run: it regression-
/// proofs the three concrete defects this task fixed directly in the
/// source data, rather than relying on someone noticing them by eye again.
void main() {
  group('Dish catalog data integrity', () {
    test(
        'every dish id is unique — a repeated id silently overwrites another '
        'dish\'s Firestore document when seeded (found: 7 collisions across '
        '5 ids before this fix, seeding only 68 of 75 dishes)', () {
      final ids = allDishes.map((d) => d['id'] as String).toList();
      final dupes = ids
          .toSet()
          .where((id) => ids.where((x) => x == id).length > 1)
          .toSet();
      expect(dupes, isEmpty, reason: 'Duplicate dish id(s): $dupes');
      expect(ids.toSet().length, ids.length);
    });

    test(
        'snack (ara öğün) pool has at least 25 dishes — the template '
        'builder (§3.3) draws 7 snack slots/week from this exact pool; a '
        'pool of 3 forced the same snacks every single day', () {
      final snackCount =
          allDishes.where((d) => d['meal_type'] == 'snack').length;
      expect(snackCount, greaterThanOrEqualTo(25));
    });

    test(
        'every dish category is one DishModel.category\'s doc comment '
        'documents as valid — the comment used to claim red_meat/vegan/diet, '
        'none of which the real data ever uses', () {
      const validCategories = {
        'breakfast',
        'chicken',
        'fish',
        'meat',
        'sport',
        'turkish_classic',
        'vegetarian',
        'veggie',
      };
      final invalid = allDishes
          .map((d) => d['category'] as String)
          .where((c) => !validCategories.contains(c))
          .toSet();
      expect(invalid, isEmpty, reason: 'Unknown category value(s): $invalid');
    });

    test('catalog has not shrunk below the pre-§3.6 baseline of 75 dishes', () {
      expect(allDishes.length, greaterThanOrEqualTo(75));
    });

    test(
        'every snack\'s ingredient calories sum to its declared total — '
        'scoped to snacks (not the whole catalog) because several '
        'pre-existing non-snack dishes already have large, unrelated '
        'mismatches here (e.g. 100%+); this only guards the new content', () {
      final snacks = allDishes.where((d) => d['meal_type'] == 'snack');
      for (final d in snacks) {
        final declared = (d['calories'] as num).toDouble();
        final ingredients = d['ingredients'] as List;
        final sum = ingredients.fold<double>(
            0, (acc, i) => acc + ((i['calories'] as num?)?.toDouble() ?? 0));
        expect(sum, closeTo(declared, 1),
            reason: 'Snack ${d['id']}: ingredients sum to $sum but '
                'calories declared as $declared');
      }
    });
  });
}
