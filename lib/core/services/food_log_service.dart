import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_log_model.dart';
import '../models/dish_model.dart';
import '../models/recipe_model.dart';
import 'food_analysis_service.dart';
import 'barcode_lookup_service.dart';
import 'recent_food_service.dart';

/// Manages food/meal logging for a user.
/// Collection: users/{uid}/food_logs/{logId}
class FoodLogService {
  static final FoodLogService _instance = FoodLogService._internal();
  factory FoodLogService() => _instance;
  FoodLogService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsRef(String uid) =>
      _db.collection('users').doc(uid).collection('food_logs');

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Log a dish from the meal plan as eaten.
  Future<void> logMeal({
    required String userId,
    required String mealType,
    required DishModel dish,
  }) async {
    final now = DateTime.now();
    final cal = dish.calories.toDouble();
    final p = dish.protein.toDouble();
    final c = dish.carbs.toDouble();
    final f = dish.fat.toDouble();
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': dish.id,
      'dishName': dish.name,
      'calories': cal,
      'protein': p,
      'carbs': c,
      'fat': f,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
    unawaited(RecentFoodService().recordFood(
      dishId: dish.id,
      dishName: dish.name,
      calories: cal,
      protein: p,
      carbs: c,
      fat: f,
    ));
  }

  /// Log a cooked recipe as a meal entry.
  Future<void> logRecipe({
    required String userId,
    required String mealType,
    required Recipe recipe,
  }) async {
    final now = DateTime.now();
    final cal = (recipe.macros['calories'] ?? 0).toDouble();
    final p = (recipe.macros['protein'] ?? 0).toDouble();
    final c = (recipe.macros['carbs'] ?? 0).toDouble();
    final f = (recipe.macros['fat'] ?? 0).toDouble();
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': recipe.id,
      'dishName': recipe.title,
      'calories': cal,
      'protein': p,
      'carbs': c,
      'fat': f,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
    unawaited(RecentFoodService().recordFood(
      dishId: recipe.id,
      dishName: recipe.title,
      calories: cal,
      protein: p,
      carbs: c,
      fat: f,
    ));
  }

  /// Log an AI-analyzed food description as a meal entry.
  Future<void> logScannedFood({
    required String userId,
    required String mealType,
    required NutritionEstimate estimate,
  }) async {
    final now = DateTime.now();
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': 'scanned_${now.millisecondsSinceEpoch}',
      'dishName': estimate.foodName,
      'calories': estimate.calories,
      'protein': estimate.protein,
      'carbs': estimate.carbs,
      'fat': estimate.fat,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
  }

  /// Log a food entry from quick-add (recent/frequent foods).
  Future<void> logQuickFood({
    required String userId,
    required String mealType,
    required String dishId,
    required String dishName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final now = DateTime.now();
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': dishId,
      'dishName': dishName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
    unawaited(RecentFoodService().recordFood(
      dishId: dishId,
      dishName: dishName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    ));
  }

  /// Log a barcode-scanned packaged food product.
  Future<void> logBarcodeFood({
    required String userId,
    required String mealType,
    required BarcodeProduct product,
    double? customServingG,
  }) async {
    final now = DateTime.now();
    final serving = customServingG ?? product.servingSizeG;
    final ratio = serving / 100.0;
    final cal = product.calories * ratio;
    final p = product.protein * ratio;
    final c = product.carbs * ratio;
    final f = product.fat * ratio;

    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': 'barcode_${product.barcode}',
      'dishName': product.displayName,
      'calories': cal,
      'protein': p,
      'carbs': c,
      'fat': f,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
    unawaited(RecentFoodService().recordFood(
      dishId: 'barcode_${product.barcode}',
      dishName: product.displayName,
      calories: cal,
      protein: p,
      carbs: c,
      fat: f,
    ));
  }

  /// Remove a previously logged meal entry.
  Future<void> removeLog(String userId, String logId) async {
    await _logsRef(userId).doc(logId).delete();
  }

  /// Real-time stream of today's food logs.
  Stream<List<FoodLog>> todayLogsStream(String userId) {
    final today = _todayKey();
    return _logsRef(userId)
        .where('date', isEqualTo: today)
        .orderBy('loggedAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => FoodLog.fromFirestore(d)).toList(),
        )
        .handleError((Object e) {
      debugPrint('FoodLogService stream error: $e');
      return <FoodLog>[];
    });
  }

  /// Returns the set of meal types already logged today
  /// (e.g. {'breakfast', 'lunch'}).
  Stream<Set<String>> todayLoggedMealTypesStream(String userId) {
    return todayLogsStream(userId).map(
      (logs) => logs.map((l) => l.mealType).toSet(),
    );
  }

  /// One-shot fetch of today's nutrition totals.
  Future<NutritionTotals> getTodayTotals(String userId) async {
    try {
      final today = _todayKey();
      final snap = await _logsRef(userId)
          .where('date', isEqualTo: today)
          .get();
      final logs = snap.docs.map((d) => FoodLog.fromFirestore(d)).toList();
      return FoodLog.sumLogs(logs);
    } catch (e) {
      debugPrint('FoodLogService.getTodayTotals error: $e');
      return NutritionTotals.zero;
    }
  }

  /// Fetches logs for each day in [start]..[end] (inclusive).
  ///
  /// Returns a map keyed by `YYYY-MM-DD` date string.
  /// Days with no logs are still present with an empty list.
  Future<Map<String, List<FoodLog>>> getLogsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final result = <String, List<FoodLog>>{};
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      result[_dateKey(d)] = [];
    }
    try {
      final startKey = _dateKey(start);
      final endKey = _dateKey(end);
      final snap = await _logsRef(userId)
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .get();
      for (final doc in snap.docs) {
        final log = FoodLog.fromFirestore(doc);
        result.putIfAbsent(log.date, () => []).add(log);
      }
    } catch (e) {
      debugPrint('FoodLogService.getLogsForDateRange error: $e');
    }
    return result;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
