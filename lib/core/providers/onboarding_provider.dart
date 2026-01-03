import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../constants/onboarding_options.dart';

class OnboardingProvider with ChangeNotifier {
  // Personal Info
  Map<String, dynamic> _personalInfo = {
    'gender': null,
    'birth_date': null,
    'height': null,
    'weight': null,
  };
  int? _targetWeight;
  String? _lifestyleProfileId;
  Map<String, dynamic>?
      _mealSchedule; // Stores meal times for different schedules

  // Preferences
  List<String> _primaryGoalIds = [];
  String? _activityLevelId;
  List<Map<String, dynamic>> _dislikedFoods = [];
  String? _cookingLevelId;
  List<String> _kitchenEquipmentIds = [];

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
  Map<String, dynamic>? get lifestyleProfile {
    if (_lifestyleProfileId == null) return null;
    final option = OnboardingOptions.lifestyleProfiles[_lifestyleProfileId];
    if (option != null) {
      return {
        'label': option['label'],
        'value': _lifestyleProfileId,
        'image': option['image'],
      };
    }
    return {'label': _lifestyleProfileId, 'value': _lifestyleProfileId};
  }

  Map<String, dynamic>? get mealSchedule => _mealSchedule;

  // Getters for Preferences
  List<Map<String, dynamic>> get primaryGoals {
    return _primaryGoalIds.map((id) {
      final option = OnboardingOptions.primaryGoals[id];
      if (option != null) {
        return {
          'label': option['label'],
          'value': id,
          'icon': option['icon'] is IconData
              ? (option['icon'] as IconData).codePoint
              : option['icon'],
        };
      }
      return {'label': id, 'value': id};
    }).toList();
  }

  Map<String, dynamic>? get activityLevel {
    if (_activityLevelId == null) return null;
    final option = OnboardingOptions.activityLevels[_activityLevelId];
    if (option != null) {
      return {
        'label': option['label'],
        'value': _activityLevelId,
        'icon': option['icon'] is IconData
            ? (option['icon'] as IconData).codePoint
            : option['icon'],
      };
    }
    return {'label': _activityLevelId, 'value': _activityLevelId};
  }

  List<Map<String, dynamic>> get dislikedFoods => _dislikedFoods;

  Map<String, dynamic>? get cookingLevel {
    if (_cookingLevelId == null) return null;
    final option = OnboardingOptions.cookingLevels[_cookingLevelId];
    if (option != null) {
      return {
        'label': option['label'],
        'value': _cookingLevelId,
        'icon': option['icon'] is IconData
            ? (option['icon'] as IconData).codePoint
            : option['icon'],
      };
    }
    return {'label': _cookingLevelId, 'value': _cookingLevelId};
  }

  List<Map<String, dynamic>> get kitchenEquipment {
    return _kitchenEquipmentIds.map((id) {
      final label = OnboardingOptions.kitchenEquipment[id];
      return {
        'label': label ?? id,
        'value': id,
      };
    }).toList();
  }

  bool get isDirty {
    final currentData = _toMap();
    if (_initialData == null) return false;

    // Compare field by field
    return !mapEquals(
            _initialData!['personal_info'], currentData['personal_info']) ||
        _initialData!['lifestyle_profile'] != _lifestyleProfileId ||
        !mapEquals(_initialData!['meal_schedule'] as Map?, _mealSchedule) ||
        !listEquals(_initialData!['primary_goals'] as List?, _primaryGoalIds) ||
        _initialData!['activity_level'] != _activityLevelId ||
        !_dislikedFoodsEquals(
            _initialData!['disliked_foods'] as List?, _dislikedFoods) ||
        _initialData!['cooking_level'] != _cookingLevelId ||
        !listEquals(
            _initialData!['kitchen_equipments'] as List?, _kitchenEquipmentIds);
  }

