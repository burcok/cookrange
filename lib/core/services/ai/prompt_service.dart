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
}
