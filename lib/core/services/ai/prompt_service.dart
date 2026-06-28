class PromptService {
  static final PromptService _instance = PromptService._internal();
  factory PromptService() => _instance;
  PromptService._internal();

  // ─── Language directive ────────────────────────────────────────────────────

  /// Returns a language instruction appended to every prompt so the model
  /// always responds in the user's active app locale. Never omit this.
  String localeInstruction(String locale) {
    if (locale == 'tr') {
      return '\n\nÖNEMLİ: Tüm yanıtları, tüm metin alanları dahil, yalnızca Türkçe olarak yaz. İngilizce kullanma.';
    }
    return '\n\nIMPORTANT: Respond entirely in English. Do not use any other language.';
  }

  // ─── Prompts ───────────────────────────────────────────────────────────────

  String validateIngredientPrompt(String query, {String locale = 'en'}) {
    return '''
Analyze the food item: "$query".
Return a JSON object with:
{
  "label": "Display Name (Capitalized)",
  "value": "normalized_snake_case_value",
  "icon": "category_icon_name" (one of: vegetable, fruit, protein, dairy, grain, nut, other),
  "calories": approx_calories_per_100g (number)
}
${localeInstruction(locale)}''';
  }

  String generateRecipePrompt({
    required List<String> ingredients,
    required double targetCalories,
    required List<String> dietaryRestrictions,
    List<String> avoidIngredients = const [],
    int? maxTotalMinutes,
    String? difficulty,
    String locale = 'en',
  }) {
    final constraints = <String>[];
    if (maxTotalMinutes != null) {
      constraints.add('Total cook + prep time MUST be under $maxTotalMinutes minutes.');
    }
    if (difficulty != null) {
      constraints.add('Difficulty MUST be "$difficulty".');
    }
    if (avoidIngredients.isNotEmpty) {
      constraints.add('MUST NOT contain these ingredients: ${avoidIngredients.join(', ')}.');
    }
    final constraintBlock = constraints.isEmpty
        ? ''
        : '\nAdditional constraints:\n${constraints.map((c) => '- $c').join('\n')}';

    return '''
Create a recipe using these ingredients: ${ingredients.join(', ')}.
Target Calories: $targetCalories.
Dietary Restrictions: ${dietaryRestrictions.isEmpty ? 'none' : dietaryRestrictions.join(', ')}.$constraintBlock

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
${localeInstruction(locale)}''';
  }

  String generateWeeklyMealPlanPrompt({
    required Map<String, dynamic> userProfile,
    required List<dynamic> availableDishes,
    required double dailyCalorieTarget,
    String locale = 'en',
  }) {
    final dishesContext = availableDishes.map((d) {
      if (d is Map) {
        return "- [${d['id']}] ${d['name']} (${d['category']}): ${d['calories']}kcal (P:${d['protein']} C:${d['carbs']} F:${d['fat']})";
      }
      return "- [${d.id}] ${d.name} (${d.category}): ${d.calories}kcal (P:${d.protein} C:${d.carbs} F:${d.fat})";
    }).join('\n');

    const jsonSchema = '''
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

    final allergiesStr = userProfile['allergies'] as String? ?? 'None';
    final allergyWarning = allergiesStr != 'None'
        ? '\n⚠️  CRITICAL ALLERGY ALERT: The user is allergic to $allergiesStr. You MUST NEVER include any dish containing these allergens. This is a strict safety requirement.'
        : '';

    return '''
Act as a professional nutritionist and personal chef. Create a 7-day weekly meal plan for a user with the following profile:

Profile:
- Goal: ${userProfile['goal']}
- Daily Calorie Target: $dailyCalorieTarget kcal
- Dietary Restrictions: ${userProfile['restrictions']}
- Confirmed Allergies: $allergiesStr$allergyWarning
- Dislikes: ${userProfile['dislikes']}
- Activity Level: ${userProfile['activity_level']}
- Meal Frequency: 3 main meals + optional snack

Task:
Select dishes ONLY from the following list to build the plan. Do not invent new dishes. You must use the EXACT IDs provided in brackets [id].
Ensure nutritional balance and variety. Strictly honour all dietary restrictions and allergies listed above — never select a dish that conflicts with them.

Available Dishes Database:
$dishesContext

Return strictly valid JSON matching this structure:
$jsonSchema
${localeInstruction(locale)}''';
  }

  String generatePlanAlternatesPrompt({
    required double dailyCalorieTarget,
    required String goal,
    required String activityLevel,
    required String restrictions,
    String locale = 'en',
  }) {
    return '''
You are a professional nutritionist. A user wants to compare 2 different weekly meal plan approaches.

User profile:
- Daily Calorie Target: $dailyCalorieTarget kcal
- Goal: $goal
- Activity Level: $activityLevel
- Dietary Restrictions: $restrictions

Generate exactly 2 distinct macro distribution approaches that achieve the same calorie target.
Approaches should have clearly different macro ratios (e.g., High Protein vs Balanced Carbs, or Fat Loss vs Muscle Gain).

Return ONLY valid JSON:
{
  "alternates": [
    {
      "name": "Short approach name (2-3 words)",
      "description": "One sentence describing this approach and its benefits",
      "avg_daily_calories": $dailyCalorieTarget,
      "avg_macros": { "protein": 0, "carbs": 0, "fat": 0 }
    },
    {
      "name": "Short approach name (2-3 words)",
      "description": "One sentence describing this approach and its benefits",
      "avg_daily_calories": $dailyCalorieTarget,
      "avg_macros": { "protein": 0, "carbs": 0, "fat": 0 }
    }
  ]
}

Ensure macros × kcal conversion ≈ avg_daily_calories (protein×4 + carbs×4 + fat×9 ≈ calories).
${localeInstruction(locale)}''';
  }
}
