class Ingredient {
  final String name;
  final double amount;
  final String unit;
  final double calories;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.calories,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      calories: (json['calories'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'calories': calories,
    };
  }

  Ingredient copyWith({
    String? name,
    double? amount,
    String? unit,
    double? calories,
  }) {
    return Ingredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
    );
  }
}
