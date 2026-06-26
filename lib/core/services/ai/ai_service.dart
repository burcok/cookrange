import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../crashlytics_service.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'tngtech/deepseek-r1t-chimera:free';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  String? _apiKey;

  void initialize({required String apiKey}) {
    final trimmed = apiKey.trim();
    _apiKey = (trimmed.isEmpty ||
            trimmed.contains('your_') ||
            trimmed.contains('_here'))
        ? null
        : trimmed;
    unawaited(CrashlyticsService().setCustomKeys(aiModel: _model));
  }

  bool get isConfigured => _apiKey != null;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Generate a text completion. Retries on transient errors.
  Future<String> generateCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    if (!isConfigured) {
      debugPrint('AIService: no API key — returning mock response.');
      if (systemPrompt != null && systemPrompt.contains('JSON')) {
        final lowerPrompt = prompt.toLowerCase();
        final lowerSystem = systemPrompt.toLowerCase();
        
        if (lowerPrompt.contains('weekly') || 
            lowerPrompt.contains('meal_plans') || 
            lowerPrompt.contains('meal plan') || 
            lowerSystem.contains('weekly') || 
            lowerSystem.contains('meal')) {
          return '''
{
  "total_calories": 14000,
  "avg_daily_calories": 2000,
  "avg_macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 },
  "days": [
    {
      "day_name": "Monday",
      "date_offset": 0,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Tuesday",
      "date_offset": 1,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Wednesday",
      "date_offset": 2,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Thursday",
      "date_offset": 3,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Friday",
      "date_offset": 4,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Saturday",
      "date_offset": 5,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Sunday",
      "date_offset": 6,
      "meals": {
        "breakfast": "dish_1",
        "lunch": "dish_2",
        "dinner": "dish_3",
        "snack": "dish_4"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    }
  ]
}
          ''';
        } else if (lowerPrompt.contains('recipe') || lowerSystem.contains('recipe')) {
          return '''
{
  "title": "Mock Healthy Stir Fry",
  "description": "A quick and delicious mock stir fry loaded with veggies and protein.",
  "prepTimeMinutes": 15,
  "cookTimeMinutes": 10,
  "servings": 2,
  "difficulty": "Easy",
  "ingredients": [
    {"name": "Chicken Breast", "amount": 200, "unit": "g", "calories": 330},
    {"name": "Mixed Vegetables", "amount": 150, "unit": "g", "calories": 80},
    {"name": "Olive Oil", "amount": 10, "unit": "ml", "calories": 90}
  ],
  "instructions": [
    "Cut chicken breast into bite-sized pieces.",
    "Heat oil in a pan, add chicken, and cook until browned.",
    "Add vegetables and stir fry for 5 minutes.",
    "Serve hot."
  ],
  "macros": {
    "protein": 45.0,
    "carbs": 10.0,
    "fat": 12.0,
    "calories": 500.0
  },
  "tags": ["Healthy", "Quick", "High-Protein"]
}
          ''';
        } else if (lowerPrompt.contains('ingredient') || 
            lowerPrompt.contains('food item') || 
            lowerSystem.contains('ingredient')) {
          return '''
{
  "label": "Mock Ingredient",
  "value": "mock_ingredient",
  "icon": "other",
  "calories": 100
}
          ''';
        }
        return '{}';
      }
      return 'AI is not configured. Please set a valid API key.';
    }

    Exception? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _callApi(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      } on AIRetryableException catch (e) {
        lastError = e;
        debugPrint('AIService: attempt $attempt/$_maxRetries retryable: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      } on AIFatalException {
        rethrow;
      } catch (e) {
        lastError = Exception(e.toString());
        debugPrint('AIService: attempt $attempt/$_maxRetries error: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('AIService: all retries exhausted');
  }

  /// Generate and parse a JSON response.
  /// Retries on both network errors AND malformed JSON.
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    required String jsonStructure,
  }) async {
    final systemPrompt = '''
You are a JSON generator. Output ONLY valid JSON matching this structure:
$jsonStructure
Rules: No markdown formatting. No ```json. No explanatory text. Raw JSON only.
''';

    Exception? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final content = await generateCompletion(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: 0.2,
        );
        return _parseJson(content);
      } on AIJsonParseException catch (e) {
        lastError = e;
        debugPrint(
            'AIService: JSON parse failed attempt $attempt/$_maxRetries: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        rethrow;
      }
    }
    throw lastError ??
        AIJsonParseException(
            'Failed to parse JSON after $_maxRetries attempts');
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  Future<String> _callApi({
    required String prompt,
    String? systemPrompt,
    required double temperature,
  }) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
            'HTTP-Referer': 'https://cookrange.app',
            'X-Title': 'Cookrange',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              if (systemPrompt != null)
                {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': prompt},
            ],
            'temperature': temperature,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw AIFatalException('Empty choices in API response');
      }
      return choices[0]['message']['content'] as String;
    }

    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw AIRetryableException(
          'HTTP ${response.statusCode}: ${response.body}');
    }

    throw AIFatalException('HTTP ${response.statusCode}: ${response.body}');
  }

  Map<String, dynamic> _parseJson(String raw) {
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Strip DeepSeek R1 <think>...</think> reasoning blocks
    if (cleaned.contains('<think>')) {
      final parts = cleaned.split('</think>');
      if (parts.length > 1) cleaned = parts.last.trim();
    }

    // Extract outermost JSON object
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (e) {
      throw AIJsonParseException('JSON parse error: $e\nRaw snippet: '
          '${cleaned.length > 200 ? cleaned.substring(0, 200) : cleaned}');
    }
  }
}

// ─── Typed exceptions for retry logic ──────────────────────────────────────

class AIRetryableException implements Exception {
  final String message;
  const AIRetryableException(this.message);
  @override
  String toString() => 'AIRetryableException: $message';
}

class AIFatalException implements Exception {
  final String message;
  const AIFatalException(this.message);
  @override
  String toString() => 'AIFatalException: $message';
}

class AIJsonParseException implements Exception {
  final String message;
  const AIJsonParseException(this.message);
  @override
  String toString() => 'AIJsonParseException: $message';
}
