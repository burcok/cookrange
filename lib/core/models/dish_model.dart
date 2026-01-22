import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient_model.dart';
import 'recipe_model.dart';

class DishModel {
  final String id;
  final String name; // Turkish name
  final String nameEn; // English name
  final String description;
  final String descriptionEn; // English description
  final String? imageUrl;

  // Nutritional Info (per serving)
  final double calories;
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final double fiber; // grams

  // Categorization
  final String
      category; // chicken, red_meat, fish, breakfast, vegetarian, vegan, diet, sport, turkish_classic
  final List<String> tags; // high_protein, low_carb, quick, etc.
  final String mealType; // breakfast, lunch, dinner, snack

  // Preparation Info
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty; // easy, medium, hard
  final int servings;

  // Ingredients
  final List<Ingredient> ingredients;
  final List<String> instructions;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const DishModel({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.descriptionEn,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    required this.category,
    required this.tags,
    required this.mealType,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    this.servings = 1,
    required this.ingredients,
    required this.instructions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DishModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DishModel.fromJson(data, doc.id);
  }

  factory DishModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return DishModel(
      id: id ?? json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String? ?? '',
      description: json['description'] as String,
      descriptionEn: json['description_en'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      mealType: json['meal_type'] as String? ?? 'main',
      prepTimeMinutes: json['prep_time_minutes'] as int? ?? 0,
      cookTimeMinutes: json['cook_time_minutes'] as int? ?? 0,
      difficulty: json['difficulty'] as String? ?? 'medium',
      servings: json['servings'] as int? ?? 1,
      ingredients: (json['ingredients'] as List? ?? [])
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      instructions: List<String>.from(json['instructions'] ?? []),
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_en': nameEn,
      'description': description,
      'description_en': descriptionEn,
      'image_url': imageUrl,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'category': category,
      'tags': tags,
      'meal_type': mealType,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'difficulty': difficulty,
      'servings': servings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  // Conversion to Recipe for UI compatibility
  Recipe toRecipe() {
    return Recipe(
      id: id,
      title: name, // Using Turkish name as title
      description: description,
      imageUrl: imageUrl,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      servings: servings,
      difficulty: difficulty,
      macros: {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      },
      ingredients: ingredients,
      instructions: instructions,
      tags: tags,
    );
  }
}
