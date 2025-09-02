import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

class OnboardingProvider extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();
  String? goal;
  String? gender;
  DateTime? birthDate;
  double? weight;
  double? height;
  String? activityLevel;
  double? targetWeight;
  List<String> primaryGoals = [];
  List<String> dietaryPreferences = [];
  List<String> customDietaryPreferences = [];
  String? cookingLevel;
  List<String> kitchenEquipment = [];

  void setGoal(String value) {
    goal = value;
    notifyListeners();
  }

  void setGender(String value) {
    gender = value;
    notifyListeners();
  }

  void setBirthDate(DateTime value) {
    birthDate = value;
    notifyListeners();
  }

  void setWeight(double value) {
    weight = value;
    notifyListeners();
  }

  void setHeight(double value) {
    height = value;
    notifyListeners();
  }

  void setActivityLevel(String value) {
    activityLevel = value;
    notifyListeners();
  }

  void setTargetWeight(double value) {
    targetWeight = value;
    notifyListeners();
  }

  void setPrimaryGoal(String value) {
    if (primaryGoals.contains(value)) {
      primaryGoals.remove(value);
    } else {
      if (primaryGoals.length < 3) {
        primaryGoals.add(value);
      }
    }
    notifyListeners();
  }

  void togglePrimaryGoal(String value) {
    if (primaryGoals.contains(value)) {
      primaryGoals.remove(value);
    } else {
      if (primaryGoals.length < 3) {
        primaryGoals.add(value);
      }
    }
    notifyListeners();
  }

  void clearPrimaryGoals() {
    primaryGoals.clear();
    notifyListeners();
  }

  void setDietaryPreferences(List<String> preferences) {
    dietaryPreferences = preferences;
    notifyListeners();
  }

  void setCustomDietaryPreferences(List<String> customPreferences) {
    customDietaryPreferences = customPreferences;
    notifyListeners();
  }

  void setCookingLevel(String value) {
    print('setCookingLevel called with: $value');
    cookingLevel = value;
    print('cookingLevel set to: $cookingLevel');
    notifyListeners();
  }

  void setKitchenEquipment(List<String> equipment) {
    print('setKitchenEquipment called with: $equipment');
    kitchenEquipment = equipment;
    print('kitchenEquipment set to: $kitchenEquipment');
    notifyListeners();
  }

  void toggleKitchenEquipment(String equipment) {
    print('toggleKitchenEquipment called with: $equipment');
    print('Current kitchenEquipment: $kitchenEquipment');
    if (kitchenEquipment.contains(equipment)) {
      kitchenEquipment.remove(equipment);
      print('Removed $equipment, new list: $kitchenEquipment');
    } else {
      kitchenEquipment.add(equipment);
      print('Added $equipment, new list: $kitchenEquipment');
    }
    notifyListeners();
  }

  /// Onboarding tamamlanma durumunu kontrol et
  bool get isOnboardingComplete {
    return goal != null &&
        gender != null &&
        birthDate != null &&
        weight != null &&
        height != null &&
        activityLevel != null &&
        targetWeight != null &&
        primaryGoals.isNotEmpty &&
        cookingLevel != null &&
        kitchenEquipment.isNotEmpty;
  }

  /// Onboarding tamamlanma analytics'ini gönder
  Future<void> logOnboardingCompletion() async {
    if (isOnboardingComplete) {
      await _analyticsService.logUserFlow(
        flowName: 'onboarding',
        step: 'completion',
        action: 'complete',
        parameters: {
          'goal': goal ?? 'unknown',
          'gender': gender ?? 'unknown',
          'activity_level': activityLevel ?? 'unknown',
          'cooking_level': cookingLevel ?? 'unknown',
          'primary_goals_count': primaryGoals.length,
          'dietary_preferences_count': dietaryPreferences.length,
          'kitchen_equipment_count': kitchenEquipment.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Onboarding tamamlanma event'ini gönder
      await _analyticsService.logUserInteraction(
        interactionType: 'onboarding_completion',
        target: 'onboarding_finished',
        parameters: {
          'total_steps_completed': 5,
          'completion_time': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// Onboarding verilerini analytics'e gönder
  Future<void> logOnboardingData() async {
    await _analyticsService.logUserFlow(
      flowName: 'onboarding_data',
      step: 'data_collection',
      action: 'submit',
      parameters: {
        'goal': goal ?? 'unknown',
        'gender': gender ?? 'unknown',
        'birth_date': birthDate?.toIso8601String() ?? 'unknown',
        'weight': weight ?? 0.0,
        'height': height ?? 0.0,
        'activity_level': activityLevel ?? 'unknown',
        'target_weight': targetWeight ?? 0.0,
        'primary_goals': primaryGoals,
        'dietary_preferences': dietaryPreferences,
        'custom_dietary_preferences': customDietaryPreferences,
        'cooking_level': cookingLevel ?? 'unknown',
        'kitchen_equipment': kitchenEquipment,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
