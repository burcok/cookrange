class MealPlan {
  final DateTime date;
  final Map<String, String>
      meals; // MealType (breakfast, lunch, dinner) -> RecipeId
  final double totalCalories;
  final Map<String, double> totalMacros;

  const MealPlan({
    required this.date,
    required this.meals,
    required this.totalCalories,
    required this.totalMacros,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      date: DateTime.parse(json['date'] as String),
      meals: Map<String, String>.from(json['meals'] as Map),
      totalCalories: (json['totalCalories'] as num).toDouble(),
      totalMacros: Map<String, double>.from(json['totalMacros'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'meals': meals,
      'totalCalories': totalCalories,
      'totalMacros': totalMacros,
    };
  }
}
