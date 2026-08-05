import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_entry_model.dart';

/// One day inside a template's `days[]` (Faz 3 §3.2). Unlike
/// `DayMealPlan` (which is tied to a concrete `date` — it's a slice of an
/// already-scheduled week), a template day is date-less: it only becomes a
/// dated `DayMealPlan` when a `plan_offers/{id}` is accepted (§3.5), so it
/// carries a 0-based [dayIndex] rather than a date.
class TemplateDay {
  /// 0=Monday .. 6=Sunday.
  final int dayIndex;
  final List<MealEntry> meals;

  const TemplateDay({
    required this.dayIndex,
    required this.meals,
  });

  factory TemplateDay.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'];
    return TemplateDay(
      dayIndex: (json['day_index'] as num?)?.toInt() ?? 0,
      meals: rawMeals is List
          ? rawMeals
              .whereType<Map>()
              .map((m) => MealEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const <MealEntry>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'day_index': dayIndex,
        'meals': meals.map((m) => m.toJson()).toList(),
      };

  TemplateDay copyWith({int? dayIndex, List<MealEntry>? meals}) => TemplateDay(
        dayIndex: dayIndex ?? this.dayIndex,
        meals: meals ?? this.meals,
      );
}

/// `meal_plan_templates/{templateId}` (Faz 3 §3.2) — a reusable weekly plan
/// authored by a gym/coach/admin, independent of any one member's
/// `meal_plans/current`. Sent to a member via a `plan_offers/{id}` (an
/// immutable copy of this doc taken at send time — see `PlanOffer`), never
/// linked live: editing a template after sending never changes an
/// already-sent offer.
class MealPlanTemplate {
  final String id;
  final String authorUid;

  /// 'gym' | 'coach' | 'admin'.
  final String authorType;

  /// Set only when [authorType] == 'gym'.
  final String? gymId;
  final String name;
  final String description;
  final String goal;
  final double targetCalories;

  /// protein/carbs/fat grams — same shape as `WeeklyMealPlanModel.avgMacros`.
  final Map<String, double> targetMacros;
  final List<String> tags;
  final List<TemplateDay> days;
  final int version;

  /// Set when this template was forked from another (§3.3 "var olandan
  /// türet") — not written by anything in this task.
  final String? parentTemplateId;
  final bool isPublic;

  /// 'private' | 'gym' | 'link' | 'marketplace'. Only 'private'/'gym'
  /// (combined with [isPublic]) currently gate anything in `firestore.rules`
  /// — 'link'/'marketplace' are accepted as valid data today but their own
  /// distinct read-access mechanism (most likely a secret-token pattern,
  /// mirroring `community_groups/secrets/invite`) is intentionally left for
  /// whoever builds §3.3/§3.5's sharing UI, not decided here.
  final String shareScope;

  /// Server-only (see `touchesProtectedTemplateFields()` in
  /// `firestore.rules`) — bumped by the `sendPlanOffer` callable, once per
  /// recipient. A client-writable "N sent" counter would be forgeable social
  /// proof, same reasoning as `live_occupancy`/`activity_score` elsewhere.
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealPlanTemplate({
    required this.id,
    required this.authorUid,
    required this.authorType,
    this.gymId,
    required this.name,
    this.description = '',
    this.goal = '',
    this.targetCalories = 0,
    this.targetMacros = const {},
    this.tags = const [],
    this.days = const [],
    this.version = 1,
    this.parentTemplateId,
    this.isPublic = false,
    this.shareScope = 'private',
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealPlanTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlanTemplate.fromJson(data, doc.id);
  }

  factory MealPlanTemplate.fromJson(Map<String, dynamic> json, [String? id]) {
    final rawDays = json['days'];
    final rawMacros = json['target_macros'];
    return MealPlanTemplate(
      id: id ?? json['id'] as String? ?? '',
      authorUid: json['author_uid'] as String? ?? '',
      authorType: json['author_type'] as String? ?? 'admin',
      gymId: json['gym_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0,
      targetMacros: rawMacros is Map
          ? rawMacros.map(
              (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()))
          : <String, double>{},
      tags: List<String>.from(json['tags'] as List? ?? const []),
      days: rawDays is List
          ? rawDays
              .whereType<Map>()
              .map((d) => TemplateDay.fromJson(Map<String, dynamic>.from(d)))
              .toList()
          : const <TemplateDay>[],
      version: (json['version'] as num?)?.toInt() ?? 1,
      parentTemplateId: json['parent_template_id'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      shareScope: json['share_scope'] as String? ?? 'private',
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_uid': authorUid,
      'author_type': authorType,
      'gym_id': gymId,
      'name': name,
      'description': description,
      'goal': goal,
      'target_calories': targetCalories,
      'target_macros': targetMacros,
      'tags': tags,
      'days': days.map((d) => d.toJson()).toList(),
      'version': version,
      'parent_template_id': parentTemplateId,
      'is_public': isPublic,
      'share_scope': shareScope,
      'usage_count': usageCount,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// `usageCount` deliberately has NO override param — it is server-only
  /// (bumped by the `sendPlanOffer` callable; see the field doc above), so
  /// no client-side edit path should ever be able to construct a changed
  /// value for it, even via `copyWith`. Callers that need a fresh unsaved
  /// draft (fork/duplicate) get `usageCount: 0` implicitly by NOT passing it.
  MealPlanTemplate copyWith({
    String? id,
    String? authorUid,
    String? authorType,
    String? gymId,
    bool clearGymId = false,
    String? name,
    String? description,
    String? goal,
    double? targetCalories,
    Map<String, double>? targetMacros,
    List<String>? tags,
    List<TemplateDay>? days,
    int? version,
    String? parentTemplateId,
    bool? isPublic,
    String? shareScope,
    DateTime? updatedAt,
  }) {
    return MealPlanTemplate(
      id: id ?? this.id,
      authorUid: authorUid ?? this.authorUid,
      authorType: authorType ?? this.authorType,
      gymId: clearGymId ? null : (gymId ?? this.gymId),
      name: name ?? this.name,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      targetCalories: targetCalories ?? this.targetCalories,
      targetMacros: targetMacros ?? this.targetMacros,
      tags: tags ?? this.tags,
      days: days ?? this.days,
      version: version ?? this.version,
      parentTemplateId: parentTemplateId ?? this.parentTemplateId,
      isPublic: isPublic ?? this.isPublic,
      shareScope: shareScope ?? this.shareScope,
      usageCount: usageCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
