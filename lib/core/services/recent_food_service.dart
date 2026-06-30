import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_log_model.dart';
import 'auth_service.dart';

/// Tracks the 20 most recently and most frequently logged foods per user.
/// Collection: users/{uid}/recent_foods/{foodId}
class RecentFoodService {
  static final RecentFoodService _instance = RecentFoodService._internal();
  factory RecentFoodService() => _instance;
  RecentFoodService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;
  static const int _maxRecent = 20;

  CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('recent_foods');

  /// Called after every successful food log — upserts the food entry.
  Future<void> recordFood({
    required String dishId,
    required String dishName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final docRef = _ref(uid).doc(dishId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          'logCount': FieldValue.increment(1),
          'lastLoggedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Enforce max limit (cheap: count query then delete oldest)
        final snap = await _ref(uid)
            .orderBy('lastLoggedAt', descending: false)
            .limit(1)
            .get();
        final count = (await _ref(uid).count().get()).count ?? 0;
        if (count >= _maxRecent && snap.docs.isNotEmpty) {
          await snap.docs.first.reference.delete();
        }
        await docRef.set({
          'dishId': dishId,
          'dishName': dishName,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'logCount': 1,
          'lastLoggedAt': FieldValue.serverTimestamp(),
          'firstLoggedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('RecentFoodService.recordFood error: $e');
    }
  }

  /// Get recent foods sorted by last logged time.
  Future<List<RecentFoodEntry>> getRecentFoods({int limit = 10}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _ref(uid)
          .orderBy('lastLoggedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => RecentFoodEntry.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('RecentFoodService.getRecentFoods error: $e');
      return [];
    }
  }

  /// Get frequent foods sorted by log count.
  Future<List<RecentFoodEntry>> getFrequentFoods({int limit = 10}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _ref(uid)
          .orderBy('logCount', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => RecentFoodEntry.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('RecentFoodService.getFrequentFoods error: $e');
      return [];
    }
  }
}

class RecentFoodEntry {
  final String dishId;
  final String dishName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int logCount;

  const RecentFoodEntry({
    required this.dishId,
    required this.dishName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.logCount,
  });

  factory RecentFoodEntry.fromMap(Map<String, dynamic> map) => RecentFoodEntry(
        dishId: map['dishId'] as String? ?? '',
        dishName: map['dishName'] as String? ?? '',
        calories: (map['calories'] as num? ?? 0).toDouble(),
        protein: (map['protein'] as num? ?? 0).toDouble(),
        carbs: (map['carbs'] as num? ?? 0).toDouble(),
        fat: (map['fat'] as num? ?? 0).toDouble(),
        logCount: (map['logCount'] as num? ?? 1).toInt(),
      );

  NutritionTotals get totals => NutritionTotals(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
}
