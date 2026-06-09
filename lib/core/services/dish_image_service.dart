import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DishImageService {
  // Cache for image URLs to avoid repeated API calls
  static final Map<String, String> _imageCache = {};

  Future<String?> fetchDishImage(String query, {String source = 'auto'}) async {
    final cleanQuery = query.trim().toLowerCase();

    // Check cache first
    if (_imageCache.containsKey(cleanQuery)) {
      return _imageCache[cleanQuery];
    }

    if (source == 'loremflickr' || source == 'auto') {
      final loremUrl = await fetchFromLoremFlickr(cleanQuery);
      if (loremUrl != null) {
        // We don't cache in the service's memory for the seeder app
        // to always allow new signatures to be generated for refresh
        return loremUrl;
      }
    }

    if (source == 'pixabay' || source == 'auto') {
      final pixabayUrl = await fetchFromPixabay(cleanQuery);
      if (pixabayUrl != null) {
        return pixabayUrl;
      }
    }

    if (source == 'themealdb' || source == 'auto') {
      final mealDbUrl = await fetchFromTheMealDB(cleanQuery);
      if (mealDbUrl != null) {
        return mealDbUrl;
      }
    }

    if (source == 'foodish' || source == 'auto') {
      final foodishUrl = await fetchFromFoodish(cleanQuery);
      if (foodishUrl != null) {
        return foodishUrl;
      }
    }

    if (source == 'picsum') {
      final picsumUrl = await fetchFromPicsum(cleanQuery);
      if (picsumUrl != null) {
        return picsumUrl;
      }
    }

    return null;
  }

  Future<String?> fetchFromTheMealDB(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://www.themealdb.com/api/json/v1/1/search.php?s=$query'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final meals = data['meals'] as List?;
        if (meals != null && meals.isNotEmpty) {
          // Find the best match if multiple returned
          return meals[0]['strMealThumb'] as String;
        }
      }
    } catch (e) {
      if (kDebugMode) print('TheMealDB Error for $query: $e');
    }
    return null;
  }

  Future<String?> fetchFromLoremFlickr(String query) async {
    try {
      // Relaxed query: try specific first, then broader
      final sig = DateTime.now().millisecondsSinceEpoch;

      // If query is too long, it often fails. Take max 3 keywords.
      final shortQuery = query.split(' ').take(3).join(',');

      return 'https://loremflickr.com/800/600/food,dish,$shortQuery/all?lock=$sig';
    } catch (e) {
      if (kDebugMode) print('LoremFlickr Error for $query: $e');
    }
    return null;
  }

  Future<String?> fetchFromUnsplash(String query) async {
    try {
      final searchKeywords = 'food,dish,culinary,${query.replaceAll(' ', ',')}';
      final sig = DateTime.now().millisecondsSinceEpoch;
      return 'https://source.unsplash.com/800x600/?$searchKeywords&sig=$sig';
    } catch (e) {
      if (kDebugMode) print('Unsplash Error for $query: $e');
    }
    return null;
  }

  Future<String?> fetchFromFoodish(String query) async {
    try {
      // Foodish API categories: biryani, burger, butter-chicken, dessert, dosa, idli, pasta, pizza, rice, samosa
      final categories = [
        'biryani',
        'burger',
        'butter-chicken',
        'dessert',
        'dosa',
        'idli',
        'pasta',
        'pizza',
        'rice',
        'samosa'
      ];

      String category = 'pizza'; // default
      for (var cat in categories) {
        if (query.contains(cat)) {
          category = cat;
          break;
        }
      }

      final response = await http
          .get(Uri.parse('https://foodish-api.com/api/images/$category'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image'] as String?;
      }
    } catch (e) {
      if (kDebugMode) print('Foodish Error for $query: $e');
    }
    return null;
  }

  Future<String?> fetchFromPicsum(String query) async {
    try {
      // Picsum needs a seed for randomness and cache busting
      final seed = DateTime.now().millisecondsSinceEpoch;
      return 'https://picsum.photos/seed/$seed/800/600';
    } catch (e) {
      if (kDebugMode) print('Picsum Error: $e');
    }
    return null;
  }

  Future<String?> fetchFromPixabay(String query) async {
    try {
      // Pixabay public API (usually needs key, but some regions/IPs allow limited access or we check for a public one)
      // For now, let's use a public-ish endpoint if available or just return a formatted query URL for manual check
      // Actually, Pixabay requires a key. I'll search for another no-key accurate source.
      // How about 'PlaceKitten' for food? No.
      // Let's use 'https://www.themealdb.com/images/ingredients/$query.png' as a crazy fallback
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>> fetchBatchImages(List<String> queries) async {
    final Map<String, String> images = {};
    for (final query in queries) {
      final url = await fetchDishImage(query);
      if (url != null) {
        images[query] = url;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return images;
  }
}
