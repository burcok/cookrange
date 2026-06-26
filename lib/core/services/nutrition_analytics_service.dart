import '../models/food_log_model.dart';

class DailyNutrition {
  final String date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool hasLogs;

  const DailyNutrition({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.hasLogs,
  });
}

class WeeklyNutritionSummary {
  final List<DailyNutrition> days;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int consistencyScore; // 0–100
  final int loggedDays;

  const WeeklyNutritionSummary({
    required this.days,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.consistencyScore,
    required this.loggedDays,
  });

  static const WeeklyNutritionSummary empty = WeeklyNutritionSummary(
    days: [],
    avgCalories: 0,
    avgProtein: 0,
    avgCarbs: 0,
    avgFat: 0,
    consistencyScore: 0,
    loggedDays: 0,
  );
}

class NutritionAnalyticsService {
  static final NutritionAnalyticsService _instance =
      NutritionAnalyticsService._internal();
  factory NutritionAnalyticsService() => _instance;
  NutritionAnalyticsService._internal();

  WeeklyNutritionSummary computeWeeklySummary(
    Map<String, List<FoodLog>> logsMap,
    double targetCalories,
  ) {
    final days = logsMap.entries.map((e) {
      final logs = e.value;
      final totals = FoodLog.sumLogs(logs);
      return DailyNutrition(
        date: e.key,
        calories: totals.calories,
        protein: totals.protein,
        carbs: totals.carbs,
        fat: totals.fat,
        hasLogs: logs.isNotEmpty,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final logged = days.where((d) => d.hasLogs).toList();
    final loggedDays = logged.length;

    if (loggedDays == 0) return WeeklyNutritionSummary.empty;

    final avgCal = logged.map((d) => d.calories).reduce((a, b) => a + b) / loggedDays;
    final avgProt = logged.map((d) => d.protein).reduce((a, b) => a + b) / loggedDays;
    final avgCarbs = logged.map((d) => d.carbs).reduce((a, b) => a + b) / loggedDays;
    final avgFat = logged.map((d) => d.fat).reduce((a, b) => a + b) / loggedDays;

    final totalDays = days.length;
    final loggingRate = loggedDays / totalDays;

    // Calorie accuracy: how close avg is to target (within 20% = full score)
    double calorieAccuracy = 1.0;
    if (targetCalories > 0) {
      final deviation = (avgCal - targetCalories).abs() / targetCalories;
      calorieAccuracy = (1.0 - (deviation / 0.2)).clamp(0.0, 1.0);
    }

    final score = ((loggingRate * 70) + (calorieAccuracy * 30)).round().clamp(0, 100);

    return WeeklyNutritionSummary(
      days: days,
      avgCalories: avgCal,
      avgProtein: avgProt,
      avgCarbs: avgCarbs,
      avgFat: avgFat,
      consistencyScore: score,
      loggedDays: loggedDays,
    );
  }
}
