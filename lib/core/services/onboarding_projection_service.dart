import 'dart:math' as math;

import '../utils/age_gate.dart';
import '../utils/calorie_calculator.dart';

/// Result of an onboarding projection — everything the target-weight page (5)
/// and the final report (14) need to render personalized, *safe* estimates.
///
/// All weight/time estimates are deliberately clamped to a medically-defensible
/// rate. Outcome predictions in a health app carry medical-claim/advertising
/// risk, so the UI MUST present these as estimates with a "not medical advice"
/// disclaimer (see `docs/roadmap/ONBOARDING_V2.md` §2).
class OnboardingProjection {
  /// Body Mass Index (kg/m²), or null if height/weight missing.
  final double? bmi;

  /// Localization-key suffix for the BMI band:
  /// `underweight` | `normal` | `overweight` | `obese`.
  final String? bmiCategory;

  /// Estimated daily calorie target (kcal), goal-adjusted, or null if inputs missing.
  final int? dailyCalories;

  /// Macro split in grams: keys `carbs` / `protein` / `fat`.
  final Map<String, int> macros;

  /// Signed delta to reach target: `targetWeight - currentWeight` (kg).
  /// Negative = needs to lose, positive = needs to gain.
  final double? weightDeltaKg;

  /// Medically-safe weekly rate of change actually used (kg/week, always > 0
  /// when there is a delta to close). Capped per goal.
  final double? weeklyRateKg;

  /// Estimated whole weeks to reach target at [weeklyRateKg], clamped.
  /// Null when the goal is maintenance or the delta is negligible (< 1 kg).
  final int? estimatedWeeks;

  /// Projected target date, or null when [estimatedWeeks] is null.
  final DateTime? estimatedDate;

  /// Recommended daily water intake (ml), rounded to nearest 100.
  final int dailyWaterMl;

  const OnboardingProjection({
    this.bmi,
    this.bmiCategory,
    this.dailyCalories,
    this.macros = const {},
    this.weightDeltaKg,
    this.weeklyRateKg,
    this.estimatedWeeks,
    this.estimatedDate,
    this.dailyWaterMl = 2000,
  });
}

/// Pure, dependency-free projection math for onboarding. No I/O, no Firestore —
/// fully unit-testable. Reuses [CalorieCalculator] (Mifflin-St Jeor) for energy.
class OnboardingProjectionService {
  OnboardingProjectionService._();

  /// Maps an onboarding `mainGoal` id to the goal key [CalorieCalculator] expects.
  static String _calorieGoalKey(String? mainGoal) {
    switch (mainGoal) {
      case 'lose_weight':
        return 'lose_weight';
      case 'gain_weight':
        return 'gain_weight';
      case 'build_muscle':
        return 'increase_muscle';
      case 'healthy_eating':
      default:
        return 'maintain_weight';
    }
  }

  /// Normalizes assorted activity-level ids/labels to [CalorieCalculator] keys.
  static String _activityKey(String? activity) {
    final a = (activity ?? '').toLowerCase();
    if (a.contains('sedentary') || a.contains('low')) return 'sedentary';
    if (a.contains('light')) return 'light';
    if (a.contains('moderate')) return 'moderate';
    if (a.contains('extra') || a.contains('athlete')) return 'Extra active';
    if (a.contains('very') || a.contains('active') || a.contains('high')) {
      return 'active';
    }
    return 'moderate';
  }