  bool _dislikedFoodsEquals(List? a, List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      final itemA = a[i];
      final itemB = b[i];
      if (itemA is String && itemB is String) {
        if (itemA != itemB) return false;
      } else if (itemA is Map && itemB is Map) {
        if (!mapEquals(
            itemA as Map<String, dynamic>, itemB as Map<String, dynamic>))
          return false;
      } else {
        return false;
      }
    }
    return true;
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
      'lifestyle_profile': _lifestyleProfileId,
      'meal_schedule': _mealSchedule,
      'primary_goals': _primaryGoalIds,
      'activity_level': _activityLevelId,
      'disliked_foods': _dislikedFoods.map((f) {
        if (OnboardingOptions.predefinedIngredients.containsKey(f['value'])) {
          return f['value'];
        }
        return f;
      }).toList(),
      'cooking_level': _cookingLevelId,
      'kitchen_equipments': _kitchenEquipmentIds,
    };
  }

  void _setInitialData() {
    _initialData = _toMap();
  }

  DateTime? _parseBirthDate(dynamic birthDate) {
    if (birthDate is String) {
      return DateTime.tryParse(birthDate);
    } else if (birthDate != null) {
      if (kDebugMode) {
        print(
            'Warning: birth_date was expected to be a String but received type ${birthDate.runtimeType}.');
      }
    }
    return null;
  }

  String? _getString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    if (value is Map) return value['value'] as String?;
    return null;
  }

  int? _getInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void initializeFromFirestore(Map<String, dynamic> data) {
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
      _personalInfo['gender'] = _getString(onboardingData, 'gender');
      _personalInfo['birth_date'] =
          _parseBirthDate(onboardingData['birth_date']);
      _personalInfo['height'] = _getInt(onboardingData, 'height');
      _personalInfo['weight'] = _getInt(onboardingData, 'weight');
    }

    _lifestyleProfileId = _extractId(onboardingData['lifestyle_profile']);
    _mealSchedule = _convertToMap(onboardingData['meal_schedule']);
    _primaryGoalIds = _extractIds(onboardingData['primary_goals']);
    _activityLevelId = _extractId(onboardingData['activity_level']);
    _dislikedFoods = _convertDislikedFoods(onboardingData['disliked_foods']);
    _cookingLevelId = _extractId(onboardingData['cooking_level']);
    _kitchenEquipmentIds = _extractIds(onboardingData['kitchen_equipments']);

    _setInitialData();
    notifyListeners();
  }

  String? _extractId(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) return data['value'] as String?;
    return null;
  }

  List<String> _extractIds(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data
          .map((item) {
            if (item is String) return item;
            if (item is Map) return item['value'] as String;
            return '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _convertDislikedFoods(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data
          .map((item) {
            if (item is String) {
              final label = OnboardingOptions.predefinedIngredients[item];
              return {
                'label': label ?? item,
                'value': item,
              };
            }
            if (item is Map<String, dynamic>) return item;
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    return [];
  }

  Map<String, dynamic>? _convertToMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return {'label': data, 'value': data};
    return null;
  }

  Future<void> updateOnboardingDataInFirestore() async {
    final authService = AuthService();
    if (authService.currentUser == null) return;
    final onboardingData = _toMap();
    if (onboardingData.isNotEmpty) {
      await authService.updateUserData({'onboarding_data': onboardingData});
      _setInitialData();
    }
  }

  Future<bool> saveFinalOnboardingData() async {
    final authService = AuthService();
    if (authService.currentUser == null) return false;
    if (!isOnboardingComplete) return false;
    final onboardingData = _toMap();
    if (onboardingData.isNotEmpty) {
      try {
        await authService.updateUserData({
          'onboarding_data': onboardingData,
          'onboarding_completed': true,
        });
        _setInitialData();
        return true;
      } catch (e) {
        if (kDebugMode) print('Error saving onboarding data: $e');
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
      'weight': null
    };
    _targetWeight = null;
    _lifestyleProfileId = null;
    _mealSchedule = null;
    _primaryGoalIds = [];
    _activityLevelId = null;
    _dislikedFoods = [];
    _cookingLevelId = null;
    _kitchenEquipmentIds = [];
    _initialData = null;
    notifyListeners();
  }

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

  void setLifestyleProfile(String profileId) {
    if (_lifestyleProfileId != profileId) {
      _lifestyleProfileId = profileId;
      notifyListeners();
    }
  }

  void setScheduleType(String type, {List<String>? mealTimes}) {
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
      newSchedule = {};
    }
    if (!mapEquals(_mealSchedule, newSchedule)) {
      _mealSchedule = newSchedule;
      notifyListeners();
    }
  }

  void updateMealTime(String meal, String time, {int? week}) {
    if (_mealSchedule?['schedule_type'] == 'irregular' ||
        _mealSchedule?['schedule_type'] == 'fixed') {
      if (_mealSchedule != null) {
        _mealSchedule = Map<String, dynamic>.from(_mealSchedule!);
        _mealSchedule![meal] = time;
        notifyListeners();
      }
    } else if (_mealSchedule?['schedule_type'] == 'rotating' && week != null) {
      if (_mealSchedule != null && _mealSchedule!['shifts'] is List) {
        final newShifts = (_mealSchedule!['shifts'] as List).map((shift) {
          if (shift['week'] == week) {
            final newShift = Map<String, dynamic>.from(shift);
            newShift[meal] = time;
            return newShift;
          }
          return shift;
        }).toList();
        _mealSchedule = {..._mealSchedule!, 'shifts': newShifts};
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
        return shiftIndex != -1
            ? oldShifts[shiftIndex]
            : {
                'week': week,
                'breakfast': '07:00',
                'lunch': '12:00',
                'dinner': '18:00'
              };
      });
      _mealSchedule = {
        ..._mealSchedule!,
        'rotation_weeks': weeks,
        'shifts': newShifts
      };
      notifyListeners();
    }
  }

  void togglePrimaryGoal(String goalId) {
    if (_primaryGoalIds.contains(goalId)) {
      _primaryGoalIds.remove(goalId);
    } else if (_primaryGoalIds.length < 5) {
      _primaryGoalIds.add(goalId);
    }
    notifyListeners();
  }

  void setActivityLevel(String levelId) {
    if (_activityLevelId != levelId) {
      _activityLevelId = levelId;
      notifyListeners();
    }
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

  void setCookingLevel(String levelId) {
    if (_cookingLevelId != levelId) {
      _cookingLevelId = levelId;
      notifyListeners();
    }
  }

  void toggleKitchenEquipment(String equipmentId) {
    if (_kitchenEquipmentIds.contains(equipmentId)) {
      _kitchenEquipmentIds.remove(equipmentId);
    } else {
      _kitchenEquipmentIds.add(equipmentId);
    }
    notifyListeners();
  }

  bool get isOnboardingComplete {
    return _personalInfo['gender'] != null &&
        _personalInfo['birth_date'] != null &&
        _personalInfo['height'] != null &&
        _personalInfo['weight'] != null &&
        _lifestyleProfileId != null &&
        _mealSchedule != null &&
        _primaryGoalIds.isNotEmpty &&
        _cookingLevelId != null &&
        _kitchenEquipmentIds.isNotEmpty;
  }

  Future<void> logOnboardingCompletion() async {
    final analyticsService = AnalyticsService();
    await analyticsService.logEvent(
        name: 'onboarding_completed',
        parameters: {'timestamp': DateTime.now().toIso8601String()});
  }

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
        'lifestyle_profile': _lifestyleProfileId ?? 'unknown',
        'primary_goals': _primaryGoalIds.join(','),
        'activity_level': _activityLevelId ?? 'unknown',
        'disliked_foods':
            _dislikedFoods.map((e) => e['value'] as String).join(','),
        'cooking_level': _cookingLevelId ?? 'unknown',
        'kitchen_equipment': _kitchenEquipmentIds.join(','),
      },
    );
  }
}
