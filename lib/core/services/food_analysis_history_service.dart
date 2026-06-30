import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'food_analysis_service.dart';

/// Persists recent AI food-analysis results to `users/{uid}/food_analyses`
/// (owner-only) so users can review and re-log past analyses.
class FoodAnalysisHistoryService {
  static final FoodAnalysisHistoryService _instance =
      FoodAnalysisHistoryService._internal();
  factory FoodAnalysisHistoryService() => _instance;
  FoodAnalysisHistoryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('food_analyses');

  /// Saves an analysis result. Best-effort — never throws into the UI.
  Future<void> save(String uid, NutritionEstimate est) async {
    try {
      await _col(uid).add({
        ...est.toJson(),
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('[FoodAnalysisHistory] saved "${est.foodName}" for $uid');
    } catch (e) {
      debugPrint('[FoodAnalysisHistory] save failed: $e');
    }
  }

  /// Streams the most recent [limit] analyses, newest first.
  Stream<List<NutritionEstimate>> streamRecent(String uid, {int limit = 30}) {
    return _col(uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NutritionEstimate.fromJson(d.data())).toList())
        .handleError((Object e) {
      debugPrint('[FoodAnalysisHistory] stream error: $e');
    });
  }
}
