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
          // Sanitize name: remove special characters, take part before punctuation
          final cleanName = nameEn
              .split(RegExp(r'[&,()]'))
              .first
              .replaceAll(RegExp(r'[^a-zA-Z\s]'), '')
              .trim();

          final queries = <String>[
            cleanName, // Full cleaned name
            cleanName.split(' ').take(3).join(' '), // First 3 words
            cleanName
                .split(' ')
                .last, // Last word (often the core ingredient/dish)
          ];

          // Add first tag as a query if available
          final tags = List<String>.from(dishData['tags'] ?? []);
          if (tags.isNotEmpty) {
            queries.add(tags.first.replaceAll('_', ' '));
          }

          // Try queries in order
          for (final q in queries.toSet()) {
            // toSet() removes duplicates
            if (q.isEmpty) continue;
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
}
