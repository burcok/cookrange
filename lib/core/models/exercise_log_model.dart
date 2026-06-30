import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseType {
  final String key;
  final double met;

  const ExerciseType({required this.key, required this.met});

  static const all = [
    ExerciseType(key: 'running', met: 9.8),
    ExerciseType(key: 'walking', met: 3.5),
    ExerciseType(key: 'cycling', met: 7.0),
    ExerciseType(key: 'swimming', met: 6.0),
    ExerciseType(key: 'weight_training', met: 5.0),
    ExerciseType(key: 'hiit', met: 8.0),
    ExerciseType(key: 'yoga', met: 2.5),
    ExerciseType(key: 'jump_rope', met: 11.0),
    ExerciseType(key: 'basketball', met: 6.5),
    ExerciseType(key: 'football', met: 7.0),
    ExerciseType(key: 'dancing', met: 5.0),
    ExerciseType(key: 'other', met: 4.0),
  ];

  /// Estimated calories burned: MET × weight(kg) × duration(hours)
  double estimateCalories(
      {required double weightKg, required int durationMinutes}) {
    return met * weightKg * (durationMinutes / 60.0);
  }
}

class ExerciseLog {
  final String id;
  final String exerciseKey;
  final int durationMinutes;
  final double caloriesBurned;
  final DateTime loggedAt;
  final String date;

  const ExerciseLog({
    required this.id,
    required this.exerciseKey,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.loggedAt,
    required this.date,
  });

  factory ExerciseLog.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExerciseLog(
      id: doc.id,
      exerciseKey: data['exerciseKey'] as String? ?? 'other',
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble() ?? 0,
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      date: data['date'] as String? ?? '',
    );
  }

  static double totalBurned(List<ExerciseLog> logs) =>
      logs.fold(0, (total, l) => total + l.caloriesBurned);
}
