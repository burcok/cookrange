import 'ai/ai_service.dart';
import 'ai/prompt_service.dart';
import '../models/recipe_model.dart';
import '../models/ingredient_model.dart';

class RecipeGenerationService {
  static final RecipeGenerationService _instance =
      RecipeGenerationService._internal();
  factory RecipeGenerationService() => _instance;
  RecipeGenerationService._internal();

  final AIService _aiService = AIService();
  final PromptService _promptService = PromptService();

  Future<Recipe?> generateRecipe({
    required List<String> ingredients,
    required double targetCalories,
    List<String> dietaryRestrictions = const [],
  }) async {
    try {
      final prompt = _promptService.generateRecipePrompt(
        ingredients: ingredients,
        targetCalories: targetCalories,
        dietaryRestrictions: dietaryRestrictions,
      );

      final jsonResponse = await _aiService.generateJson(
        prompt: prompt,
        jsonStructure: '''
{
  "title": "Recipe Title",
  "description": "Short description",
  "prepTimeMinutes": number,
  "cookTimeMinutes": number,
  "servings": number,
  "difficulty": "Easy/Medium/Hard",
  "ingredients": [
    {"name": "Ingredient Name", "amount": number, "unit": "g/ml/pcs", "calories": number}
  ],
  "instructions": ["Step 1", "Step 2"],
  "macros": {
    "protein": number,
    "carbs": number,
    "fat": number,
    "calories": number
  },
  "tags": ["Tag1", "Tag2"]
}
''',
      );

      // Map JSON to Recipe Model using a UUID for ID
      final String id = DateTime.now().millisecondsSinceEpoch.toString();

      return Recipe(
        id: id,
        title: jsonResponse['title'] as String,
        description: jsonResponse['description'] as String,
        prepTimeMinutes: jsonResponse['prepTimeMinutes'] as int,
        cookTimeMinutes: jsonResponse['cookTimeMinutes'] as int,
        servings: jsonResponse['servings'] as int,
        difficulty: jsonResponse['difficulty'] as String,
        macros: Map<String, double>.from(jsonResponse['macros'] as Map),
        ingredients: (jsonResponse['ingredients'] as List).map((i) {
          return Ingredient(
            name: i['name'] as String,
            amount: (i['amount'] as num).toDouble(),
            unit: i['unit'] as String,
            calories: (i['calories'] as num).toDouble(),
          );
        }).toList(),
        instructions: List<String>.from(jsonResponse['instructions'] as List),
        tags: List<String>.from(jsonResponse['tags'] as List),
        imageUrl: null, // AI doesn't generate images yet
      );
    } catch (e) {
      // debugPrint('Recipe Generation Failed: $e');
      return null;
    }
  }
}
