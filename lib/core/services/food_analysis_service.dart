import 'package:flutter/foundation.dart';
import 'ai/ai_service.dart';

class NutritionEstimate {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;

  const NutritionEstimate({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
  });
}

class FoodAnalysisService {
  static final FoodAnalysisService _instance = FoodAnalysisService._internal();
  factory FoodAnalysisService() => _instance;
  FoodAnalysisService._internal();

  final AIService _ai = AIService();

  bool get isAvailable => _ai.isConfigured;

  Future<NutritionEstimate?> analyzeFood(String description) async {
    if (!_ai.isConfigured) return null;
    if (description.trim().isEmpty) return null;

    const jsonStructure = '''
{
  "food_name": "Short name of the food or meal",
  "serving_size": "Description of the serving (e.g. '2 slices + 1 egg')",
  "calories": 350,
  "protein_g": 22.5,
  "carbs_g": 40.0,
  "fat_g": 8.0
}''';

    final prompt =
        'Analyze the nutritional content of the following food description and estimate its macros per the described serving:\n\n"$description"\n\nProvide best-effort estimates based on typical values. If the user described a quantity, use that quantity as the serving size.';

    try {
      final result = await _ai.generateJson(
        prompt: prompt,
        jsonStructure: jsonStructure,
      );

      return NutritionEstimate(
        foodName: (result['food_name'] as String? ?? description).trim(),
        servingSize: (result['serving_size'] as String? ?? '').trim(),
        calories: (result['calories'] as num?)?.toDouble() ?? 0,
        protein: (result['protein_g'] as num?)?.toDouble() ?? 0,
        carbs: (result['carbs_g'] as num?)?.toDouble() ?? 0,
        fat: (result['fat_g'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('FoodAnalysisService.analyzeFood error: $e');
      rethrow;
    }
  }
}
