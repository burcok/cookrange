import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_plan_template_model.dart';
import '../models/plan_offer_model.dart';
import '../models/user_model.dart';
import '../models/user_nutrition_profile.dart';
import '../utils/calorie_calculator.dart';
import '../utils/firestore_count.dart';
import 'crashlytics_service.dart';
import 'weekly_meal_plan_service.dart';

/// Faz 3 §3.5 — the send/respond side of the plan-offer flow. Template CRUD
/// itself stays in `MealPlanTemplateService` (§3.3); this service owns
/// everything downstream of "a template exists and someone wants to send or
/// answer it": invoking the `sendPlanOffer` callable, the recipient's own
/// `plan_offers` inbox queries, and accept/decline.
class PlanOfferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final PlanOfferService _instance = PlanOfferService._internal();
  factory PlanOfferService() => _instance;
  PlanOfferService._internal();

  CollectionReference<Map<String, dynamic>> _offersCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('plan_offers');

  // ─── Send (sender side) ────────────────────────────────────────────────

  /// Invokes the `sendPlanOffer` callable (`functions/templates.js`) —
  /// server-authoritative sender/recipient-eligibility checks, immutable
  /// `template_snapshot`, `usage_count` bump, the `plan_offer` chat message,
  /// and the recipient's `planOfferReceived` notification all happen there,
  /// atomically, per recipient. [toUids] covers both single- and multi-select
  /// send (the callable already treats them identically — "toplu gönderimde
  /// her alıcı için ayrı plan_offer").
  ///
  /// Throws `FirebaseFunctionsException` on any rejection (`not_template_
  /// author` / `recipient_not_eligible:{uid}` / `too_many_recipients` /
  /// etc.) — the caller surfaces that to the sender, it is never silently
  /// swallowed.
  Future<int> sendOffer({
    required String templateId,
    required List<String> toUids,
    String message = '',
  }) async {
    try {
      final result =
          await FirebaseFunctions.instance.httpsCallable('sendPlanOffer').call({
        'templateId': templateId,
        'toUids': toUids,
        'message': message,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final sent = (data['sent'] as num?)?.toInt() ?? toUids.length;
      debugPrint(
          'PlanOfferService.sendOffer: sent=$sent templateId=$templateId');
      return sent;
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('PlanOfferService.sendOffer error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'PlanOfferService.sendOffer templateId=$templateId'));
      rethrow;
    } catch (e, st) {
      debugPrint('PlanOfferService.sendOffer error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'PlanOfferService.sendOffer templateId=$templateId'));
      rethrow;
    }
  }

  // ─── Inbox (recipient side) ─────────────────────────────────────────────
  // Backing composite index: plan_offers (status ASC, created_at DESC),
  // queryScope COLLECTION (firestore.indexes.json) — serves streamPendingOffers
  // directly. streamOfferHistory deliberately does NOT filter by status
  // server-side (a plain orderBy needs no composite index) and instead
  // excludes 'pending' client-side — the member's own lifetime offer count is
  // small and bounded, unlike a global collection, so this stays cheap
  // without a second composite index for a rarely-viewed "past offers" list.

  /// Pending offers, newest first — the primary "teklif kutusu" view.
  Stream<List<PlanOffer>> streamPendingOffers(String uid, {int limit = 50}) {
    return _offersCol(uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PlanOffer.fromFirestore).toList())
        .handleError((e) {
      debugPrint('PlanOfferService.streamPendingOffers error: $e');
      return <PlanOffer>[];
    });
  }

  /// Resolved offers (accepted/declined/expired), newest first.
  Stream<List<PlanOffer>> streamOfferHistory(String uid, {int limit = 50}) {
    return _offersCol(uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map(PlanOffer.fromFirestore)
            .where((o) => o.status != 'pending')
            .toList())
        .handleError((e) {
      debugPrint('PlanOfferService.streamOfferHistory error: $e');
      return <PlanOffer>[];
    });
  }

  /// Live-ish pending-offer count for the home-screen discovery banner, via
  /// `pollCount` (cheap `count()` aggregation, polled — never a full
  /// `.snapshots()` listener just to read `.length`, per CLAUDE.md's
  /// counting rule). Mirrors `role_quick_card.dart`'s own gym-member-count
  /// polling exactly (same default interval), wrapped here rather than in
  /// the widget so the widget itself stays free of a direct `cloud_firestore`
  /// import (architecture rule: UI never touches Firebase).
  Stream<int> pollPendingOfferCount(String uid,
      {Duration interval = const Duration(minutes: 2)}) {
    return pollCount(
      _offersCol(uid).where('status', isEqualTo: 'pending'),
      interval: interval,
    );
  }

  Future<PlanOffer?> getOfferOnce(String uid, String offerId) async {
    try {
      final doc = await _offersCol(uid).doc(offerId).get();
      if (!doc.exists) return null;
      return PlanOffer.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('PlanOfferService.getOfferOnce error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'PlanOfferService.getOfferOnce uid=$uid offerId=$offerId'));
      return null;
    }
  }

  // ─── Accept / decline (recipient side) ─────────────────────────────────

  /// Accepts [offer] for [user]: copies its `template_snapshot` into the
  /// member's own `meal_plans/current` (archiving whatever was previously
  /// there first — `WeeklyMealPlanService.adoptTemplate`, the existing
  /// archive mechanism, not reinvented here), THEN — only once that
  /// succeeds — marks the offer `accepted`. This order is deliberate: if the
  /// plan write fails, the offer stays `pending` and the member can retry;
  /// the reverse order could leave an offer marked `accepted` with no plan
  /// actually copied, which is the worse failure mode.
  ///
  /// The Firestore update itself is a plain client write under the already-
  /// tested `plan_offers` rule (`status`+`responded_at` only, `responded_at
  /// == request.time`) — no callable needed; this mirrors exactly what the
  /// rules suite already verifies a recipient can do directly.
  Future<void> acceptOffer({
    required UserModel user,
    required PlanOffer offer,
  }) async {
    final template =
        MealPlanTemplate.fromJson(offer.templateSnapshot, offer.templateId);
    await WeeklyMealPlanService()
        .adoptTemplate(user: user, templateDays: template.days);

    try {
      await _offersCol(user.uid).doc(offer.id).update({
        'status': 'accepted',
        'responded_at': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('PlanOfferService.acceptOffer status-update error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'PlanOfferService.acceptOffer uid=${user.uid} offerId=${offer.id}'));
      rethrow;
    }
  }

  /// Declines [offer]. [reason] is optional free text (≤300 chars, enforced
  /// by `firestore.rules`) forwarded to the ORIGINAL SENDER's quiet
  /// `planOfferDeclined` notification (`functions/templates.js`'s
  /// `onPlanOfferResponded` trigger reads `decline_reason` off this same
  /// update) — "üye baskı altında kalmaz": nothing here requires a reason,
  /// and the notification it produces is deliberately non-judgmental.
  Future<void> declineOffer({
    required String uid,
    required String offerId,
    String? reason,
  }) async {
    final trimmedReason = (reason ?? '').trim();
    final capped = trimmedReason.length > 300
        ? trimmedReason.substring(0, 300)
        : trimmedReason;
    try {
      await _offersCol(uid).doc(offerId).update({
        'status': 'declined',
        'responded_at': FieldValue.serverTimestamp(),
        if (capped.isNotEmpty) 'decline_reason': capped,
      });
    } catch (e, st) {
      debugPrint('PlanOfferService.declineOffer error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'PlanOfferService.declineOffer uid=$uid offerId=$offerId'));
      rethrow;
    }
  }

  // ─── Member's own nutrition target (offer preview) ─────────────────────

  /// The member's own daily-calorie + macro target, for the offer preview's
  /// deviation indicator. Computed the exact same BMR -> TDEE -> goal-
  /// adjusted chain `WeeklyMealPlanService` already runs for AI generation
  /// (kept private there, tied to that call site's own defaults) — this
  /// calls the same public `CalorieCalculator` statics, it does not
  /// re-derive the math, and no new stored "target" field is introduced
  /// (there isn't one anywhere in this schema; every caller computes this
  /// on demand from onboarding profile data).
  static ({double calories, Map<String, double> macros}) computeMemberTarget(
      UserNutritionProfile profile) {
    final height = profile.heightCm?.toDouble() ?? 170;
    final weight = profile.weightKg?.toDouble() ?? 70;
    final age = profile.age ?? 30;
    final gender = profile.gender ?? 'Male';
    final bmr = CalorieCalculator.calculateBMR(
        weight: weight, height: height, age: age, gender: gender);
    final tdee = CalorieCalculator.calculateTDEE(
        bmr: bmr, activityLevel: profile.activityLevel);
    final goal = profile.primaryGoals.isNotEmpty
        ? profile.primaryGoals.first
        : 'maintain_weight';
    final calories =
        CalorieCalculator.adjustTDEEForGoal(tdee: tdee, primaryGoal: goal);
    return (
      calories: calories,
      macros: CalorieCalculator.calculateMacros(calories)
    );
  }
}
