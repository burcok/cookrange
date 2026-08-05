import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/services/ai/prompt_service.dart';

/// Faz 3 §3.6 — the 180-dish AI-prompt ceiling `docs/AI_SYSTEM.md` documents
/// but which nothing enforced in code before this task. Tests go through the
/// public [PromptService.generateWeeklyMealPlanPrompt] (the cap helper
/// itself is private) and inspect the rendered prompt text, since that's
/// the actual contract: whatever ends up in the string sent to the model.
void main() {
  Map<String, dynamic> dish(String id, {String mealType = 'lunch'}) => {
        'id': id,
        'name': id,
        'category': 'test',
        'meal_type': mealType,
        'calories': 400,
        'protein': 20,
        'carbs': 40,
        'fat': 10,
      };

  final profile = <String, dynamic>{
    'goal': 'lose_weight',
    'restrictions': 'None',
    'allergies': 'None',
    'dislikes': 'None',
    'activity_level': 'moderate',
  };

  int dishLineCount(String prompt) => '- ['.allMatches(prompt).length;

  group('PromptService.generateWeeklyMealPlanPrompt — 180-dish ceiling', () {
    test('pool under the ceiling passes through unchanged', () {
      final dishes = List.generate(50, (i) => dish('d$i'));
      final prompt = PromptService().generateWeeklyMealPlanPrompt(
        userProfile: profile,
        availableDishes: dishes,
        dailyCalorieTarget: 2000,
      );
      expect(dishLineCount(prompt), 50);
      for (var i = 0; i < 50; i++) {
        expect(prompt.contains('[d$i]'), isTrue);
      }
    });

    test('pool exactly at the ceiling passes through unchanged', () {
      final dishes = List.generate(180, (i) => dish('d$i'));
      final prompt = PromptService().generateWeeklyMealPlanPrompt(
        userProfile: profile,
        availableDishes: dishes,
        dailyCalorieTarget: 2000,
      );
      expect(dishLineCount(prompt), 180);
    });

    test('pool over the ceiling is capped to exactly 180 dishes', () {
      final dishes = List.generate(300, (i) => dish('d$i'));
      final prompt = PromptService().generateWeeklyMealPlanPrompt(
        userProfile: profile,
        availableDishes: dishes,
        dailyCalorieTarget: 2000,
      );
      expect(dishLineCount(prompt), 180);
    });

    test(
        'a small minority meal type is never zeroed out by the cap — '
        'guards against exactly the failure this task\'s snack-pool fix '
        'itself would be exposed to at catalog scale: a positional '
        '.take(180) could silently drop every snack if dishes with other '
        'meal types happen to sort first', () {
      // Worst case: the 5 snacks are the LAST 5 entries in the list, and
      // everything else (295 lunches) sorts before them.
      final dishes = [
        ...List.generate(295, (i) => dish('lunch$i', mealType: 'lunch')),
        ...List.generate(5, (i) => dish('snack$i', mealType: 'snack')),
      ];
      final prompt = PromptService().generateWeeklyMealPlanPrompt(
        userProfile: profile,
        availableDishes: dishes,
        dailyCalorieTarget: 2000,
      );
      expect(dishLineCount(prompt), 180);
      for (var i = 0; i < 5; i++) {
        expect(prompt.contains('[snack$i]'), isTrue,
            reason: 'snack$i was dropped by the cap');
      }
    });

    test(
        'accepts Map-shaped dishes (as used by MealPlanTemplateService) '
        'without throwing', () {
      final dishes = List.generate(10, (i) => dish('d$i'));
      expect(
        () => PromptService().generateWeeklyMealPlanPrompt(
          userProfile: profile,
          availableDishes: dishes,
          dailyCalorieTarget: 2000,
        ),
        returnsNormally,
      );
    });
  });
}
