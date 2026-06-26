import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_log_model.dart';
import '../models/dish_model.dart';
import '../models/recipe_model.dart';

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
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': dish.id,
      'dishName': dish.name,
      'calories': dish.calories.toDouble(),
      'protein': dish.protein.toDouble(),
      'carbs': dish.carbs.toDouble(),
      'fat': dish.fat.toDouble(),
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
  }

  /// Log a cooked recipe as a meal entry.
  Future<void> logRecipe({
    required String userId,
    required String mealType,
    required Recipe recipe,
  }) async {
    final now = DateTime.now();
    await _logsRef(userId).add({
      'userId': userId,
      'mealType': mealType,
      'dishId': recipe.id,
      'dishName': recipe.title,
      'calories': (recipe.macros['calories'] ?? 0).toDouble(),
      'protein': (recipe.macros['protein'] ?? 0).toDouble(),
      'carbs': (recipe.macros['carbs'] ?? 0).toDouble(),
      'fat': (recipe.macros['fat'] ?? 0).toDouble(),
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
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
}
