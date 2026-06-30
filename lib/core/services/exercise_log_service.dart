import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/exercise_log_model.dart';

/// Manages exercise/activity logs for calorie-burn tracking.
/// Collection: users/{uid}/exercise_logs/{logId}
class ExerciseLogService {
  static final ExerciseLogService _instance = ExerciseLogService._internal();
  factory ExerciseLogService() => _instance;
  ExerciseLogService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('exercise_logs');

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> logExercise({
    required String userId,
    required String exerciseKey,
    required int durationMinutes,
    required double caloriesBurned,
  }) async {
    final now = DateTime.now();
    await _ref(userId).add({
      'exerciseKey': exerciseKey,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'loggedAt': Timestamp.fromDate(now),
      'date': _todayKey(),
    });
    debugPrint('ExerciseLogService: logged $exerciseKey ${durationMinutes}min '
        '${caloriesBurned.toInt()}kcal for $userId');
  }

  /// Real-time stream of today's exercise logs.
  Stream<List<ExerciseLog>> todayLogsStream(String userId) {
    final today = _todayKey();
    return _ref(userId)
        .where('date', isEqualTo: today)
        .orderBy('loggedAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ExerciseLog.fromFirestore(d)).toList())
        .handleError((Object e) {
      debugPrint('ExerciseLogService stream error: $e');
      return <ExerciseLog>[];
    });
  }

  Future<void> deleteLog(String userId, String logId) async {
    await _ref(userId).doc(logId).delete();
  }
}
