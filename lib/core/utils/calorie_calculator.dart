
class CalorieCalculator {
  // Calculates Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
  static double calculateBMR({
    required double weight, // in kg
    required double height, // in cm
    required int age,
    required String gender, // "Male" or "Female"
  }) {
    if (gender == "Male") {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      // Assuming "Female"
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

  // Calculates Total Daily Energy Expenditure (TDEE)
  static double calculateTDEE({
    required double bmr,
    required String activityLevel, // Matches keys from onboarding
  }) {
    switch (activityLevel) {
      case 'Sedentary':
        return bmr * 1.2;
      case 'Lightly active':
        return bmr * 1.375;
      case 'Moderately active':
        return bmr * 1.55;
      case 'Very active':
        return bmr * 1.725;
      case 'Extra active':
        return bmr * 1.9;
      default:
        return bmr * 1.2; // Default to sedentary
    }
  }

  // Adjusts TDEE based on the primary goal
  static double adjustTDEEForGoal({
    required double tdee,
    required String primaryGoal, // Matches keys from onboarding
  }) {
    switch (primaryGoal) {
      case 'Lose Weight':
        return tdee - 500; // Caloric deficit of 500 kcal for weight loss
      case 'Gain Muscle':
        return tdee + 500; // Caloric surplus of 500 kcal for muscle gain
      case 'Maintain Weight':
      default:
        return tdee; // No adjustment
    }
  }

  // Calculates macronutrient distribution
  static Map<String, double> calculateMacros(double calories) {
    // Standard distribution: 40% Carbs, 30% Protein, 30% Fat
    double carbsGrams = (calories * 0.40) / 4;
    double proteinGrams = (calories * 0.30) / 4;
    double fatGrams = (calories * 0.30) / 9;

    return {
      'carbs': carbsGrams,
      'protein': proteinGrams,
      'fat': fatGrams,
    };
  }
}
