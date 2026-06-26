import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DishImageService {
  static final Map<String, String> _imageCache = {};

  /// Fetches a food image for [query], trying sources in priority order.
  ///
  /// [seed] makes the result deterministic — use the dish ID so the same
  /// dish always resolves to the same image across seeder runs.
  Future<String?> fetchDishImage(String query,
      {String source = 'auto', String? seed}) async {
    final cleanQuery = query.trim().toLowerCase();
    final cacheKey = seed != null ? '${seed}_$cleanQuery' : cleanQuery;

    if (_imageCache.containsKey(cacheKey)) return _imageCache[cacheKey];

    String? result;

    if (source == 'auto') {
      // 1. TheMealDB — best match for international/Mediterranean dishes
      result = await fetchFromTheMealDB(cleanQuery);

      // 2. Unsplash via source API — food-specific, deterministic seed
      result ??= await fetchFromUnsplash(cleanQuery, seed: seed ?? cleanQuery);

      // 3. LoremFlickr as stable fallback — seed from query so it's consistent
      result ??= fetchFromLoremFlickr(cleanQuery, seed: seed ?? cleanQuery);
    } else if (source == 'themealdb') {
      result = await fetchFromTheMealDB(cleanQuery);
    } else if (source == 'unsplash') {
      result = await fetchFromUnsplash(cleanQuery, seed: seed ?? cleanQuery);
    } else if (source == 'loremflickr') {
      result = fetchFromLoremFlickr(cleanQuery, seed: seed ?? cleanQuery);
    } else if (source == 'picsum') {
      result = fetchFromPicsum(seed: seed ?? cleanQuery);
    }

    if (result != null) _imageCache[cacheKey] = result;
    return result;
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
          return meals[0]['strMealThumb'] as String?;
        }
      }
    } catch (e) {
      if (kDebugMode) print('TheMealDB Error for $query: $e');
    }
    return null;
  }

  /// Stable Unsplash image using the source API.
  ///
  /// Uses [seed] (usually the dish ID) so the same dish always maps to the
  /// same Unsplash photo, regardless of when the seeder runs.
  Future<String?> fetchFromUnsplash(String query, {String? seed}) async {
    try {
      // Build a food-focused query, keeping it to ≤4 keywords for accuracy.
      final keywords =
          'food,dish,${query.split(' ').take(3).join(',')}';
      // Stable numeric seed derived from the seed string
      final numericSeed = seed != null
          ? seed.codeUnits.fold(0, (p, e) => p + e) % 1000
          : query.codeUnits.fold(0, (p, e) => p + e) % 1000;
      return 'https://source.unsplash.com/800x600/?$keywords&sig=$numericSeed';
    } catch (e) {
      if (kDebugMode) print('Unsplash Error for $query: $e');
    }
    return null;
  }

  /// Deterministic LoremFlickr URL using [seed] as the lock.
  ///
  /// LoremFlickr keeps the same image as long as the `lock` number is fixed,
  /// so using the dish ID ensures consistency across seeder runs.
  String fetchFromLoremFlickr(String query, {required String seed}) {
    final shortQuery = query.split(' ').take(3).join(',');
    final lock = seed.codeUnits.fold(0, (p, e) => p + e) % 99999;
    return 'https://loremflickr.com/800/600/food,dish,$shortQuery/all?lock=$lock';
  }

  /// Random Picsum photo (no food relevance — use only as last resort).
  String fetchFromPicsum({String? seed}) {
    final s = seed ?? 'food';
    final lock = s.codeUnits.fold(0, (p, e) => p + e) % 99999;
    return 'https://picsum.photos/seed/$lock/800/600';
  }

  Future<Map<String, String>> fetchBatchImages(List<String> queries,
      {List<String>? seeds}) async {
    final Map<String, String> images = {};
    for (int i = 0; i < queries.length; i++) {
      final query = queries[i];
      final seed = seeds != null && i < seeds.length ? seeds[i] : null;
      final url = await fetchDishImage(query, seed: seed);
      if (url != null) images[query] = url;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return images;
  }
}
