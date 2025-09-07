import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';

class OnboardingProvider with ChangeNotifier {
  // Personal Info
  Map<String, dynamic> _personalInfo = {
    'gender': null,
    'birth_date': null,
    'height': null,
    'weight': null,
  };
  int? _targetWeight;
  Map<String, dynamic>? _lifestyleProfile;
  Map<String, dynamic>?
      _mealSchedule; // Stores meal times for different schedules

  // Preferences
  List<Map<String, dynamic>> _primaryGoals = [];
  Map<String, dynamic>? _activityLevel;
  List<Map<String, dynamic>> _dislikedFoods = [];
  Map<String, dynamic>? _cookingLevel;
  List<Map<String, dynamic>> _kitchenEquipment = [];

  // To track changes
  Map<String, dynamic>? _initialData;

  // Getters for Personal Info
  String? get gender => _personalInfo['gender'];
  DateTime? get birthDate {
    final date = _personalInfo['birth_date'];
    if (date is DateTime) {
      return date;
    } else if (date is String) {
      return DateTime.tryParse(date);
    }
    return null;
  }

  int? get height => _personalInfo['height'];
  int? get weight => _personalInfo['weight'];

  int? get targetWeight => _targetWeight;
  Map<String, dynamic>? get lifestyleProfile => _lifestyleProfile;
  Map<String, dynamic>? get mealSchedule => _mealSchedule;

  // Getters for Preferences
  List<Map<String, dynamic>> get primaryGoals => _primaryGoals;
  Map<String, dynamic>? get activityLevel => _activityLevel;
  List<Map<String, dynamic>> get dislikedFoods => _dislikedFoods;
  Map<String, dynamic>? get cookingLevel => _cookingLevel;
  List<Map<String, dynamic>> get kitchenEquipment => _kitchenEquipment;

  bool get isDirty {
    final currentData = _toMap();
    if (_initialData == null) {
      // If there's no initial data, any new data is a change.
      return currentData.values.any((value) {
        if (value is List) return value.isNotEmpty;
        if (value is Map) {
          return value.values
              .any((v) => v != null && (v is! List || v.isNotEmpty));
        }
        return value != null;
      });
    }
    // Compare field by field
    return !mapEquals(_initialData!['personal_info'], _personalInfo) ||
        !mapEquals(
            _initialData!['lifestyle_profile'] as Map?, _lifestyleProfile) ||
        !mapEquals(_initialData!['meal_schedule'] as Map?, _mealSchedule) ||
        !_mapListEquals(
            _initialData!['primary_goals'] as List<Map<String, dynamic>>?,
            _primaryGoals) ||
        _initialData!['activity_level']?['value'] != _activityLevel?['value'] ||
        !_mapListEquals(
            _initialData!['disliked_foods'] as List<Map<String, dynamic>>?,
            _dislikedFoods) ||
        _initialData!['cooking_level']?['value'] != _cookingLevel?['value'] ||
        !_mapListEquals(
            _initialData!['kitchen_equipments'] as List<Map<String, dynamic>>?,
            _kitchenEquipment);
  }

  bool _mapListEquals(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;

    final aValues = a.map((e) => e['value']).toSet();
    final bValues = b.map((e) => e['value']).toSet();

    return setEquals(aValues, bValues);
  }

  Map<String, dynamic> _toMap() {
    return {
      'personal_info': {
        'gender': _personalInfo['gender'],
        'birth_date': _personalInfo['birth_date'] is DateTime
            ? (_personalInfo['birth_date'] as DateTime).toIso8601String()
            : _personalInfo['birth_date'],
        'height': _personalInfo['height'],
        'weight': _personalInfo['weight'],
      },
      'lifestyle_profile': _lifestyleProfile,
      'meal_schedule': _mealSchedule,
      'primary_goals': List<Map<String, dynamic>>.from(_primaryGoals),
      'activity_level': _activityLevel,
      'disliked_foods': List<Map<String, dynamic>>.from(_dislikedFoods),
      'cooking_level': _cookingLevel,
      'kitchen_equipments': List<Map<String, dynamic>>.from(_kitchenEquipment),
    };
  }

  void _setInitialData() {
    _initialData = _toMap();
  }

  DateTime? _parseBirthDate(dynamic birthDate) {
    if (birthDate is String) {
      return DateTime.tryParse(birthDate);
    } else if (birthDate != null) {
      // A non-string birthDate is unexpected.
      // Log in debug mode to help identify the issue source.
      if (kDebugMode) {
        print(
            'Warning: birth_date was expected to be a String but received type ${birthDate.runtimeType} with value $birthDate. Treating as null.');
      }
    }
    return null;
  }

