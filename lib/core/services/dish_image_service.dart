import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DishImageService {
  // Cache for image URLs to avoid repeated API calls
  static final Map<String, String> _imageCache = {};

  Future<String?> fetchDishImage(String query) async {
    // Check cache first
    if (_imageCache.containsKey(query)) {
      return _imageCache[query];
    }

    // 1. Try TheMealDB first (good for specific named dishes)
    final mealDbUrl = await _fetchFromTheMealDB(query);
    if (mealDbUrl != null) {
      _imageCache[query] = mealDbUrl;
      return mealDbUrl;
    }

    // 2. Fallback to LoremFlickr (reliable keyword-based placeholder)
    final loremUrl = await _fetchFromLoremFlickr(query);
    if (loremUrl != null) {
      _imageCache[query] = loremUrl;
      return loremUrl;
    }

    // 3. Last resort: Generic random food image
    final genericUrl = await _fetchGenericFoodImage();
    if (genericUrl != null) {
      _imageCache[query] = genericUrl;
      return genericUrl;
    }

    return null;
  }

  Future<String?> _fetchFromTheMealDB(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://www.themealdb.com/api/json/v1/1/search.php?s=$query'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final meals = data['meals'] as List?;
        if (meals != null && meals.isNotEmpty) {
          return meals[0]['strMealThumb'] as String;
        }
      }
    } catch (e) {
      if (kDebugMode) print('TheMealDB Error for $query: $e');
    }
    return null;
  }

  Future<String?> _fetchFromLoremFlickr(String query) async {
    try {
      // LoremFlickr returns a direct image or a redirect
      final cleanQuery = query.replaceAll(' ', ',');
      final url = 'https://loremflickr.com/600/600/food,$cleanQuery';

      final response = await http.head(Uri.parse(url));

      if (response.statusCode == 200 || response.statusCode == 302) {
        // We return the source URL as it's reliable for loading in the app
        // or follow the location header if we want to store the final URL
        final location = response.headers['location'];
        if (location != null) {
          return location.startsWith('http')
              ? location
              : 'https://loremflickr.com$location';
        }
        return url;
      }
    } catch (e) {
      if (kDebugMode) print('LoremFlickr Error for $query: $e');
    }
    return null;
  }

  Future<String?> _fetchGenericFoodImage() async {
    try {
      final response =
          await http.get(Uri.parse('https://foodish-api.com/api/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image'] as String?;
      }
    } catch (e) {
      if (kDebugMode) print('Foodish Error: $e');
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
