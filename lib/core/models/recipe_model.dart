import 'ingredient_model.dart';

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty;
  final Map<String, double> macros; // protein, carbs, fat, calories
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> tags;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.macros,
    required this.ingredients,
    required this.instructions,
    required this.tags,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 0,
      cookTimeMinutes: json['cookTimeMinutes'] as int? ?? 0,
      servings: json['servings'] as int? ?? 1,
      difficulty: json['difficulty'] as String? ?? 'Medium',
      macros: Map<String, double>.from(json['macros'] as Map),
      ingredients: (json['ingredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      instructions: List<String>.from(json['instructions'] as List),
      tags: List<String>.from(json['tags'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'servings': servings,
      'difficulty': difficulty,
      'macros': macros,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'tags': tags,
    };
  }
}
