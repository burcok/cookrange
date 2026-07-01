import 'package:flutter/foundation.dart';
import 'ai/ai_service.dart';
import 'ai/prompt_service.dart';

/// Rich nutrition estimate returned by AI text/photo analysis.
///
/// The four core macros + [foodName]/[servingSize] are always present; the
/// enriched fields ([fiber], [sugar], [sodiumMg], [healthScore], [allergens],
/// [confidence], [portionGrams]) are best-effort and may be 0/empty.
class NutritionEstimate {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;

  // Enriched fields
  final double fiber; // g
  final double sugar; // g
  final double sodiumMg; // mg
  final int healthScore; // 0–100
  final double confidence; // 0–1
  final List<String> allergens;
  final double portionGrams; // estimated portion weight (0 = unknown)
  final bool fromPhoto;

  const NutritionEstimate({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.fiber = 0,
    this.sugar = 0,
    this.sodiumMg = 0,
    this.healthScore = 0,
    this.confidence = 0,
    this.allergens = const [],
    this.portionGrams = 0,
    this.fromPhoto = false,
  });

  /// Linearly rescales all quantitative values by [factor] (e.g. a portion
  /// stepper). Qualitative fields (name, score, allergens, confidence) are kept.
  NutritionEstimate scaled(double factor) {
    return NutritionEstimate(
      foodName: foodName,
      servingSize: servingSize,
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sugar: sugar * factor,
      sodiumMg: sodiumMg * factor,
      healthScore: healthScore,
      confidence: confidence,
      allergens: allergens,
      portionGrams: portionGrams * factor,
      fromPhoto: fromPhoto,
    );
  }

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'serving_size': servingSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium_mg': sodiumMg,
        'health_score': healthScore,
        'confidence': confidence,
        'allergens': allergens,
        'portion_grams': portionGrams,
        'from_photo': fromPhoto,
      };

  factory NutritionEstimate.fromJson(Map<String, dynamic> j) {
    return NutritionEstimate(
      foodName: j['food_name'] as String? ?? '',
      servingSize: j['serving_size'] as String? ?? '',
      calories: (j['calories'] as num?)?.toDouble() ?? 0,
      protein: (j['protein'] as num?)?.toDouble() ?? 0,
      carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
      fat: (j['fat'] as num?)?.toDouble() ?? 0,
      fiber: (j['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (j['sugar'] as num?)?.toDouble() ?? 0,
      sodiumMg: (j['sodium_mg'] as num?)?.toDouble() ?? 0,
      healthScore: (j['health_score'] as num?)?.toInt() ?? 0,
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      allergens: List<String>.from(j['allergens'] ?? const []),
      portionGrams: (j['portion_grams'] as num?)?.toDouble() ?? 0,
      fromPhoto: j['from_photo'] as bool? ?? false,
    );
  }
}

class FoodAnalysisService {
  static final FoodAnalysisService _instance = FoodAnalysisService._internal();
  factory FoodAnalysisService() => _instance;
  FoodAnalysisService._internal();

  final AIService _ai = AIService();

  bool get isAvailable => _ai.isConfigured;

  /// True when photo analysis is supported (a vision model is configured).
  bool get isPhotoAvailable => _ai.isVisionAvailable;

  static const String _jsonStructure = '''
{
  "food_name": "Short name of the food or meal",
  "serving_size": "Description of the serving (e.g. '2 slices + 1 egg')",
  "portion_grams": 300,
  "calories": 350,
  "protein_g": 22.5,
  "carbs_g": 40.0,
  "fat_g": 8.0,
  "fiber_g": 5.0,
  "sugar_g": 6.0,
  "sodium_mg": 400,
  "health_score": 72,
  "confidence": 0.8,
  "allergens": ["gluten", "dairy"]
}''';

  NutritionEstimate _parse(Map<String, dynamic> result,
      {required String fallbackName, required bool fromPhoto}) {
    return NutritionEstimate(
      foodName: (result['food_name'] as String? ?? fallbackName).trim(),
      servingSize: (result['serving_size'] as String? ?? '').trim(),
      calories: (result['calories'] as num?)?.toDouble() ?? 0,
      protein: (result['protein_g'] as num?)?.toDouble() ?? 0,
      carbs: (result['carbs_g'] as num?)?.toDouble() ?? 0,
      fat: (result['fat_g'] as num?)?.toDouble() ?? 0,
      fiber: (result['fiber_g'] as num?)?.toDouble() ?? 0,
      sugar: (result['sugar_g'] as num?)?.toDouble() ?? 0,
      sodiumMg: (result['sodium_mg'] as num?)?.toDouble() ?? 0,
      healthScore:
          ((result['health_score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      confidence:
          ((result['confidence'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      allergens: List<String>.from(result['allergens'] ?? const [])
          .map((e) => e.toString())
          .toList(),
      portionGrams: (result['portion_grams'] as num?)?.toDouble() ?? 0,
      fromPhoto: fromPhoto,
    );
  }

  Future<NutritionEstimate?> analyzeFood(String description) async {
    if (!_ai.isConfigured) return null;
    if (description.trim().isEmpty) return null;

    final prompt =
        '${PromptService.injectionGuard}'
        'Analyze the nutritional content of the following food description and estimate its macros, key micros (fiber, sugar, sodium), a 0–100 health score (higher = healthier), your confidence (0–1), and likely allergens, per the described serving:\n\n${PromptService().fence(description)}\n\nProvide best-effort estimates based on typical values. If the user described a quantity, use it as the serving size.';

    try {
      final result = await _ai.generateJson(
        prompt: prompt,
        jsonStructure: _jsonStructure,
        type: 'food_photo',
      );
      return _parse(result, fallbackName: description, fromPhoto: false);
    } catch (e) {
      debugPrint('FoodAnalysisService.analyzeFood error: $e');
      rethrow;
    }
  }

  /// Analyzes a meal photo with a vision model. [hint] is an optional user note
  /// (e.g. "large portion") appended to the prompt.
  Future<NutritionEstimate?> analyzeFoodPhoto(
    Uint8List imageBytes, {
    String? hint,
    String mimeType = 'image/jpeg',
  }) async {
    if (!_ai.isVisionAvailable) return null;
    if (imageBytes.isEmpty) return null;

    final prompt =
        '${PromptService.injectionGuard}'
        'Identify the food in this image and estimate the nutrition for the visible portion: macros, key micros (fiber, sugar, sodium), a 0–100 health score (higher = healthier), your confidence (0–1), the estimated portion weight in grams, and likely allergens.'
        '${(hint != null && hint.trim().isNotEmpty) ? '\n\nUser note: ${PromptService().fence(hint.trim())}.' : ''}'
        '\n\nIf multiple foods are present, summarize the whole plate.';

    try {
      final result = await _ai.generateJsonFromImage(
        prompt: prompt,
        jsonStructure: _jsonStructure,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      return _parse(result, fallbackName: '', fromPhoto: true);
    } catch (e) {
      debugPrint('FoodAnalysisService.analyzeFoodPhoto error: $e');
      rethrow;
    }
  }
}
