import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyMealPlanModel {
  final String id;
  final String userId;
  final DateTime weekStartDate;
  final List<DayMealPlan> days; // 7 days

  // Nutritional Totals (Average per day)
  final double totalCalories;
  final double avgDailyCalories;
  final Map<String, double> avgMacros;

  // Caching Metadata
  final DateTime createdAt;
  final DateTime? regeneratedAt;
  final DateTime expiresAt;
  final String generationPromptHash; // To detect if user profile changed

  // AI Generation Info
  final bool isAiGenerated;
  final String? aiModel;

  WeeklyMealPlanModel({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.days,
    required this.totalCalories,
    required this.avgDailyCalories,
    required this.avgMacros,
    required this.createdAt,
    this.regeneratedAt,
    required this.expiresAt,
    required this.generationPromptHash,
    this.isAiGenerated = true,
    this.aiModel,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory WeeklyMealPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklyMealPlanModel.fromJson(data, doc.id);
  }

  factory WeeklyMealPlanModel.fromJson(Map<String, dynamic> json,
      [String? id]) {
    return WeeklyMealPlanModel(
      id: id ?? json['id'] as String,
      userId: json['user_id'] as String,
      weekStartDate: (json['week_start_date'] as Timestamp).toDate(),
      days: (json['days'] as List)
          .map((d) => DayMealPlan.fromJson(d as Map<String, dynamic>))
          .toList(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      avgDailyCalories: (json['avg_daily_calories'] as num).toDouble(),
      avgMacros: (json['avg_macros'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
      createdAt: (json['created_at'] as Timestamp).toDate(),
      regeneratedAt: json['regenerated_at'] != null
          ? (json['regenerated_at'] as Timestamp).toDate()
          : null,
      expiresAt: (json['expires_at'] as Timestamp).toDate(),
      generationPromptHash: json['generation_prompt_hash'] as String? ?? '',
      isAiGenerated: json['is_ai_generated'] as bool? ?? true,
      aiModel: json['ai_model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'week_start_date': Timestamp.fromDate(weekStartDate),
      'days': days.map((d) => d.toJson()).toList(),
      'total_calories': totalCalories,
      'avg_daily_calories': avgDailyCalories,
      'avg_macros': avgMacros,
      'created_at': Timestamp.fromDate(createdAt),
      'regenerated_at':
          regeneratedAt != null ? Timestamp.fromDate(regeneratedAt!) : null,
      'expires_at': Timestamp.fromDate(expiresAt),
      'generation_prompt_hash': generationPromptHash,
      'is_ai_generated': isAiGenerated,
      'ai_model': aiModel,
    };
  }
}

class DayMealPlan {
  final DateTime date;
  final String dayName; // Monday, Tuesday, etc.
  final Map<String, String>
      meals; // mealType -> dishId (e.g. breakfast -> dish_123)
  final double totalCalories;
  final Map<String, double> macros;

  DayMealPlan({
    required this.date,
    required this.dayName,
    required this.meals,
    required this.totalCalories,
    required this.macros,
  });

  factory DayMealPlan.fromJson(Map<String, dynamic> json) {
    return DayMealPlan(
      date: (json['date'] as Timestamp).toDate(),
      dayName: json['day_name'] as String,
      meals: Map<String, String>.from(json['meals'] as Map),
      totalCalories: (json['total_calories'] as num).toDouble(),
      macros: (json['macros'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
      'day_name': dayName,
      'meals': meals,
      'total_calories': totalCalories,
      'macros': macros,
    };
  }
}
