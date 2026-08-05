import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_entry_model.dart';
import '../models/meal_plan_template_model.dart';
import '../utils/allergen_safety.dart';
import 'ai/ai_service.dart';
import 'ai/prompt_service.dart';
import 'crashlytics_service.dart';
import 'dish_service.dart';

/// Faz 3 §3.3 — CRUD + the exact query shapes the template builder/library
/// screens need, plus AI-draft generation (path 1 of the three creation
/// paths). `meal_plan_templates/{id}` itself and its `firestore.rules` were
/// built in §3.2 (prior task); this is the first service layer on top of it.
///
/// **Never touches `usage_count`.** That field is server-only
/// (`touchesProtectedTemplateFields()` in `firestore.rules`) and is already
/// bumped exactly once, at send time, by the `sendPlanOffer` callable
/// (`functions/templates.js`, shipped in §3.2) — the ONLY place it may ever
/// change. This service only ever reads it for the library's "sent to N
/// members" display. Incrementing it here — or on offer-accept — would
/// double-count against what `sendPlanOffer` already does, or race it; §3.5
/// (send/accept flow, not built here) is the only feature that ever calls
/// `sendPlanOffer`.
class MealPlanTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DishService _dishService = DishService();
  final AIService _aiService = AIService();
  final PromptService _promptService = PromptService();

  static final MealPlanTemplateService _instance =
      MealPlanTemplateService._internal();
  factory MealPlanTemplateService() => _instance;
  MealPlanTemplateService._internal();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('meal_plan_templates');

  // ─── CRUD ────────────────────────────────────────────────────────────────

  Future<MealPlanTemplate?> getTemplate(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return MealPlanTemplate.fromFirestore(doc);
    } catch (e, stack) {
      debugPrint('MealPlanTemplateService.getTemplate error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'MealPlanTemplateService.getTemplate id=$id'));
      return null;
    }
  }

  /// Creates a brand-new template. Always writes `usage_count: 0` and a
  /// fresh server-observed `created_at`/`updated_at`, regardless of what
  /// [draft] carries — matches `firestore.rules`' create-time requirement
  /// and this class's own "never touch usage_count" contract.
  Future<MealPlanTemplate> createTemplate(MealPlanTemplate draft) async {
    final ref = _col.doc();
    final now = DateTime.now();
    final toSave = draft.copyWith(id: ref.id, updatedAt: now);
    try {
      final json = toSave.toJson();
      json['usage_count'] = 0;
      json['created_at'] = Timestamp.fromDate(now);
      await ref.set(json);
      debugPrint('MealPlanTemplateService: created ${ref.id} '
          '(author=${toSave.authorUid}, shareScope=${toSave.shareScope})');
      return toSave;
    } catch (e, stack) {
      debugPrint('MealPlanTemplateService.createTemplate error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'MealPlanTemplateService.createTemplate '
              'author=${draft.authorUid}'));
      rethrow;
    }
  }

  /// Saves edits to an existing template.
  ///
  /// **Version policy (Faz 3 §3.3 decision):** `version` bumps by exactly 1
  /// only when the actual plan CONTENT (`days` — the meals themselves)
  /// changed between [original] and [edited]; a metadata-only edit (rename,
  /// re-tag, goal/target/share_scope change with the same meals) does not.
  /// Rationale: `version` exists so a `plan_offers.template_snapshot` sent
  /// to a member can be traced back to "which content iteration was this",
  /// and a member's nutrition never changes when only metadata changes — so
  /// bumping on every save would make the version number noisy without
  /// tracking anything a recipient could actually feel. This is a version
  /// COUNTER, not a full history: no past `days` snapshot is retained per
  /// version (that would need its own subcollection — deliberately not
  /// built here; see the service-file doc / final report for why).
  ///
  /// Never writes `usage_count` (see class doc) or `created_at`/`author_uid`
  /// (immutable after creation — matches `firestore.rules`, which has no
  /// legitimate client path to change either).
  Future<MealPlanTemplate> saveEdits({
    required MealPlanTemplate original,
    required MealPlanTemplate edited,
  }) async {
    final contentChanged = !_daysEqual(original.days, edited.days);
    final now = DateTime.now();
    final toSave = edited.copyWith(
      id: original.id,
      version: contentChanged ? original.version + 1 : edited.version,
      updatedAt: now,
    );
    try {
      final json = toSave.toJson()
        ..remove('usage_count')
        ..remove('created_at')
        ..remove('author_uid');
      await _col.doc(original.id).update(json);
      debugPrint('MealPlanTemplateService: saved edits ${original.id} '
          '(version ${toSave.version}, contentChanged=$contentChanged)');
      return toSave;
    } catch (e, stack) {
      debugPrint('MealPlanTemplateService.saveEdits error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'MealPlanTemplateService.saveEdits id=${original.id}'));
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _col.doc(id).delete();
      debugPrint('MealPlanTemplateService: deleted $id');
    } catch (e, stack) {
      debugPrint('MealPlanTemplateService.deleteTemplate error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'MealPlanTemplateService.deleteTemplate id=$id'));
      rethrow;
    }
  }

  /// §3.3 path 3 ("var olandan türet") AND the library's "duplicate" action
  /// — both are the same underlying operation: copy [source]'s content into
  /// a brand-new document. The only difference is caller intent (fork opens
  /// the new copy straight into the editor; duplicate just refreshes the
  /// library list), so callers pick which UX to drive, not this method.
  ///
  /// [authorUid] may differ from `source.authorUid` — forking someone
  /// else's gym-shared/public template into your OWN library is exactly
  /// what §3.3 path 3 asks for. Always resets `version` to 1 (a fork starts
  /// its own lineage), `usage_count` to 0 (a fresh copy has never been sent
  /// to anyone), and `share_scope`/`is_public` to private (sharing is a
  /// deliberate re-opt-in on the new copy, never inherited — otherwise
  /// forking a public template would silently make YOUR copy public too).
  /// `parent_template_id` is set to [source.id] either way.
  Future<MealPlanTemplate> forkTemplate(
    MealPlanTemplate source, {
    required String authorUid,
    required String authorType,
    String? gymId,
    String? nameOverride,
  }) async {
    final ref = _col.doc();
    final now = DateTime.now();
    final forked = MealPlanTemplate(
      id: ref.id,
      authorUid: authorUid,
      authorType: authorType,
      gymId: authorType == 'gym' ? gymId : null,
      name: nameOverride ?? source.name,
      description: source.description,
      goal: source.goal,
      targetCalories: source.targetCalories,
      targetMacros: source.targetMacros,
      tags: source.tags,
      days: source.days,
      // version/isPublic/shareScope/usageCount all left at MealPlanTemplate's
      // own defaults (1/false/'private'/0) — that IS the reset this method's
      // doc comment promises, just not spelled out redundantly here.
      parentTemplateId: source.id,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await ref.set(forked.toJson());
      debugPrint('MealPlanTemplateService: forked ${source.id} -> ${ref.id} '
          '(newAuthor=$authorUid)');
      return forked;
    } catch (e, stack) {
      debugPrint('MealPlanTemplateService.forkTemplate error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'MealPlanTemplateService.forkTemplate source=${source.id}'));
      rethrow;
    }
  }

  // ─── Queries (Faz 3 §3.3 — exactly what the library screen needs) ─────────
  // Backing composite indexes added to firestore.indexes.json: author_uid+
  // updated_at DESC · gym_id+share_scope+updated_at DESC · is_public+
  // usage_count DESC. No other query shape is used anywhere in this file.

  /// "My templates" tab — everything I authored, most-recently-updated first.
  Stream<List<MealPlanTemplate>> streamMyTemplates(String authorUid,
      {int limit = 50}) {
    return _col
        .where('author_uid', isEqualTo: authorUid)
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MealPlanTemplate.fromFirestore).toList())
        .handleError((e) {
      debugPrint('MealPlanTemplateService.streamMyTemplates error: $e');
      return <MealPlanTemplate>[];
    });
  }

  /// This gym's `share_scope == 'gym'` pool — the "another author's shared
  /// template, if permitted by share_scope" fork source for a gym-affiliated
  /// author (§3.3 path 3). Mirrors the exact condition `firestore.rules`
  /// already reads this collection under (gym-membership gated), so nothing
  /// this returns can ever fail the read rule.
  Stream<List<MealPlanTemplate>> streamGymSharedTemplates(String gymId,
      {int limit = 50}) {
    return _col
        .where('gym_id', isEqualTo: gymId)
        .where('share_scope', isEqualTo: 'gym')
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MealPlanTemplate.fromFirestore).toList())
        .handleError((e) {
      debugPrint('MealPlanTemplateService.streamGymSharedTemplates error: $e');
      return <MealPlanTemplate>[];
    });
  }

  /// Public/marketplace discovery, most-used first — the other "permitted by
  /// share_scope" fork source (§3.3 path 3), open to any authenticated user
  /// regardless of gym/coach affiliation.
  Stream<List<MealPlanTemplate>> streamPublicTemplates({int limit = 50}) {
    return _col
        .where('is_public', isEqualTo: true)
        .orderBy('usage_count', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MealPlanTemplate.fromFirestore).toList())
        .handleError((e) {
      debugPrint('MealPlanTemplateService.streamPublicTemplates error: $e');
      return <MealPlanTemplate>[];
    });
  }

  // ─── AI draft generation (§3.3 path 1) ────────────────────────────────────

  /// Generates an UNSAVED draft template from the AI. Reuses
  /// `PromptService.generateWeeklyMealPlanPrompt` verbatim (no prompt text is
  /// rebuilt here) and mirrors `WeeklyMealPlanService._generateAndSaveMealPlan`'s
  /// existing, audited shape — the only other AI weekly-plan generator in
  /// the app — rather than inventing a second, divergent one.
  ///
  /// **Mandatory allergen pre-filter**: [allergyIds]/[avoidIngredients] are
  /// run through `AllergenSafety.filterSafe` BEFORE the candidate pool ever
  /// reaches the AI prompt. If that leaves zero safe dishes, generation is
  /// refused (`StateError('no_allergen_safe_dishes')`) rather than risk
  /// serving a plan built from an unsafe pool — same refusal
  /// `WeeklyMealPlanService` already makes.
  ///
  /// **The AI's self-reported totals are deliberately DISCARDED.** Only
  /// `days` (the dish selections) are taken from the response; this method
  /// does not read/return `total_calories`/`avg_daily_calories` at all. The
  /// caller (template creator screen) must compute the draft's actual
  /// nutrition via `PlanNutritionCalculator` before displaying anything —
  /// "the calculated number wins over the LLM's claimed one", exactly the
  /// AI-output-validation use `PlanNutritionCalculator`'s own doc comment
  /// already earmarks for this task. `avg_macros` IS read, but only as a
  /// starting *target* suggestion (editable goal, not a claimed actual).
  ///
  /// Throws on AI failure / empty·malformed response
  /// (`AIFatalException`/`AIQuotaExceededException` from [AIService], or
  /// `FormatException`/`StateError` from this method) — the caller is
  /// responsible for the credit check/rollback UI dance
  /// (`AiCreditService.checkAndConsume`/`rollbackCredit`), exactly like
  /// `MealPlanComparisonSheet` already does around
  /// `generatePlanAlternates` — not duplicated here.
  Future<MealPlanTemplate> generateDraftFromAI({
    required String authorUid,
    required String authorType,
    String? gymId,
    required String goal,
    required double dailyCalorieTarget,
    List<String> dietaryRestrictionIds = const [],
    List<String> allergyIds = const [],
    List<String> avoidIngredients = const [],
    String locale = 'en',
  }) async {
    final dishes = await _dishService.getAllDishes();
    if (dishes.isEmpty) {
      throw StateError('no_dishes_available');
    }

    // Deterministic life-safety filter — BEFORE the AI or the user ever sees
    // a candidate. Backstops the prompt's own allergy instruction, which an
    // LLM may ignore (same reasoning as WeeklyMealPlanService).
    final poolForAi = AllergenSafety.filterSafe(
      dishes,
      allergyIds: allergyIds,
      avoidIngredients: avoidIngredients,
    );
    if (poolForAi.isEmpty) {
      debugPrint('MealPlanTemplateService: no allergen-safe dishes for '
          'author=$authorUid — refusing to generate');
      throw StateError('no_allergen_safe_dishes');
    }

    final userProfile = <String, dynamic>{
      'goal': goal,
      'activity_level': 'moderate',
      'restrictions': dietaryRestrictionIds.isEmpty
          ? 'None'
          : dietaryRestrictionIds.join(', '),
      'allergies': allergyIds.isEmpty ? 'None' : allergyIds.join(', '),
      'dislikes':
          avoidIngredients.isEmpty ? 'None' : avoidIngredients.join(', '),
    };

    final prompt = _promptService.generateWeeklyMealPlanPrompt(
      userProfile: userProfile,
      dailyCalorieTarget: dailyCalorieTarget,
      availableDishes: poolForAi,
      locale: locale,
    );

    final jsonResponse = await _aiService.generateJson(
      prompt: prompt,
      jsonStructure: '{ ... weekly template structure, see '
          'PromptService.generateWeeklyMealPlanPrompt ... }',
      type: 'meal_plan_template',
    );

    final rawDays = jsonResponse['days'];
    if (rawDays is! List || rawDays.isEmpty) {
      throw const FormatException('invalid_ai_response_days');
    }

    final days = <TemplateDay>[];
    for (var i = 0; i < rawDays.length; i++) {
      final d = rawDays[i];
      if (d is! Map) continue;
      final rawMeals = d['meals'];
      final meals = rawMeals is Map
          ? rawMeals.entries
              .map((e) => MealEntry(
                    dishId: e.value?.toString(),
                    mealType: e.key.toString(),
                  ))
              .toList()
          : <MealEntry>[];
      days.add(TemplateDay(dayIndex: i, meals: meals));
    }
    if (days.isEmpty) {
      throw const FormatException('no_valid_days_parsed');
    }

    final rawAvgMacros = jsonResponse['avg_macros'];
    final avgMacros = rawAvgMacros is Map
        ? rawAvgMacros.map<String, double>(
            (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()))
        : <String, double>{};

    final now = DateTime.now();
    return MealPlanTemplate(
      id: '',
      authorUid: authorUid,
      authorType: authorType,
      gymId: authorType == 'gym' ? gymId : null,
      name: '',
      goal: goal,
      targetCalories: dailyCalorieTarget,
      // Starting suggestion only — editable, never displayed as an "actual".
      targetMacros: avgMacros,
      days: days,
      // description/tags/version/isPublic/shareScope/usageCount all left at
      // MealPlanTemplate's own defaults — an unsaved AI draft has none of
      // these yet; the creator screen's editor is where they get filled in.
      createdAt: now,
      updatedAt: now,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  bool _daysEqual(List<TemplateDay> a, List<TemplateDay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].dayIndex != b[i].dayIndex) return false;
      if (!_mealsEqual(a[i].meals, b[i].meals)) return false;
    }
    return true;
  }

  bool _mealsEqual(List<MealEntry> a, List<MealEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.dishId != y.dishId ||
          x.customFood != y.customFood ||
          x.portion != y.portion ||
          x.mealType != y.mealType ||
          x.note != y.note) {
        return false;
      }
    }
    return true;
  }
}
