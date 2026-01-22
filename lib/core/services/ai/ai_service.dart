import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  String? _apiKey;

  void initialize({required String apiKey}) {
    _apiKey = apiKey;
  }

  Future<String> generateCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      // Return mock response if no API key is set
      debugPrint(
          'Warning: No API key set for AIService. Returning mock response.');
      await Future.delayed(const Duration(seconds: 1));

      // If it looks like a JSON request, return a generic mock JSON
      if (systemPrompt != null && systemPrompt.contains('JSON')) {
        return '{}';
      }

      return 'This is a mock response from AIService. Please configure your API key.';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'Referer': 'https://cookrange.app', // Standard header name
          'X-Title': 'Cookrange', // Optional, for OpenRouter tracking
        },
        body: jsonEncode({
          'model':
              'tngtech/deepseek-r1t-chimera:free', // Fast and free model on OpenRouter
          'messages': [
            if (systemPrompt != null)
              {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': temperature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        throw Exception(
            'AI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('AIService Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    required String jsonStructure,
  }) async {
    final systemPrompt = '''
You are a helpful JSON generator. 
Output ONLY valid JSON matching this structure:
$jsonStructure
Do not include markdown formatting (like ```json).
''';

    try {
      final content = await generateCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.3, // Lower temperature for more deterministic structure
      );

      // Clean up potential markdown and extract JSON block
      String cleanContent =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      // Remove <think> tags if present
      if (cleanContent.contains('<think>')) {
        cleanContent = cleanContent.split('</think>').last.trim();
      }

      // If there's still extra text, find the first '{' and last '}'
      final firstBrace = cleanContent.indexOf('{');
      final lastBrace = cleanContent.lastIndexOf('}');

      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        cleanContent = cleanContent.substring(firstBrace, lastBrace + 1);
      }

      return jsonDecode(cleanContent) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON Generation Failed: $e');
      rethrow;
    }
  }
}
