import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeProduct {
  final String barcode;
  final String name;
  final String? brand;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSizeG;
  final String? imageUrl;

  const BarcodeProduct({
    required this.barcode,
    required this.name,
    this.brand,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSizeG,
    this.imageUrl,
  });

  String get displayName => brand != null ? '$name ($brand)' : name;
}

class BarcodeNotFoundError implements Exception {
  final String barcode;
  const BarcodeNotFoundError(this.barcode);
  @override
  String toString() => 'Product not found for barcode: $barcode';
}

/// Looks up nutritional data by EAN/UPC barcode using Open Food Facts API.
class BarcodeLookupService {
  static final BarcodeLookupService _instance =
      BarcodeLookupService._internal();
  factory BarcodeLookupService() => _instance;
  BarcodeLookupService._internal();

  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v0/product';

  // Simple in-memory cache — keyed by barcode
  final Map<String, BarcodeProduct> _cache = {};

  Future<BarcodeProduct> lookupBarcode(String barcode) async {
    final cached = _cache[barcode];
    if (cached != null) return cached;

    debugPrint('BarcodeLookupService: looking up $barcode');

    final uri = Uri.parse('$_baseUrl/$barcode.json');
    final response = await http.get(uri, headers: {
      'User-Agent': 'Cookrange/1.0 (contact@cookrangeapp.com)',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw BarcodeNotFoundError(barcode);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as int? ?? 0;
    if (status != 1) throw BarcodeNotFoundError(barcode);

    final product = json['product'] as Map<String, dynamic>? ?? {};
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    final name = (product['product_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw BarcodeNotFoundError(barcode);

    // Prefer per-100g values; fall back to per-serving, then 0
    double n(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key] ?? 0;
      return (v as num?)?.toDouble() ?? 0.0;
    }

    final servingRaw = product['serving_size'] as String? ?? '';
    final servingG = _parseServingGrams(servingRaw);

    final result = BarcodeProduct(
      barcode: barcode,
      name: name,
      brand: (product['brands'] as String?)?.trim().split(',').first.trim(),
      calories: n('energy-kcal'),
      protein: n('proteins'),
      carbs: n('carbohydrates'),
      fat: n('fat'),
      servingSizeG: servingG > 0 ? servingG : 100,
      imageUrl: product['image_url'] as String?,
    );

    _cache[barcode] = result;
    debugPrint(
        'BarcodeLookupService: found "${result.name}" — ${result.calories} kcal/100g');
    return result;
  }

  /// Adjust nutrition values from per-100g to per-serving-size.
  BarcodeProduct forServing(BarcodeProduct product, double servingG) {
    final ratio = servingG / 100.0;
    return BarcodeProduct(
      barcode: product.barcode,
      name: product.name,
      brand: product.brand,
      calories: product.calories * ratio,
      protein: product.protein * ratio,
      carbs: product.carbs * ratio,
      fat: product.fat * ratio,
      servingSizeG: servingG,
      imageUrl: product.imageUrl,
    );
  }

  double _parseServingGrams(String raw) {
    if (raw.isEmpty) return 0;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(raw.toLowerCase());
    if (match != null) return double.tryParse(match.group(1)!) ?? 0;
    final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    if (numMatch != null) return double.tryParse(numMatch.group(1)!) ?? 0;
    return 0;
  }
}