  /// BMI band thresholds (WHO).
  static String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }

  /// Safe weekly rate (kg/week) for closing [deltaKg] given [currentWeightKg].
  /// Loss is capped tighter than gain; both stay within clinical guidance
  /// (~0.5–0.75 kg/wk loss, ~0.25–0.5 kg/wk gain).
  static double _safeWeeklyRate({
    required double deltaKg,
    required double currentWeightKg,
  }) {
    if (deltaKg < 0) {
      // Losing: ~0.75% of body weight, clamped 0.4–0.75 kg/wk.
      return (currentWeightKg * 0.0075).clamp(0.4, 0.75);
    }
    // Gaining (lean gain): slower, clamped 0.2–0.5 kg/wk.
    return (currentWeightKg * 0.0035).clamp(0.2, 0.5);
  }

  /// Recommended daily water (ml): ~33 ml/kg baseline with a small activity
  /// bonus, clamped to a sane 1500–4000 ml and rounded to the nearest 100.
  static int recommendedWaterMl({
    required int weightKg,
    String? activityLevel,
  }) {
    final base = weightKg * 33.0;
    final key = _activityKey(activityLevel);
    final bonus = switch (key) {
      'active' => 500.0,
      'Extra active' => 750.0,
      'moderate' => 300.0,
      'light' => 150.0,
      _ => 0.0,
    };
    final total = (base + bonus).clamp(1500.0, 4000.0);
    return (total / 100).round() * 100;
  }

  /// Computes the full projection from the (possibly partial) onboarding inputs.
  /// Missing inputs degrade gracefully to null fields rather than throwing.
  static OnboardingProjection compute({
    required String? gender,
    required DateTime? birthDate,
    required int? heightCm,
    required int? weightKg,
    required int? targetWeightKg,
    required String? mainGoal,
    required String? activityLevel,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    double? bmi;
    String? bmiCategory;
    if (heightCm != null && heightCm > 0 && weightKg != null && weightKg > 0) {
      final h = heightCm / 100.0;
      bmi = weightKg / (h * h);
      bmiCategory = _bmiCategory(bmi);
    }

    int? dailyCalories;
    Map<String, int> macros = const {};
    if (gender != null &&
        birthDate != null &&
        heightCm != null &&
        weightKg != null) {
      final age = AgeGate.ageInYears(birthDate, n);
      // CalorieCalculator expects "Male"/"Female"; normalize onboarding ids.
      final g = gender.toLowerCase().startsWith('m') ? 'Male' : 'Female';
      final bmr = CalorieCalculator.calculateBMR(
        weight: weightKg.toDouble(),
        height: heightCm.toDouble(),
        age: age,
        gender: g,
      );
      final tdee = CalorieCalculator.calculateTDEE(
        bmr: bmr,
        activityLevel: _activityKey(activityLevel),
      );
      final goalCals = CalorieCalculator.adjustTDEEForGoal(
        tdee: tdee,
        primaryGoal: _calorieGoalKey(mainGoal),
      );
      dailyCalories = goalCals.round();
      final m = CalorieCalculator.calculateMacros(goalCals);
      macros = {
        'carbs': (m['carbs'] ?? 0).round(),
        'protein': (m['protein'] ?? 0).round(),
        'fat': (m['fat'] ?? 0).round(),
      };
    }

    double? deltaKg;
    double? weeklyRate;
    int? weeks;
    DateTime? targetDate;
    if (weightKg != null && weightKg > 0 && targetWeightKg != null) {
      deltaKg = (targetWeightKg - weightKg).toDouble();
      final isMaintain = _calorieGoalKey(mainGoal) == 'maintain_weight';
      if (!isMaintain && deltaKg.abs() >= 1.0) {
        weeklyRate = _safeWeeklyRate(
          deltaKg: deltaKg,
          currentWeightKg: weightKg.toDouble(),
        );
        weeks = math.max(1, (deltaKg.abs() / weeklyRate).ceil());
        targetDate = n.add(Duration(days: weeks * 7));
      }
    }

    return OnboardingProjection(
      bmi: bmi,
      bmiCategory: bmiCategory,
      dailyCalories: dailyCalories,
      macros: macros,
      weightDeltaKg: deltaKg,
      weeklyRateKg: weeklyRate,
      estimatedWeeks: weeks,
      estimatedDate: targetDate,
      dailyWaterMl: (weightKg != null && weightKg > 0)
          ? recommendedWaterMl(weightKg: weightKg, activityLevel: activityLevel)
          : 2000,
    );
  }
}
