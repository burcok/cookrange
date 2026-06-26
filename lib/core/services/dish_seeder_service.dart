import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dish_model.dart';
import '../models/ingredient_model.dart';
import '../data/dish_data.dart';
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

    print('Starting dish seeding for ${items.length} items...');

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

          // Try queries in order
          for (final q in queries.toSet()) {
            if (q.isEmpty || q.length < 3) continue;
            imageUrl = await _imageService.fetchDishImage(q);
            if (imageUrl != null) break;
          }

          if (imageUrl != null) {
            print('Fetched image for $id: $imageUrl');
          } else {
            print('Could not fetch image for $id');
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
        print('Error seeding dish ${dishData['id']}: $e');
        failCount++;
      }
    }

    print('Seeding complete. Success: $successCount, Failed: $failCount');
  }

  /// Seeds all dishes from local data if the Firestore dishes collection is empty.
  /// Uses batch writes for efficiency. Does NOT fetch images — uses image_url
  /// already present in the data or leaves imageUrl null.
  Future<void> seedIfEmpty() async {
    try {
      final existing = await _firestore
          .collection('dishes')
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existing.docs.isNotEmpty) return;

      const batchSize = 450; // Stay well under the 500-op Firestore batch limit
      final items = allDishes;
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
          } catch (_) {
            // Skip individual bad entries; don't abort the whole batch
          }
        }

        await batch.commit();
        batchStart = end;
      }
    } catch (_) {
      // Seeding failure is non-fatal; app works without pre-seeded dishes
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
      print('Successfully seeded single dish: $id');
    } catch (e) {
      print('Error seeding single dish ${dishData['id']}: $e');
      rethrow;
    }
  }
}
