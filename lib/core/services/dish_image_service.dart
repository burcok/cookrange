import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class DishImageService {
  static const String _unsplashBaseUrl = 'https://api.unsplash.com';

  // Cache for image URLs to avoid repeated API calls
  static final Map<String, String> _imageCache = {};

  Future<String?> fetchDishImage(String query) async {
    // Check cache first
    if (_imageCache.containsKey(query)) {
      return _imageCache[query];
    }

    String? apiKey;
    try {
      apiKey = dotenv.env['UNSPLASH_API_KEY'];
    } catch (e) {
      if (kDebugMode) {
        print('Warning: DotEnv not initialized when fetching image: $e');
      }
    }

    // If no API key, return null (UI should handle placeholder)
    // Or return a specific placeholder based on query keywords?
    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        print('Warning: UNSPLASH_API_KEY not found in .env');
      }
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '$_unsplashBaseUrl/search/photos?query=$query&per_page=1&orientation=squarish'),
        headers: {
          'Authorization': 'Client-ID $apiKey',
          'Accept-Version': 'v1',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          final imageUrl = results[0]['urls']['regular'] as String;
          _imageCache[query] = imageUrl;
          return imageUrl;
        }
      } else {
        if (kDebugMode) {
          print(
              'Unsplash API Error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching image for $query: $e');
      }
    }
    return null;
  }

  Future<Map<String, String>> fetchBatchImages(List<String> queries) async {
    final Map<String, String> images = {};
    for (final query in queries) {
      final url = await fetchDishImage(query);
      if (url != null) {
        images[query] = url;
      }
      // Simple rate limiting to be nice to the API
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return images;
  }
}
