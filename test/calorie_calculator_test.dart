import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/calorie_calculator.dart';

void main() {
  group('CalorieCalculator', () {
    group('calculateBMR', () {
      test('male formula: 10w + 6.25h - 5a + 5', () {
        final bmr = CalorieCalculator.calculateBMR(
          weight: 80,
          height: 180,
          age: 30,
          gender: 'Male',
        );
        // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        expect(bmr, closeTo(1780, 0.01));
      });

      test('female formula: 10w + 6.25h - 5a - 161', () {
        final bmr = CalorieCalculator.calculateBMR(
          weight: 60,
          height: 165,
          age: 25,
          gender: 'Female',
        );
        // 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
        expect(bmr, closeTo(1345.25, 0.01));
      });

      test('unknown gender falls back to female formula', () {
        final bmr = CalorieCalculator.calculateBMR(
          weight: 60,
          height: 165,
          age: 25,
          gender: 'Other',
        );
        final femaleBmr = CalorieCalculator.calculateBMR(
          weight: 60,
          height: 165,
          age: 25,
          gender: 'Female',
        );
        expect(bmr, equals(femaleBmr));
      });
    });

    group('calculateTDEE', () {
      const bmr = 1800.0;

      test('sedentary multiplier 1.2', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'sedentary'),
            closeTo(bmr * 1.2, 0.01));
      });

      test('Sedentary (capital) multiplier 1.2', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'Sedentary'),
            closeTo(bmr * 1.2, 0.01));
      });

      test('light multiplier 1.375', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'light'),
            closeTo(bmr * 1.375, 0.01));
      });

      test('moderate multiplier 1.55', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'moderate'),
            closeTo(bmr * 1.55, 0.01));
      });

      test('active multiplier 1.725', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'active'),
            closeTo(bmr * 1.725, 0.01));
      });

      test('Extra active multiplier 1.9', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'Extra active'),
            closeTo(bmr * 1.9, 0.01));
      });

      test('unknown activity level defaults to sedentary (1.2)', () {
        expect(CalorieCalculator.calculateTDEE(bmr: bmr, activityLevel: 'unknown'),
            closeTo(bmr * 1.2, 0.01));
      });
    });

    group('adjustTDEEForGoal', () {
      const tdee = 2000.0;

      test('lose_weight subtracts 500', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'lose_weight'),
            equals(1500));
      });

      test('Lose Weight subtracts 500', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'Lose Weight'),
            equals(1500));
      });

      test('gain_weight adds 500', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'gain_weight'),
            equals(2500));
      });

      test('increase_muscle adds 500', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'increase_muscle'),
            equals(2500));
      });

      test('maintain_weight makes no change', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'maintain_weight'),
            equals(2000));
      });

      test('unknown goal defaults to no change', () {
        expect(CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: 'unknown'),
            equals(2000));
      });
    });

    group('calculateMacros', () {
      test('returns correct macro gram amounts for 2000 kcal', () {
        final macros = CalorieCalculator.calculateMacros(2000);
        // Carbs: 2000 * 0.40 / 4 = 200g
        expect(macros['carbs'], closeTo(200, 0.01));
        // Protein: 2000 * 0.30 / 4 = 150g
        expect(macros['protein'], closeTo(150, 0.01));
        // Fat: 2000 * 0.30 / 9 ≈ 66.67g
        expect(macros['fat'], closeTo(2000 * 0.30 / 9, 0.01));
      });

      test('returns 0 for 0 calories', () {
        final macros = CalorieCalculator.calculateMacros(0);
        expect(macros['carbs'], equals(0));
        expect(macros['protein'], equals(0));
        expect(macros['fat'], equals(0));
      });

      test('contains all three macro keys', () {
        final macros = CalorieCalculator.calculateMacros(1500);
        expect(macros.containsKey('carbs'), isTrue);
        expect(macros.containsKey('protein'), isTrue);
        expect(macros.containsKey('fat'), isTrue);
      });
    });

    group('integration: full calculation pipeline', () {
      test('male, moderate activity, lose weight', () {
        final bmr = CalorieCalculator.calculateBMR(
          weight: 90,
          height: 175,
          age: 35,
          gender: 'Male',
        );
        final tdee = CalorieCalculator.calculateTDEE(
          bmr: bmr,
          activityLevel: 'moderate',
        );
        final target = CalorieCalculator.adjustTDEEForGoal(
          tdee: tdee,
          primaryGoal: 'lose_weight',
        );
        // BMR = 10*90 + 6.25*175 - 5*35 + 5 = 900 + 1093.75 - 175 + 5 = 1823.75
        // TDEE = 1823.75 * 1.55 = 2826.81
        // Target = 2826.81 - 500 = 2326.81
        expect(bmr, closeTo(1823.75, 0.01));
        expect(tdee, closeTo(1823.75 * 1.55, 0.01));
        expect(target, closeTo(1823.75 * 1.55 - 500, 0.01));

        // Macros should be non-zero
        final macros = CalorieCalculator.calculateMacros(target);
        expect(macros['carbs']!, greaterThan(0));
        expect(macros['protein']!, greaterThan(0));
        expect(macros['fat']!, greaterThan(0));
      });
    });
  });
}
