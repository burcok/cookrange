class Ingredient {
  final String name;
  final double amount;
  final String unit;
  final double calories;

  /// Shopping-list provenance (empty for recipe/dish ingredients):
  /// display names of the dishes/meals that require this ingredient.
  final List<String> sourceMeals;

  /// Shopping-list provenance: `yyyy-MM-dd` dates of the meal-plan days that
  /// require this ingredient. Used for the Today / This-week filters.
  final List<String> sourceDates;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.calories,
    this.sourceMeals = const [],
    this.sourceDates = const [],
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      calories: (json['calories'] as num).toDouble(),
      sourceMeals: List<String>.from(json['source_meals'] ?? const []),
      sourceDates: List<String>.from(json['source_dates'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'calories': calories,
      // Only serialize provenance when present (keeps dish/recipe docs clean).
      if (sourceMeals.isNotEmpty) 'source_meals': sourceMeals,
      if (sourceDates.isNotEmpty) 'source_dates': sourceDates,
    };
  }

  Ingredient copyWith({
    String? name,
    double? amount,
    String? unit,
    double? calories,
    List<String>? sourceMeals,
    List<String>? sourceDates,
  }) {
    return Ingredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
      sourceMeals: sourceMeals ?? this.sourceMeals,
      sourceDates: sourceDates ?? this.sourceDates,
    );
  }
}
