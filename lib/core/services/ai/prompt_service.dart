class PromptService {
  static final PromptService _instance = PromptService._internal();
  factory PromptService() => _instance;
  PromptService._internal();

  /// Generates a prompt for ingredient validation
  String validateIngredientPrompt(String query) {
    return '''
Analyze the food item: "$query".
Return a JSON object with:
{
  "label": "Display Name (Capitalized)",
  "value": "normalized_snake_case_value",
  "icon": "category_icon_name" (one of: vegetable, fruit, protein, dairy, grain, nut, other),
  "calories": approx_calories_per_100g (number)
}
''';
  }

  /// Generates a prompt for recipe suggestions
  String generateRecipePrompt({
    required List<String> ingredients,
    required double targetCalories,
    required List<String> dietaryRestrictions,
  }) {
    return '''
Create a recipe using these ingredients: ${ingredients.join(', ')}.
Target Calories: $targetCalories.
Dietary Restrictions: ${dietaryRestrictions.join(', ')}.

Return fully structured JSON matching this schema:
{
  "title": "Recipe Title",
  "description": "Short appetizing description",
  "prepTimeMinutes": 15,
  "cookTimeMinutes": 20,
  "servings": 2,
  "difficulty": "Easy/Medium/Hard",
  "ingredients": [
    {"name": "Ingredient 1", "amount": 100, "unit": "g", "calories": 50}
  ],
  "instructions": ["Step 1", "Step 2"],
  "macros": {
    "protein": 20,
    "carbs": 30,
    "fat": 10,
    "calories": Total (close to target)
  },
  "tags": ["Tag1", "Tag2"]
}
''';
  }

  /// Generates a comprehensive weekly meal plan prompt
  String generateWeeklyMealPlanPrompt({
    required Map<String, dynamic> userProfile, // extracted from UserModel
    required List<dynamic>
        availableDishes, // List of DishModel (passed as dry objects or stringified)
    required double dailyCalorieTarget,
  }) {
    // 1. Format available dishes for the prompt
    final dishesContext = availableDishes.map((d) {
      if (d is Map) {
        return "- [${d['id']}] ${d['name']} (${d['category']}): ${d['calories']}kcal (P:${d['protein']} C:${d['carbs']} F:${d['fat']})";
      }
      // Assuming DishModel has toJson or similar
      return "- [${d.id}] ${d.name} (${d.category}): ${d.calories}kcal (P:${d.protein} C:${d.carbs} F:${d.fat})";
    }).join('\n');

    final jsonSchema = '''
{
  "total_calories": 14000,
  "avg_daily_calories": 2000,
  "avg_macros": { "protein": 150, "carbs": 200, "fat": 70 },
  "days": [
    {
      "day_name": "Monday",
      "date_offset": 0,
      "meals": {
        "breakfast": "dish_id_1",
        "lunch": "dish_id_2",
        "dinner": "dish_id_3",
        "snack": "dish_id_4" 
      },
      "total_calories": 2000,
      "macros": { "protein": 150, "carbs": 200, "fat": 70 }
    }
  ] (7 days total)
}
''';

    return '''
Act as a professional nutritionist and personal chef. Create a 7-day weekly meal plan for a user with the following profile:

Profile:
- Goal: ${userProfile['goal']}
- Daily Calorie Target: $dailyCalorieTarget kcal
- Dietary Restrictions: ${userProfile['restrictions']}
- Dislikes: ${userProfile['dislikes']}
- Activity Level: ${userProfile['activity_level']}
- Meal Frequency: 3 main meals + optional snack

Task:
Select dishes ONLY from the following list to build the plan. Do not invent new dishes. You must use the EXACT IDs provided in brackets [id].
Ensure nutritional balance and variety. Try to use ingredients efficiently (e.g., if chicken is cooked for lunch, maybe use chicken for dinner another day, but avoid repetition in same day).

Available Dishes Database:
$dishesContext

Return strictly valid JSON matching this structure:
$jsonSchema
''';
  }
}
