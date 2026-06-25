import 'package:cloud_firestore/cloud_firestore.dart';

/// A single food log entry — one meal the user has eaten.
/// Stored at: users/{uid}/food_logs/{logId}
class FoodLog {
  final String id;
  final String userId;
  final String mealType; // breakfast | lunch | dinner | snack
  final String dishId;
  final String dishName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime loggedAt;
  final String date; // YYYY-MM-DD — used for daily query key

  const FoodLog({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.dishId,
    required this.dishName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.loggedAt,
    required this.date,
  });

  factory FoodLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FoodLog(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      mealType: data['mealType'] as String? ?? '',
      dishId: data['dishId'] as String? ?? '',
      dishName: data['dishName'] as String? ?? '',
      calories: (data['calories'] as num?)?.toDouble() ?? 0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0,
      carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0,
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      date: data['date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'mealType': mealType,
        'dishId': dishId,
        'dishName': dishName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'loggedAt': Timestamp.fromDate(loggedAt),
        'date': date,
      };

  /// Summarises today's logs into totals.
  static NutritionTotals sumLogs(List<FoodLog> logs) {
    double cal = 0, protein = 0, carbs = 0, fat = 0;
    for (final l in logs) {
      cal += l.calories;
      protein += l.protein;
      carbs += l.carbs;
      fat += l.fat;
    }
    return NutritionTotals(
      calories: cal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }
}

class NutritionTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const NutritionTotals zero = NutritionTotals(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );
}
