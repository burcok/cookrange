import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../constants/onboarding_options.dart';
import '../utils/age_gate.dart';

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
  List<String> _allergyIds = [];
  List<String> _dietaryRestrictionIds = [];
  String? _cookingLevelId;
  List<String> _kitchenEquipmentIds = [];

  // --- Onboarding V2 additions (collected pre-registration, in-memory) ---
  /// First name (page 1) → persisted as the account `displayName` at registration.
  String? _firstName;

  /// Single primary goal (page 2): lose_weight | gain_weight | build_muscle | healthy_eating.
  /// Distinct from [_primaryGoalIds], which are the multi-select "motivators" (page 3).
  String? _mainGoal;

  /// Water reminder (page 11). [_waterDailyTargetMl] is computed but user-adjustable.
  bool _waterReminderEnabled = true;
  int? _waterDailyTargetMl;
  String _waterWakeTime = '08:00';
  String _waterSleepTime = '23:00';

  /// Household (page 12) — captured only; per-person meal scaling is shelved.
  bool _cooksForOthers = false;

  /// Premium intent (page 13). Transient: drives the post-registration purchase,
  /// never written into `onboarding_data`.
  bool _wantsPremiumIntent = false;

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
  List<String> get allergyIds => List.unmodifiable(_allergyIds);
  List<String> get dietaryRestrictionIds =>
      List.unmodifiable(_dietaryRestrictionIds);

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

  // --- Onboarding V2 getters ---
  String? get firstName => _firstName;
  String? get mainGoal => _mainGoal;
  bool get waterReminderEnabled => _waterReminderEnabled;
  int? get waterDailyTargetMl => _waterDailyTargetMl;
  String get waterWakeTime => _waterWakeTime;
  String get waterSleepTime => _waterSleepTime;
  bool get cooksForOthers => _cooksForOthers;
  bool get wantsPremiumIntent => _wantsPremiumIntent;

  /// Whole-year age derived from [birthDate], or null if unset.
  int? get ageYears =>
      birthDate == null ? null : AgeGate.ageInYears(birthDate!);

  /// Non-PII payload for the public `users/{uid}.onboarding_data` map, written
  /// once at registration. Mirrors [_toPublicMap].
  Map<String, dynamic> get publicOnboardingData => _toPublicMap();

  /// PII payload for the owner-only `users/{uid}/private/nutrition` doc, written
  /// once at registration. Mirrors [_toPrivateMap].
  Map<String, dynamic> get privateNutritionData => _toPrivateMap();

  bool get isDirty {
    final currentData = _toMap();
    if (_initialData == null) return false;

    return !mapEquals(
            _initialData!['personal_info'], currentData['personal_info']) ||
        _initialData!['lifestyle_profile'] != _lifestyleProfileId ||
        !mapEquals(_initialData!['meal_schedule'] as Map?, _mealSchedule) ||
        !listEquals(_initialData!['primary_goals'] as List?, _primaryGoalIds) ||
        _initialData!['activity_level'] != _activityLevelId ||
        !_dislikedFoodsEquals(
            _initialData!['disliked_foods'] as List?, _dislikedFoods) ||
        !listEquals(_initialData!['allergies'] as List?, _allergyIds) ||
        !listEquals(_initialData!['dietary_restrictions'] as List?,
            _dietaryRestrictionIds) ||
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
            itemA as Map<String, dynamic>, itemB as Map<String, dynamic>)) {
          return false;
        }
      } else {
        return false;
      }
    }
    return true;
  }

  /// Non-PII fields — stored on the public `users/{uid}.onboarding_data` map.
  Map<String, dynamic> _toPublicMap() {
    return {
      'lifestyle_profile': _lifestyleProfileId,
      'meal_schedule': _mealSchedule,
      'primary_goals': _primaryGoalIds,
      'activity_level': _activityLevelId,
      'cooking_level': _cookingLevelId,
      'kitchen_equipments': _kitchenEquipmentIds,
      // V2 additions
      'main_goal': _mainGoal,
      'target_weight': _targetWeight,
      'water_reminder': {
        'enabled': _waterReminderEnabled,
        'target_ml': _waterDailyTargetMl,
        'wake': _waterWakeTime,
        'sleep': _waterSleepTime,
      },
      'cooks_for_others': _cooksForOthers,
    };
  }

  /// PII fields — stored in the owner-only `users/{uid}/private/nutrition` doc.
  Map<String, dynamic> _toPrivateMap() {
    return {
      'personal_info': {
        'gender': _personalInfo['gender'],
        'birth_date': _personalInfo['birth_date'] is DateTime
            ? (_personalInfo['birth_date'] as DateTime).toIso8601String()
            : _personalInfo['birth_date'],
        'height': _personalInfo['height'],
        'weight': _personalInfo['weight'],
      },
      'disliked_foods': _dislikedFoods.map((f) {
        if (OnboardingOptions.predefinedIngredients.containsKey(f['value'])) {
          return f['value'];
        }
        return f;
      }).toList(),
      'allergies': _allergyIds,
      'dietary_restrictions': _dietaryRestrictionIds,
    };
  }

  /// Full merged map — used internally by [isDirty] check and
  /// [initializeFromFirestore] for backward compat when the caller passes
  /// combined data (public + private merged by [UserProvider]).
  Map<String, dynamic> _toMap() => {
        ..._toPublicMap(),
        ..._toPrivateMap(),
      };

  void _setInitialData() {
    _initialData = _toMap();
  }

  DateTime? _parseBirthDate(dynamic birthDate) {
    if (birthDate is String) {
      return DateTime.tryParse(birthDate);
    } else if (birthDate != null) {
      if (kDebugMode) {
        debugPrint(
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
    _allergyIds = _extractIds(onboardingData['allergies']);
    _dietaryRestrictionIds =
        _extractIds(onboardingData['dietary_restrictions']);
    _cookingLevelId = _extractId(onboardingData['cooking_level']);
    _kitchenEquipmentIds = _extractIds(onboardingData['kitchen_equipments']);

    // V2 fields (tolerant: legacy docs simply lack these keys)
    _mainGoal = _extractId(onboardingData['main_goal']);
    _targetWeight = _getInt(onboardingData, 'target_weight');
    _cooksForOthers = onboardingData['cooks_for_others'] == true;
    final water = onboardingData['water_reminder'];
    if (water is Map) {
      _waterReminderEnabled = water['enabled'] == true;
      _waterDailyTargetMl = _getInt(water.cast<String, dynamic>(), 'target_ml');
      _waterWakeTime = (water['wake'] as String?) ?? _waterWakeTime;
      _waterSleepTime = (water['sleep'] as String?) ?? _waterSleepTime;
    }

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

  /// Persists the collected V2 profile against [user]'s account (existing or
  /// just-created): updates the Firebase Auth display name, writes the public
  /// `onboarding_data` map + `onboarding_completed: true` to the user doc, and
  /// the PII to the owner-only `private/nutrition` subcollection.
  ///
  /// Pure persistence: callers own consent recording, reminder scheduling,
  /// [UserProvider] population, navigation, and [reset] — these differ between
  /// new-account registration and logged-in completion. See
  /// `screens/onboarding/v2/onboarding_completion.dart`.
  Future<void> persistV2Profile(User user) async {
    final uid = user.uid;
    final name = _firstName;
    if (name != null && name.isNotEmpty) {
      try {
        await user.updateDisplayName(name);
      } catch (_) {}
    }
    await FirestoreService().updateUserData(uid, {
      if (name != null && name.isNotEmpty) 'displayName': name,
      'onboarding_data': _toPublicMap(),
      'onboarding_completed': true,
    });
    // Best-effort: a private-nutrition write hiccup must not undo the
    // authoritative completion flag written above.
    try {
      await FirestoreService().savePrivateNutritionData(uid, _toPrivateMap());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('persistV2Profile: private nutrition write failed: $e');
      }
    }
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
    _allergyIds = [];
    _dietaryRestrictionIds = [];
    _cookingLevelId = null;
    _kitchenEquipmentIds = [];
    _firstName = null;
    _mainGoal = null;
    _waterReminderEnabled = false;
    _waterDailyTargetMl = null;
    _waterWakeTime = '08:00';
    _waterSleepTime = '23:00';
    _cooksForOthers = false;
    _wantsPremiumIntent = false;
    _initialData = null;
    notifyListeners();
  }

  void setTargetWeight(int? weight) {
    if (_targetWeight != weight) {
      _targetWeight = weight;
      notifyListeners();
    }
  }

  // --- Onboarding V2 setters ---
  void setFirstName(String? name) {
    final trimmed = name?.trim();
    final value = (trimmed != null && trimmed.isEmpty) ? null : trimmed;
    if (_firstName != value) {
      _firstName = value;
      notifyListeners();
    }
  }

  void setMainGoal(String? goal) {
    if (_mainGoal != goal) {
      _mainGoal = goal;
      notifyListeners();
    }
  }

  void setWaterReminder({
    required bool enabled,
    int? targetMl,
    String? wake,
    String? sleep,
  }) {
    var changed = false;
    if (_waterReminderEnabled != enabled) {
      _waterReminderEnabled = enabled;
      changed = true;
    }
    if (targetMl != null && _waterDailyTargetMl != targetMl) {
      _waterDailyTargetMl = targetMl;
      changed = true;
    }
    if (wake != null && _waterWakeTime != wake) {
      _waterWakeTime = wake;
      changed = true;
    }
    if (sleep != null && _waterSleepTime != sleep) {
      _waterSleepTime = sleep;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void setCooksForOthers(bool value) {
    if (_cooksForOthers != value) {
      _cooksForOthers = value;
      notifyListeners();
    }
  }

  void setWantsPremiumIntent(bool value) {
    if (_wantsPremiumIntent != value) {
      _wantsPremiumIntent = value;
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

  void toggleAllergy(String allergyId) {
    if (_allergyIds.contains(allergyId)) {
      _allergyIds.remove(allergyId);
    } else {
      _allergyIds.add(allergyId);
    }
    notifyListeners();
  }

  void toggleDietaryRestriction(String restrictionId) {
    if (_dietaryRestrictionIds.contains(restrictionId)) {
      _dietaryRestrictionIds.remove(restrictionId);
    } else {
      _dietaryRestrictionIds.add(restrictionId);
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

  /// Final safety gate for the V2 flow (before "Onayla" → registration).
  /// Each page gates its own field, so this should always be true on arrival;
  /// it guards against navigation bugs. Distinct from [isOnboardingComplete],
  /// which the legacy flow still uses (kept intact until V2 fully replaces it).
  bool get isV2Complete {
    return _firstName != null &&
        _firstName!.isNotEmpty &&
        _mainGoal != null &&
        _activityLevelId != null &&
        isOnboardingComplete;
  }
}
