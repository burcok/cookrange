/// Typed view over the raw `onboarding_data` Firestore map stored in [UserModel].
///
/// The Firestore schema is unchanged; this model is a parsing layer that
/// replaces raw `user.onboardingData?['key']` casts throughout the codebase.
class UserNutritionProfile {
  final String? gender;
  final DateTime? birthDate;
  final int? heightCm;
  final int? weightKg;
  final String activityLevel;
  final List<String> primaryGoals;
  final List<String> allergyIds;
  final List<String> dietaryRestrictionIds;
  final List<String> dislikedFoodKeys;
  final String? cookingLevel;
  final List<String> kitchenEquipmentIds;
  final String? lifestyleProfile;
  final Map<String, dynamic>? mealSchedule;

  const UserNutritionProfile({
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.activityLevel = 'sedentary',
    this.primaryGoals = const [],
    this.allergyIds = const [],
    this.dietaryRestrictionIds = const [],
    this.dislikedFoodKeys = const [],
    this.cookingLevel,
    this.kitchenEquipmentIds = const [],
    this.lifestyleProfile,
    this.mealSchedule,
  });

  static const UserNutritionProfile empty = UserNutritionProfile();

  factory UserNutritionProfile.fromOnboardingData(Map<String, dynamic>? data) {
    if (data == null) return empty;

    // personal_info may be a nested map or flat
    final raw = data;
    final personalInfo = raw['personal_info'] is Map<String, dynamic>
        ? raw['personal_info'] as Map<String, dynamic>
        : raw;

    return UserNutritionProfile(
      gender: _str(personalInfo, 'gender'),
      birthDate: _parseDate(personalInfo['birth_date']),
      heightCm: _int(personalInfo, 'height'),
      weightKg: _int(personalInfo, 'weight'),
      activityLevel: _extractId(raw['activity_level']) ?? 'sedentary',
      primaryGoals: _extractIds(raw['primary_goals']),
      allergyIds: _extractIds(raw['allergies']),
      dietaryRestrictionIds: _extractIds(raw['dietary_restrictions']),
      dislikedFoodKeys: _extractDislikedFoodKeys(raw['disliked_foods']),
      cookingLevel: _extractId(raw['cooking_level']),
      kitchenEquipmentIds: _extractIds(raw['kitchen_equipments']),
      lifestyleProfile: _extractId(raw['lifestyle_profile']),
      mealSchedule: raw['meal_schedule'] is Map<String, dynamic>
          ? raw['meal_schedule'] as Map<String, dynamic>
          : null,
    );
  }

  /// Age in years, or null if birthDate is unknown.
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int y = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) y--;
    return y;
  }

  // ── Parsing helpers ────────────────────────────────────────────────────────

  static String? _str(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String) return v;
    if (v is Map) return v['value'] as String?;
    return null;
  }

  static int? _int(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }

  static String? _extractId(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) return v['value'] as String?;
    return null;
  }

  static List<String> _extractIds(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) {
          if (e is String) return e;
          if (e is Map) return e['value'] as String? ?? '';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<String> _extractDislikedFoodKeys(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) {
          if (e is String) return e;
          if (e is Map) return (e['value'] ?? e['label']) as String? ?? '';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
