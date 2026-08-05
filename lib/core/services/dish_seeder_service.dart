import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/dish_model.dart';
import '../models/ingredient_model.dart';
import '../data/dish_data.dart';
import 'crashlytics_service.dart';
import 'dish_image_service.dart';

class DishSeederService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DishImageService _imageService = DishImageService();

  Future<void> seedAllDishes({bool forceUpdateImages = false}) async {
    return seedDishes(allDishes, forceUpdateImages: forceUpdateImages);
  }

  Future<void> seedDishes(List<Map<String, dynamic>> items,
      {bool forceUpdateImages = false}) async {
    int successCount = 0;
    int failCount = 0;

    debugPrint('Starting dish seeding for ${items.length} items...');

    for (final dishData in items) {
      try {
        final String id = dishData['id'];
        final String nameEn = dishData['name_en'];

        // 1. Check if image exists or needs update
        String? imageUrl = dishData['image_url'];

        // If no image url in data, or forced update, try to fetch
        if (imageUrl == null || imageUrl.isEmpty || forceUpdateImages) {
          // List of common descriptive words to filter out for better image searching
          final adjectives = [
            'traditional',
            'grilled',
            'roasted',
            'baked',
            'tender',
            'hearty',
            'fresh',
            'fit',
            'healthy',
            'home',
            'made',
            'gourmet',
            'premium',
            'slow-cooked',
            'fried',
            'steamed',
            'seared',
            'rich',
            'classic',
            'delicious',
            'authentic',
            'spicy',
            'sweet',
            'savory',
            'crispy',
            'crunchy',
            'juicy',
            'creamy',
            'homemade',
            'style',
            'special',
            'turkish',
            'ottoman',
            'village',
            'pure',
            'natural',
            'organic'
          ];

          String sanitizeForSearch(String text) {
            String sanitized = text
                .split(RegExp(r'[&,()]'))
                .first
                .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
                .toLowerCase();

            // Remove common adjectives (whole words only)
            for (var adj in adjectives) {
              sanitized = sanitized.replaceAll(RegExp('\\b$adj\\b'), '');
            }
            return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
          }

          final cleanName = sanitizeForSearch(nameEn);

          final queries = <String>[
            cleanName, // Cleaned name without adjectives
            // Try only the first two words if there are many (usually the main dish)
            cleanName.split(' ').take(2).join(' '),
            // Try only the last word (often the core ingredient)
            cleanName.split(' ').last,
          ];

          // Add meaningful tags as fallback queries
          final tags = List<String>.from(dishData['tags'] ?? []);
          for (var tag in tags) {
            if (!tag.contains('_') && tag.length > 3) {
              queries.add(tag);
            }
          }

          // Try queries in order; pass dish ID as seed for stable results
          for (final q in queries.toSet()) {
            if (q.isEmpty || q.length < 3) continue;
            imageUrl = await _imageService.fetchDishImage(q, seed: id);
            if (imageUrl != null) break;
          }

          if (imageUrl != null) {
            debugPrint('Fetched image for $id: $imageUrl');
          } else {
            debugPrint('Could not fetch image for $id');
          }
        }

        // 2. Convert Ingredients Map -> Object
        final rawIngredients = dishData['ingredients'] as List<dynamic>? ?? [];
        final List<Ingredient> ingredients = rawIngredients.map((item) {
          final map = item as Map<String, dynamic>;
          return Ingredient(
            name: map['name'] ?? '',
            amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
            unit: map['unit'] ?? '',
            calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        // 3. Create DishModel
        final dish = DishModel(
          id: id,
          name: dishData['name'],
          nameEn: dishData['name_en'],
          description: dishData['description'],
          descriptionEn: dishData['description_en'] ?? '',
          imageUrl: imageUrl,
          calories: (dishData['calories'] as num).toDouble(),
          protein: (dishData['protein'] as num).toDouble(),
          carbs: (dishData['carbs'] as num).toDouble(),
          fat: (dishData['fat'] as num).toDouble(),
          fiber: (dishData['fiber'] as num?)?.toDouble() ?? 0.0,
          category: dishData['category'],
          tags: List<String>.from(dishData['tags'] ?? []),
          mealType: dishData['meal_type'] ?? 'main',
          prepTimeMinutes: dishData['prep_time_minutes'] ?? 0,
          cookTimeMinutes: dishData['cook_time_minutes'] ?? 0,
          difficulty: dishData['difficulty'] ?? 'medium',
          servings: dishData['servings'] ?? 1,
          ingredients: ingredients,
          instructions: List<String>.from(dishData['instructions'] ?? []),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 4. Save to Firestore
        await _firestore.collection('dishes').doc(id).set(dish.toJson());
        successCount++;
      } catch (e) {
        debugPrint('Error seeding dish ${dishData['id']}: $e');
        failCount++;
      }
    }

    debugPrint('Seeding complete. Success: $successCount, Failed: $failCount');
  }

  /// Seeds any dishes from local data that are missing from Firestore.
  /// Cheap in the common case: a single `count()` aggregation (~1 read
  /// regardless of collection size, never a full document read — matches
  /// this codebase's "count() over size" convention) compares the live
  /// count against `allDishes.length`; only on a mismatch does it fetch the
  /// live id set and upsert whatever's missing, via batch writes. Does NOT
  /// fetch images — uses image_url already present in the data or leaves
  /// imageUrl null.
  ///
  /// **Faz 3 §3.6 repair.** This used to just check "is the collection
  /// non-empty" and no-op otherwise, so it could bootstrap a brand-new
  /// project once but could never pick up dishes added to `dish_data.dart`
  /// afterward (e.g. this task's snack-pool expansion, 75 → 100) on any
  /// environment that had already seeded an earlier catalog — new dishes
  /// only ever reached Firestore via an admin's manual "reseed" tap
  /// (`DishService.seedDatabase` → `seedAllDishes`, an unconditional
  /// overwrite-all). Additive-only — never touches a doc that already
  /// exists — so it stays safe to call unconditionally on every app start.
  Future<void> seedIfEmpty() async {
    try {
      final col = _firestore.collection('dishes');
      final countSnap = await col.count().get();
      final liveCount = countSnap.count ?? 0;
      if (liveCount >= allDishes.length) return; // already caught up

      final existingIds = liveCount == 0
          ? const <String>{}
          : (await col.get(const GetOptions(source: Source.server)))
              .docs
              .map((d) => d.id)
              .toSet();

      final items = allDishes
          .where((d) => !existingIds.contains(d['id'] as String))
          .toList();
      if (items.isEmpty) return;

      const batchSize = 450; // Stay well under the 500-op Firestore batch limit
      int batchStart = 0;

      while (batchStart < items.length) {
        final batch = _firestore.batch();
        final end = (batchStart + batchSize).clamp(0, items.length);

        for (int i = batchStart; i < end; i++) {
          final dishData = items[i];
          try {
            final rawIngredients =
                dishData['ingredients'] as List<dynamic>? ?? [];
            final ingredients = rawIngredients.map((item) {
              final map = item as Map<String, dynamic>;
              return Ingredient(
                name: map['name'] ?? '',
                amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
                unit: map['unit'] ?? '',
                calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
              );
            }).toList();

            final dish = DishModel(
              id: dishData['id'],
              name: dishData['name'],
              nameEn: dishData['name_en'],
              description: dishData['description'],
              descriptionEn: dishData['description_en'] ?? '',
              imageUrl: dishData['image_url'] as String?,
              calories: (dishData['calories'] as num).toDouble(),
              protein: (dishData['protein'] as num).toDouble(),
              carbs: (dishData['carbs'] as num).toDouble(),
              fat: (dishData['fat'] as num).toDouble(),
              fiber: (dishData['fiber'] as num?)?.toDouble() ?? 0.0,
              category: dishData['category'],
              tags: List<String>.from(dishData['tags'] ?? []),
              mealType: dishData['meal_type'] ?? 'main',
              prepTimeMinutes: dishData['prep_time_minutes'] ?? 0,
              cookTimeMinutes: dishData['cook_time_minutes'] ?? 0,
              difficulty: dishData['difficulty'] ?? 'medium',
              servings: dishData['servings'] ?? 1,
              ingredients: ingredients,
              instructions: List<String>.from(dishData['instructions'] ?? []),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            batch.set(
              _firestore.collection('dishes').doc(dish.id),
              dish.toJson(),
            );
          } catch (e) {
            // Skip individual bad entries; don't abort the whole batch.
            debugPrint('DishSeederService.seedIfEmpty: skipping bad entry '
                '${dishData['id']}: $e');
          }
        }

        await batch.commit();
        batchStart = end;
      }
      debugPrint('DishSeederService.seedIfEmpty: added ${items.length} '
          'missing dish(es)');
    } catch (e, stack) {
      // Seeding failure is non-fatal; app works without pre-seeded dishes —
      // but still reported, unlike before (R4: no silent catch).
      debugPrint('DishSeederService.seedIfEmpty error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'DishSeederService.seedIfEmpty'));
    }
  }

  Future<void> seedSingleDish(
      Map<String, dynamic> dishData, String imageUrl) async {
    try {
      final String id = dishData['id'];

      // 1. Convert Ingredients Map -> Object
      final rawIngredients = dishData['ingredients'] as List<dynamic>? ?? [];
      final List<Ingredient> ingredients = rawIngredients.map((item) {
        final map = item as Map<String, dynamic>;
        return Ingredient(
          name: map['name'] ?? '',
          amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
          unit: map['unit'] ?? '',
          calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      // 2. Create DishModel
      final dish = DishModel(
        id: id,
        name: dishData['name'],
        nameEn: dishData['name_en'],
        description: dishData['description'],
        descriptionEn: dishData['description_en'] ?? '',
        imageUrl: imageUrl,
        calories: (dishData['calories'] as num).toDouble(),
        protein: (dishData['protein'] as num).toDouble(),
        carbs: (dishData['carbs'] as num).toDouble(),
        fat: (dishData['fat'] as num).toDouble(),
        fiber: (dishData['fiber'] as num?)?.toDouble() ?? 0.0,
        category: dishData['category'],
        tags: List<String>.from(dishData['tags'] ?? []),
        mealType: dishData['meal_type'] ?? 'main',
        prepTimeMinutes: dishData['prep_time_minutes'] ?? 0,
        cookTimeMinutes: dishData['cook_time_minutes'] ?? 0,
        difficulty: dishData['difficulty'] ?? 'medium',
        servings: dishData['servings'] ?? 1,
        ingredients: ingredients,
        instructions: List<String>.from(dishData['instructions'] ?? []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Save to Firestore
      await _firestore.collection('dishes').doc(id).set(dish.toJson());
      debugPrint('Successfully seeded single dish: $id');
    } catch (e) {
      debugPrint('Error seeding single dish ${dishData['id']}: $e');
      rethrow;
    }
  }
}
