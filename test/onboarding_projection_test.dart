import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/services/onboarding_projection_service.dart';

/// Guards the onboarding projection invariants — especially the medically-safe
/// rate clamping and water bounds, which are legal-sensitive (see
/// docs/roadmap/ONBOARDING_V2.md §2: estimates, not medical advice).
void main() {
  final now = DateTime(2026, 1, 1);

  group('OnboardingProjectionService.compute', () {
    test('BMI is computed and banded correctly', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Male',
        birthDate: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 90,
        targetWeightKg: 70,
        mainGoal: 'lose_weight',
        activityLevel: 'moderate',
        now: now,
      );
      // 90 / 1.8^2 = 27.78 → overweight
      expect(p.bmi, closeTo(27.78, 0.05));
      expect(p.bmiCategory, 'overweight');
    });

    test('weight-loss pace is clamped to a safe 0.4–0.75 kg/week', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Male',
        birthDate: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 90,
        targetWeightKg: 70,
        mainGoal: 'lose_weight',
        activityLevel: 'moderate',
        now: now,
      );
      expect(p.weeklyRateKg, isNotNull);
      expect(p.weeklyRateKg! >= 0.4 && p.weeklyRateKg! <= 0.75, isTrue);
      expect(p.weightDeltaKg, -20);
      expect(p.estimatedWeeks, isNotNull);
      expect(p.estimatedWeeks! > 0, isTrue);
      expect(p.estimatedDate, isNotNull);
    });

    test('lean-gain pace is clamped to a safe 0.2–0.5 kg/week', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Female',
        birthDate: DateTime(2000, 6, 1),
        heightCm: 165,
        weightKg: 55,
        targetWeightKg: 62,
        mainGoal: 'build_muscle',
        activityLevel: 'active',
        now: now,
      );
      expect(p.weeklyRateKg, isNotNull);
      expect(p.weeklyRateKg! >= 0.2 && p.weeklyRateKg! <= 0.5, isTrue);
      expect(p.weightDeltaKg, 7);
    });

    test('maintenance goal yields no ETA (habit focus)', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Female',
        birthDate: DateTime(2000, 6, 1),
        heightCm: 165,
        weightKg: 60,
        targetWeightKg: 60,
        mainGoal: 'healthy_eating',
        activityLevel: 'light',
        now: now,
      );
      expect(p.estimatedWeeks, isNull);
      expect(p.estimatedDate, isNull);
    });

    test('negligible delta (<1kg) yields no ETA', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Male',
        birthDate: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 80,
        targetWeightKg: 80,
        mainGoal: 'lose_weight',
        activityLevel: 'moderate',
        now: now,
      );
      expect(p.estimatedWeeks, isNull);
    });

    test('water target stays within 1500–4000 ml and rounds to 100', () {
      final light = OnboardingProjectionService.recommendedWaterMl(
          weightKg: 30, activityLevel: 'sedentary');
      final heavy = OnboardingProjectionService.recommendedWaterMl(
          weightKg: 200, activityLevel: 'active');
      expect(light >= 1500, isTrue);
      expect(heavy <= 4000, isTrue);
      expect(light % 100, 0);
      expect(heavy % 100, 0);
    });

    test('calories + macros computed when inputs present', () {
      final p = OnboardingProjectionService.compute(
        gender: 'Male',
        birthDate: DateTime(1996, 1, 1),
        heightCm: 180,
        weightKg: 80,
        targetWeightKg: 75,
        mainGoal: 'lose_weight',
        activityLevel: 'moderate',
        now: now,
      );
      expect(p.dailyCalories, isNotNull);
      expect(p.dailyCalories! > 0, isTrue);
      expect(p.macros['protein'], isNotNull);
      expect(p.macros['carbs'], isNotNull);
      expect(p.macros['fat'], isNotNull);
    });

    test('degrades gracefully with missing inputs (no throw, null fields)', () {
      final p = OnboardingProjectionService.compute(
        gender: null,
        birthDate: null,
        heightCm: null,
        weightKg: null,
        targetWeightKg: null,
        mainGoal: null,
        activityLevel: null,
        now: now,
      );
      expect(p.bmi, isNull);
      expect(p.dailyCalories, isNull);
      expect(p.estimatedWeeks, isNull);
      expect(p.dailyWaterMl, 2000);
    });
  });
}
