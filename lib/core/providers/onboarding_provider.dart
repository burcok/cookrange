import 'package:flutter/material.dart';

class OnboardingProvider extends ChangeNotifier {
  String? goal;
  String? gender;
  DateTime? birthDate;
  double? weight;
  double? height;
  String? activityLevel;
  double? targetWeight;

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
}
