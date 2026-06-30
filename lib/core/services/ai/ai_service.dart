import 'dart:async';
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../crashlytics_service.dart';
import '../performance_service.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openrouter/free';
  // Default free vision-capable model. Override via [initialize] `visionModel`
  // or [setVisionModel] (e.g. from `.env` OPENROUTER_VISION_MODEL). An empty
  // value disables photo analysis (the UI hides the camera option).
  static const String _defaultVisionModel =
      'meta-llama/llama-3.2-11b-vision-instruct:free';
  String _visionModel = _defaultVisionModel;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  String? _apiKey;

  // When set, all AI calls are proxied through the Cloud Function and the
  // API key stays server-side. Populated from Remote Config `ai_proxy_url`.
  String? _proxyUrl;

  void initialize({
    required String apiKey,
    String? proxyUrl,
    String? visionModel,
  }) {
    final trimmed = apiKey.trim();
    _apiKey = (trimmed.isEmpty ||
            trimmed.contains('your_') ||
            trimmed.contains('_here'))
        ? null
        : trimmed;
    final proxyTrimmed = proxyUrl?.trim() ?? '';
    _proxyUrl = proxyTrimmed.isEmpty ? null : proxyTrimmed;
    if (visionModel != null) _visionModel = visionModel.trim();
    unawaited(CrashlyticsService().setCustomKeys(aiModel: _model));
  }

  bool get isConfigured => _proxyUrl != null || _apiKey != null;

  /// True when photo/vision analysis can run (configured + a vision model set).
  bool get isVisionAvailable => isConfigured && _visionModel.isNotEmpty;

  /// Override the vision model at runtime (e.g. from Remote Config).
  void setVisionModel(String? model) {
    _visionModel = model?.trim() ?? '';
  }

  /// True when an AI proxy URL is configured — credits are enforced server-side.
  bool get hasProxy => _proxyUrl != null;

  /// Called after Remote Config loads to activate server-side key proxying.
  void setProxyUrl(String? url) {
    final trimmed = url?.trim() ?? '';
    _proxyUrl = trimmed.isEmpty ? null : trimmed;
  }

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
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Tuesday",
      "date_offset": 1,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Wednesday",
      "date_offset": 2,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Thursday",
      "date_offset": 3,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Friday",
      "date_offset": 4,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Saturday",
      "date_offset": 5,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    },
    {
      "day_name": "Sunday",
      "date_offset": 6,
      "meals": {
        "breakfast": "geleneksel_menemen",
        "lunch": "somonlu_kinoa_bowl",
        "dinner": "izgara_somon_sebze",
        "snack": "smoothie_bowl_protein"
      },
      "total_calories": 2000.0,
      "macros": { "protein": 150.0, "carbs": 200.0, "fat": 70.0 }
    }
  ]
}
          ''';
        } else if (lowerPrompt.contains('recipe') ||
            lowerSystem.contains('recipe')) {
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
      } on AIQuotaExceededException {
        rethrow;
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

  /// Send a multi-turn chat conversation and return the assistant's reply.
  ///
  /// [messages] is the full history: `[{'role': 'user'|'assistant'|'system', 'content': '...'}]`.
  Future<String> generateChatResponse({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
  }) async {
    if (!isConfigured) {
      return 'I am your AI nutrition assistant. Unfortunately I need an API key to give you personalized advice right now. Please configure the AI key in settings.';
    }

    Exception? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _callApiWithMessages(
          messages: messages,
          temperature: temperature,
        );
      } on AIRetryableException catch (e) {
        lastError = e;
        if (attempt < _maxRetries) await Future.delayed(_retryDelay * attempt);
      } on AIQuotaExceededException {
        rethrow;
      } on AIFatalException {
        rethrow;
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt < _maxRetries) await Future.delayed(_retryDelay * attempt);
      }
    }
    throw lastError ?? Exception('AIService: all retries exhausted');
  }

  Future<String> _callApiWithMessages({
    required List<Map<String, String>> messages,
    required double temperature,
  }) async {
    final url = _proxyUrl ?? _baseUrl;
    final metric = PerformanceService().newHttpMetric(url, HttpMethod.Post);
    await metric.start();
    final http.Response response;
    try {
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      if (_proxyUrl != null) {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
        try {
          final appCheckToken = await FirebaseAppCheck.instance.getToken();
          if (appCheckToken != null) {
            headers['X-Firebase-AppCheck'] = appCheckToken;
          }
        } catch (_) {}
      } else {
        headers['Authorization'] = 'Bearer $_apiKey';
        headers['HTTP-Referer'] = 'https://cookrangeapp.com';
        headers['X-Title'] = 'Cookrange';
      }
      response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 45));
      metric.httpResponseCode = response.statusCode;
      metric.responsePayloadSize = response.bodyBytes.length;
    } finally {
      await metric.stop();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const AIFatalException('Empty choices in API response');
      }
      return choices[0]['message']['content'] as String;
    }
    if (response.statusCode == 402) {
      throw const AIQuotaExceededException();
    }
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw AIRetryableException(
          'HTTP ${response.statusCode}: ${response.body}');
    }
    throw AIFatalException('HTTP ${response.statusCode}: ${response.body}');
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
        const AIJsonParseException(
            'Failed to parse JSON after $_maxRetries attempts');
  }

  /// Generate and parse JSON from an image + prompt using a vision model.
  /// Retries on transient network errors AND malformed JSON.
  Future<Map<String, dynamic>> generateJsonFromImage({
    required String prompt,
    required String jsonStructure,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (!isVisionAvailable) {
      throw const AIFatalException('AIService: vision model not configured');
    }

    final systemPrompt = '''
