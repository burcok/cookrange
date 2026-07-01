import '../models/dish_model.dart';

/// Deterministic, life-safety allergen filtering.
///
/// AI prompts *ask* the model to avoid allergens, but an LLM can ignore or
/// mis-handle that instruction. This utility enforces the rule in code: it
/// removes any dish whose name or ingredient list matches a user-declared
/// allergen / avoid-ingredient, so the model can only ever pick from a pool
/// that is already safe (it selects dishes by ID from the provided list).
///
/// Matching is case-insensitive substring on the dish name (TR + EN) and every
/// ingredient name, expanded with a small EN/TR synonym map for the common
/// allergen categories (the user's stored allergy keys are often category
/// labels like "dairy"/"gluten" that won't literally appear in an ingredient
/// name like "Milk"/"Wheat Flour"). This is a safety *backstop*, not a complete
/// allergen ontology — extend [_synonyms] as the dish catalog grows.
class AllergenSafety {
  AllergenSafety._();

  /// Common allergen category → concrete ingredient terms (EN + TR), lower-case.
  static const Map<String, List<String>> _synonyms = {
    'gluten': ['gluten', 'wheat', 'flour', 'bread', 'barley', 'rye', 'pasta',
        'bulgur', 'buğday', 'un', 'ekmek', 'makarna', 'arpa'],
    'dairy': ['dairy', 'milk', 'cheese', 'butter', 'yogurt', 'yoghurt', 'cream',
        'lactose', 'süt', 'peynir', 'tereyağ', 'yoğurt', 'krema', 'laktoz'],
    'lactose': ['milk', 'cheese', 'butter', 'yogurt', 'cream', 'süt', 'peynir',
        'yoğurt'],
    'nuts': ['nut', 'peanut', 'almond', 'walnut', 'hazelnut', 'cashew',
        'pistachio', 'fındık', 'fıstık', 'badem', 'ceviz', 'kaju', 'antep'],
    'peanut': ['peanut', 'yer fıstığı', 'fıstık'],
    'tree_nuts': ['almond', 'walnut', 'hazelnut', 'cashew', 'pistachio',
        'badem', 'ceviz', 'fındık', 'antep fıstığı'],
    'egg': ['egg', 'yumurta', 'mayonnaise', 'mayonez'],
    'eggs': ['egg', 'yumurta'],
    'shellfish': ['shrimp', 'prawn', 'crab', 'lobster', 'shellfish', 'karides',
        'yengeç', 'istakoz', 'midye', 'mussel'],
    'fish': ['fish', 'salmon', 'tuna', 'anchovy', 'balık', 'somon', 'ton',
        'hamsi', 'levrek'],
    'soy': ['soy', 'soya', 'tofu', 'edamame'],
    'sesame': ['sesame', 'tahini', 'susam', 'tahin'],
  };

  /// Expands a raw user term (e.g. an allergy key like "dairy" or a typed
  /// ingredient like "peanut butter") into the set of lower-case match terms.
  static Set<String> _expand(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return const {};
    final out = <String>{t};
    // Normalise snake_case / spaced keys and add token parts.
    for (final part in t.split(RegExp(r'[\s_\-/,]+'))) {
      if (part.length >= 3) out.add(part);
    }
    for (final entry in _synonyms.entries) {
      if (t == entry.key || t.contains(entry.key)) {
        out.addAll(entry.value);
      }
    }
    // Drop very short tokens that would cause false positives.
    out.removeWhere((s) => s.length < 3);
    return out;
  }

  /// Builds the full set of unsafe match terms from the user's declared
  /// allergies + avoid-ingredients (preferences/dislikes are NOT included —
  /// only safety-relevant inputs).
  static Set<String> buildUnsafeTerms({
    required List<String> allergyIds,
    required List<String> avoidIngredients,
  }) {
    final terms = <String>{};
    for (final a in [...allergyIds, ...avoidIngredients]) {
      terms.addAll(_expand(a));
    }
    return terms;
  }

  /// True if [dish] contains any of the [unsafeTerms].
  static bool dishIsUnsafe(DishModel dish, Set<String> unsafeTerms) {
    if (unsafeTerms.isEmpty) return false;
    final haystack = StringBuffer()
      ..write(dish.name.toLowerCase())
      ..write(' ')
      ..write(dish.nameEn.toLowerCase());
    for (final ing in dish.ingredients) {
      haystack..write(' ')..write(ing.name.toLowerCase());
    }
    final hay = haystack.toString();
    for (final term in unsafeTerms) {
      if (hay.contains(term)) return true;
    }
    return false;
  }

  /// Returns only the dishes that are safe for the given allergy/avoid inputs.
  static List<DishModel> filterSafe(
    List<DishModel> dishes, {
    required List<String> allergyIds,
    required List<String> avoidIngredients,
  }) {
    final unsafe = buildUnsafeTerms(
      allergyIds: allergyIds,
      avoidIngredients: avoidIngredients,
    );
    if (unsafe.isEmpty) return dishes;
    return dishes.where((d) => !dishIsUnsafe(d, unsafe)).toList();
  }
}