  String? _getString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) {
      return value;
    } else if (value is Map) {
      // Handle cases where data might be in a { 'label': 'x', 'value': 'y' } format
      return value['value'] as String?;
    }
    return null;
  }

  int? _getInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt();
    } else if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  void initializeFromFirestore(Map<String, dynamic> data) {
    // Check if the data is in the new nested format or the old flat format
    final onboardingData =
        data.containsKey('onboarding_data') && data['onboarding_data'] is Map
            ? data['onboarding_data'] as Map<String, dynamic>
            : data;

    if (onboardingData.containsKey('personal_info') &&
        onboardingData['personal_info'] is Map) {
      final personalInfoData =
          onboardingData['personal_info'] as Map<String, dynamic>;
      _personalInfo['gender'] = _getString(personalInfoData, 'gender');
      _personalInfo['birth_date'] =
          _parseBirthDate(personalInfoData['birth_date']);
      _personalInfo['height'] = _getInt(personalInfoData, 'height');
      _personalInfo['weight'] = _getInt(personalInfoData, 'weight');
    } else {
      // Fallback for old flat structure
      _personalInfo['gender'] = _getString(onboardingData, 'gender');
      _personalInfo['birth_date'] =
          _parseBirthDate(onboardingData['birth_date']);
      _personalInfo['height'] = _getInt(onboardingData, 'height');
      _personalInfo['weight'] = _getInt(onboardingData, 'weight');
    }

    _lifestyleProfile = _convertToMap(onboardingData['lifestyle_profile']);
    _mealSchedule = _convertToMap(onboardingData['meal_schedule']);

    // Handle old and new data formats
    _primaryGoals = _convertToListMap(onboardingData['primary_goals']);
    _activityLevel = _convertToMap(onboardingData['activity_level']);
    _dislikedFoods = _convertToListMap(onboardingData['disliked_foods']);
    _cookingLevel = _convertToMap(onboardingData['cooking_level']);
    _kitchenEquipment = _convertToListMap(onboardingData['kitchen_equipments']);

    _setInitialData(); // Set initial data after loading
    notifyListeners();
  }

  List<Map<String, dynamic>> _convertToListMap(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else if (item is String) {
          return {'label': item, 'value': item};
        }
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  Map<String, dynamic>? _convertToMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is String) {
      return {'label': data, 'value': data};
    }
    return null;
  }

  Future<void> updateOnboardingDataInFirestore() async {
    final authService = AuthService();
    if (authService.currentUser == null) return;

    // Create a clean version of meal_schedule before saving to remove old data.
    Map<String, dynamic>? cleanMealSchedule;
    if (_mealSchedule != null) {
      cleanMealSchedule = Map<String, dynamic>.from(_mealSchedule!);
      final scheduleType = cleanMealSchedule['schedule_type'];
      if (scheduleType == 'fixed' || scheduleType == 'irregular') {
        cleanMealSchedule.remove('rotation_weeks');
        cleanMealSchedule.remove('shifts');
      }
    }

    final onboardingData = {
      'personal_info': {
        'gender': _personalInfo['gender'],
        'birth_date': _personalInfo['birth_date']?.toIso8601String(),
        'height': _personalInfo['height'],
        'weight': _personalInfo['weight'],
      },
      'lifestyle_profile': _lifestyleProfile,
      'meal_schedule': cleanMealSchedule,
      'primary_goals': _primaryGoals,
      'activity_level': _activityLevel,
      'disliked_foods': _dislikedFoods,
      'cooking_level': _cookingLevel,
      'kitchen_equipments': _kitchenEquipment,
    };

    onboardingData.removeWhere((key, value) {
      if (value == null) return true;
      if (key == 'personal_info' && value is Map) {
        value.removeWhere((k, v) => v == null);
      }
      return false;
    });

    if (onboardingData.isNotEmpty) {
      await authService.updateUserData({'onboarding_data': onboardingData});
      _setInitialData(); // Reset dirty tracking after saving
    }
  }

  Future<bool> saveFinalOnboardingData() async {
    final authService = AuthService();
    if (authService.currentUser == null) return false;

    if (!isOnboardingComplete) {
      // Maybe log an error or throw an exception
      return false;
    }

    // Create a clean version of meal_schedule before saving to remove old data.
    Map<String, dynamic>? cleanMealSchedule;
    if (_mealSchedule != null) {
      cleanMealSchedule = Map<String, dynamic>.from(_mealSchedule!);
      final scheduleType = cleanMealSchedule['schedule_type'];
      if (scheduleType == 'fixed' || scheduleType == 'irregular') {
        cleanMealSchedule.remove('rotation_weeks');
        cleanMealSchedule.remove('shifts');
      }
    }

    final onboardingData = {
      'personal_info': {
        'gender': _personalInfo['gender'],
        'birth_date': _personalInfo['birth_date']?.toIso8601String(),
        'height': _personalInfo['height'],
        'weight': _personalInfo['weight'],
      },
      'lifestyle_profile': _lifestyleProfile,
      'meal_schedule': cleanMealSchedule,
      'primary_goals': _primaryGoals,
      'activity_level': _activityLevel,
      'disliked_foods': _dislikedFoods,
      'cooking_level': _cookingLevel,
      'kitchen_equipments': _kitchenEquipment,
    };

    onboardingData.removeWhere((key, value) {
      if (value == null) return true;
      if (key == 'personal_info' && value is Map) {
        value.removeWhere((k, v) => v == null);
      }
      return false;
    });

    if (onboardingData.isNotEmpty) {
      try {
        await authService.updateUserData({
          'onboarding_data': onboardingData,
          'onboarding_completed': true,
        });
        _setInitialData(); // Reset dirty tracking after saving
        return true;
      } catch (e) {
        // Log the error but don't fail the onboarding completion
        if (kDebugMode) {
          print('Error updating user data during onboarding completion: $e');
        }
        // Still return true to allow onboarding to complete
        // The user data can be updated later
        return true;
      }
    }
    return false;
  }

  void reset() {
    _personalInfo = {
      'gender': null,
      'birth_date': null,
      'height': null,
      'weight': null,
    };
    _targetWeight = null;
    _lifestyleProfile = null;
    _mealSchedule = null;
    _primaryGoals = [];
    _activityLevel = null;
    _dislikedFoods = [];
    _cookingLevel = null;
    _kitchenEquipment = [];
    _initialData = null; // Reset initial data
    notifyListeners();
  }

  // Setters for Personal Info
  void setTargetWeight(int? weight) {
    if (_targetWeight != weight) {
      _targetWeight = weight;
      notifyListeners();
    }
  }

  void setGender(String? gender) {
    if (_personalInfo['gender'] != gender) {
      _personalInfo['gender'] = gender;
      notifyListeners();
    }
  }

  void setBirthDate(DateTime? date) {
    if (_personalInfo['birth_date'] != date) {
      _personalInfo['birth_date'] = date;
      notifyListeners();
    }
  }

  void setHeight(int? height) {
    if (_personalInfo['height'] != height) {
      _personalInfo['height'] = height;
      notifyListeners();
    }
  }

  void setWeight(int? weight) {
    if (_personalInfo['weight'] != weight) {
      _personalInfo['weight'] = weight;
      notifyListeners();
    }
  }

  void setLifestyleProfile(Map<String, dynamic> profile) {
    _lifestyleProfile = profile;
    notifyListeners();
  }

  void setScheduleType(String type, {List<String>? mealTimes}) {
    // Per user request, always reset the schedule when a new type is set
    // to ensure a clean state and that new data is saved correctly.
    Map<String, dynamic> newSchedule;

    if (type == 'fixed') {
      newSchedule = {
        'schedule_type': 'fixed',
        'breakfast':
            mealTimes != null && mealTimes.isNotEmpty ? mealTimes[0] : '07:00',
        'lunch':
            mealTimes != null && mealTimes.length > 1 ? mealTimes[1] : '12:00',
        'dinner':
            mealTimes != null && mealTimes.length > 2 ? mealTimes[2] : '18:00',
      };
    } else if (type == 'irregular') {
      newSchedule = {
        'schedule_type': 'irregular',
        'breakfast': '08:00',
        'lunch': '13:00',
        'dinner': '19:00',
      };
    } else if (type == 'rotating') {
      newSchedule = {
        'schedule_type': 'rotating',
        'rotation_weeks': 2,
        'shifts': [
          {
            'week': 1,
            'breakfast': '07:00',
            'lunch': '12:00',
            'dinner': '18:00'
          },
          {
            'week': 2,
            'breakfast': '15:00',
            'lunch': '20:00',
            'dinner': '01:00'
          },
        ]
      };
    } else {
      // Should not happen, but as a fallback, clear the schedule.
      newSchedule = {};
    }

    // Check if the new schedule is different from the old one before notifying.
    if (!mapEquals(_mealSchedule, newSchedule)) {
      _mealSchedule = newSchedule;
      notifyListeners();
    }
  }

  void updateMealTime(String meal, String time, {int? week}) {
    if (_mealSchedule?['schedule_type'] == 'irregular' ||
        _mealSchedule?['schedule_type'] == 'fixed') {
      if (_mealSchedule != null) {
        // Create a new map for the meal schedule to ensure immutability
        _mealSchedule = Map<String, dynamic>.from(_mealSchedule!);
        _mealSchedule![meal] = time;
        notifyListeners();
      }
    } else if (_mealSchedule?['schedule_type'] == 'rotating' && week != null) {
      if (_mealSchedule != null && _mealSchedule!['shifts'] is List) {
        // Create a new list of shifts for immutability
        final newShifts = (_mealSchedule!['shifts'] as List).map((shift) {
          if (shift['week'] == week) {
            // Create a new map for the specific shift that's changing
            final newShift = Map<String, dynamic>.from(shift);
            newShift[meal] = time;
            return newShift;
          }
          return shift;
        }).toList();

        // Create a new map for the meal schedule
        _mealSchedule = {
          ..._mealSchedule!,
          'shifts': newShifts,
        };
        notifyListeners();
      }
    }
  }

  void updateRotationWeeks(int weeks) {
    if (_mealSchedule?['schedule_type'] == 'rotating' &&
        _mealSchedule != null) {
      final oldShifts = _mealSchedule!['shifts'] as List<dynamic>? ?? [];
      final newShifts = List.generate(weeks, (index) {
        final week = index + 1;
        final shiftIndex = oldShifts.indexWhere((s) => s['week'] == week);

        if (shiftIndex != -1) {
          return oldShifts[shiftIndex];
        } else {
          return {
            'week': week,
            'breakfast': '07:00',
            'lunch': '12:00',
            'dinner': '18:00'
          };
        }
      });

      // Create a new meal schedule map to ensure immutability
      _mealSchedule = {
        ..._mealSchedule!,
        'rotation_weeks': weeks,
        'shifts': newShifts,
      };
      notifyListeners();
    }
  }

  // Setters for Preferences
  void togglePrimaryGoal(Map<String, dynamic> goal) {
    final exists =
        _primaryGoals.any((element) => element['value'] == goal['value']);
    if (exists) {
      _primaryGoals.removeWhere((element) => element['value'] == goal['value']);
    } else {
      if (_primaryGoals.length < 5) {
        _primaryGoals.add(goal);
      }
    }
    notifyListeners();
  }

  void setActivityLevel(Map<String, dynamic> level) {
    _activityLevel = level;
    notifyListeners();
  }

  void setDislikedFoods(List<Map<String, dynamic>> foods) {
    _dislikedFoods = foods;
    notifyListeners();
  }

  void toggleDislikedFood(Map<String, dynamic> food) {
    final exists =
        _dislikedFoods.any((element) => element['value'] == food['value']);
    if (exists) {
      _dislikedFoods
          .removeWhere((element) => element['value'] == food['value']);
    } else {
      _dislikedFoods.add(food);
    }
    notifyListeners();
  }

  void setCookingLevel(Map<String, dynamic> level) {
    _cookingLevel = level;
    notifyListeners();
  }

  void toggleKitchenEquipment(Map<String, dynamic> equipment) {
    final exists = _kitchenEquipment
        .any((element) => element['value'] == equipment['value']);
    if (exists) {
      _kitchenEquipment
          .removeWhere((element) => element['value'] == equipment['value']);
    } else {
      _kitchenEquipment.add(equipment);
    }
    notifyListeners();
  }

  /// Onboarding tamamlanma durumunu kontrol et
  bool get isOnboardingComplete {
    return _personalInfo['gender'] != null &&
        _personalInfo['birth_date'] != null &&
        _personalInfo['height'] != null &&
        _personalInfo['weight'] != null &&
        _lifestyleProfile != null &&
        _mealSchedule != null &&
        _primaryGoals.isNotEmpty &&
        _cookingLevel != null &&
        _kitchenEquipment.isNotEmpty;
  }

  /// Onboarding tamamlanma analytics'ini gönder
  Future<void> logOnboardingCompletion() async {
    final analyticsService = AnalyticsService();
    await analyticsService.logEvent(
      name: 'onboarding_completed',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Onboarding verilerini analytics'e gönder
  Future<void> logOnboardingData() async {
    final analyticsService = AnalyticsService();
    await analyticsService.logEvent(
      name: 'onboarding_data',
      parameters: {
        'gender': _personalInfo['gender'] ?? 'unknown',
        'birth_date':
            _personalInfo['birth_date']?.toIso8601String() ?? 'unknown',
        'height': _personalInfo['height'] ?? 0,
        'weight': _personalInfo['weight'] ?? 0,
        'lifestyle_profile': _lifestyleProfile?['value'] ?? 'unknown',
        'primary_goals':
            _primaryGoals.map((e) => e['value'] as String).join(','),
        'activity_level': _activityLevel?['value'] ?? 'unknown',
        'disliked_foods':
            _dislikedFoods.map((e) => e['value'] as String).join(','),
        'cooking_level': _cookingLevel?['value'] ?? 'unknown',
        'kitchen_equipment':
            _kitchenEquipment.map((e) => e['value'] as String).join(','),
      },
    );
  }
}