You are a JSON generator. Output ONLY valid JSON matching this structure:
$jsonStructure
Rules: No markdown formatting. No ```json. No explanatory text. Raw JSON only.
''';
    final dataUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';

    Exception? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final content = await _callVisionApi(
          systemPrompt: systemPrompt,
          userText: prompt,
          imageDataUrl: dataUrl,
          temperature: 0.2,
        );
        return _parseJson(content);
      } on AIJsonParseException catch (e) {
        lastError = e;
        debugPrint(
            'AIService: vision JSON parse failed $attempt/$_maxRetries: $e');
        if (attempt < _maxRetries) await Future.delayed(_retryDelay);
      } on AIRetryableException catch (e) {
        lastError = e;
        debugPrint('AIService: vision retryable error $attempt/$_maxRetries: $e');
        if (attempt < _maxRetries) await Future.delayed(_retryDelay * attempt);
      } catch (e) {
        rethrow;
      }
    }
    throw lastError ??
        const AIJsonParseException(
            'Failed to parse vision JSON after $_maxRetries attempts');
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  Future<String> _callVisionApi({
    required String systemPrompt,
    required String userText,
    required String imageDataUrl,
    required double temperature,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userText},
          {
            'type': 'image_url',
            'image_url': {'url': imageDataUrl},
          },
        ],
      },
    ];

    final url = _proxyUrl ?? _baseUrl;
    final metric = PerformanceService().newHttpMetric(url, HttpMethod.Post);
    await metric.start();
    final http.Response response;
    try {
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (_proxyUrl != null) {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
        try {
          final appCheckToken = await FirebaseAppCheck.instance.getToken();
          if (appCheckToken != null) {
            headers['X-Firebase-AppCheck'] = appCheckToken;
          }
        } catch (_) {}
      } else {
        headers['Authorization'] = 'Bearer $_apiKey';
        headers['HTTP-Referer'] = 'https://cookrangeapp.com';
        headers['X-Title'] = 'Cookrange';
      }

      response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'model': _visionModel,
              'messages': messages,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 60));
      metric.httpResponseCode = response.statusCode;
      metric.responsePayloadSize = response.bodyBytes.length;
    } finally {
      await metric.stop();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const AIFatalException('Empty choices in vision API response');
      }
      return choices[0]['message']['content'] as String;
    }
    if (response.statusCode == 402) {
      throw const AIQuotaExceededException();
    }
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw AIRetryableException(
          'HTTP ${response.statusCode}: ${response.body}');
    }
    throw AIFatalException('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<String> _callApi({
    required String prompt,
    String? systemPrompt,
    required double temperature,
  }) async {
    final messages = [
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': prompt},
    ];

    final url = _proxyUrl ?? _baseUrl;
    final metric = PerformanceService().newHttpMetric(url, HttpMethod.Post);
    await metric.start();
    final http.Response response;
    try {
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (_proxyUrl != null) {
        // Server-side key: authenticate with Firebase ID token + App Check.
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
        try {
          final appCheckToken = await FirebaseAppCheck.instance.getToken();
          if (appCheckToken != null) {
            headers['X-Firebase-AppCheck'] = appCheckToken;
          }
        } catch (_) {}
      } else {
        headers['Authorization'] = 'Bearer $_apiKey';
        headers['HTTP-Referer'] = 'https://cookrangeapp.com';
        headers['X-Title'] = 'Cookrange';
      }

      response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 45));
      metric.httpResponseCode = response.statusCode;
      metric.responsePayloadSize = response.bodyBytes.length;
    } finally {
      await metric.stop();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const AIFatalException('Empty choices in API response');
      }
      return choices[0]['message']['content'] as String;
    }

    if (response.statusCode == 402) {
      throw const AIQuotaExceededException();
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

/// Thrown when the server-side AI proxy returns 402 (daily quota exceeded).
/// Not retried — callers should surface the credits/paywall sheet.
class AIQuotaExceededException implements Exception {
  const AIQuotaExceededException();
  @override
  String toString() => 'AIQuotaExceededException: daily AI generation limit reached';
}
