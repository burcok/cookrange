// Faz A §A8 Faz 0 — the single most valuable test in the config migration
// (see DECISIONS.md ADR-023): asserts every generated schema default
// (lib/core/config/app_config_defaults.g.dart, derived from the canonical
// functions/config_schema.json) equals whatever real, currently-live Dart
// constant it is meant to replace — by importing the REAL classes, not by
// re-reading config_schema.json's own numbers back at itself. This converts
// "did the migration change behavior?" from a manual review question into a
// CI result.
//
// Companion to functions/test/config_schema_defaults.test.js, which covers
// the JS/Cloud-Functions side (the majority of the ~80 hardcoded constants
// this migration targets — economy, gamification, moderation, presence,
// etc. all live server-side). This file covers what's genuinely Dart-only
// or genuinely dual-sourced.
//
// TWO KNOWN, INTENTIONAL exclusions from the generic equality checks below
// — NOT oversights, see DECISIONS.md ADR-023 for the full reasoning:
//   - ai.free_daily_limit / ai.premium_daily_limit: the schema default (2/20)
//     is the RESOLVED value (the server already enforces 2/20 — verified on
//     the JS side against functions/index.js). AiConfig's OWN current
//     default is still the STALE 5/50 (app_config_model.dart) — rewiring
//     that stale value is Faz 1/4's job, not Faz 0's, so asserting equality
//     against it HERE would fail on purpose and for the wrong reason.
//   - features.photo_analysis / weekly_recap / fitness_twin: these
//     REPLACE ai.photo_analysis_enabled / weekly_recap_enabled /
//     fitness_twin_enabled (folded into the generic features.* map as a
//     deliberate schema-authoring simplification — one enable/disable
//     mechanism, not several). There is no like-for-like key to compare.
//
// Also NOT covered here, documented rather than silently skipped:
//   - gamification.max_level: its real Dart source (XpLevelCurve._maxLevel)
//     is a PRIVATE field with no public getter to test against without
//     adding test-only API surface — out of scope (schema + codegen +
//     tests, zero other behavior/API change).
//   - ai.max_retries / ai.retry_delay_s: WAS in this same "private field"
//     category through Faz 0/1/2/3 — see the 'AiConfig: max_retries /
//     retry_delay_s' test below for how Faz 4 resolved it (wired through
//     the already-public AiConfig model instead of adding test-only surface
//     to AIService itself).
//   - economy.streak_freeze_grant_amount, client.weekly_meal_plan_expiry_days:
//     their real Dart sources are bare inline literals
//     (lib/core/services/firestore_service.dart:162 and
//     lib/core/services/weekly_meal_plan_service.dart, respectively), not
//     named constants — nothing to import. Verified by direct source
//     inspection this session (see config_schema.json's `note` field for
//     the exact file:line); extracting named constants purely for
//     testability is a reasonable future micro-improvement, not done here
//     to keep this change to its stated scope.

import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/config/app_config_defaults.g.dart';
import 'package:cookrange/core/models/app_config_model.dart';
import 'package:cookrange/core/models/gym_analytics_model.dart';
import 'package:cookrange/core/models/gym_model.dart';
import 'package:cookrange/core/models/cost_analytics_model.dart';
import 'package:cookrange/core/utils/age_gate.dart';
import 'package:cookrange/core/utils/xp_level_curve.dart';
import 'package:cookrange/core/services/ai/prompt_service.dart';
import 'package:cookrange/core/services/referral_service.dart';

void main() {
  group('AppConfig sub-models — unchanged fields, defaults must match exactly', () {
    test('AiConfig: text_model / vision_model / timeout_s (NOT the resolved-drift pair)', () {
      const d = AiConfig();
      expect(d.textModel, kConfigDefaults['ai.text_model']);
      expect(d.visionModel, kConfigDefaults['ai.vision_model']);
      expect(d.timeoutS, kConfigDefaults['ai.timeout_s']);
    });

    // Faz A Faz 4 — closes this file's own previously-documented gap (see
    // header comment): AIService._maxRetries/_retryDelay are still private
    // with no test-only getter, but they're no longer the real source of
    // truth — AppConfigService._set -> AIService.applyRemoteConfig now feeds
    // them from AiConfig.maxRetries/retryDelayS (app_config_model.dart),
    // which IS public. Also moves ai.max_retries/ai.retry_delay_s from
    // doc:server to doc:client in config_schema.json — the ORIGINAL
    // placement was a bug: AIService (Dart, client-only reader) could never
    // have read a `server`-doc field, per the same placement rule
    // ai.model_by_type's own schema note states in the other direction.
    test('AiConfig: max_retries / retry_delay_s (Faz 4 — was DEAD, now wired)', () {
      const d = AiConfig();
      expect(d.maxRetries, kConfigDefaults['ai.max_retries']);
      expect(d.retryDelayS, kConfigDefaults['ai.retry_delay_s']);
    });

    test('VersionConfig defaults', () {
      const d = VersionConfig();
      expect(d.minSupportedAndroid, kConfigDefaults['version.min_supported_android']);
      expect(d.minSupportedIos, kConfigDefaults['version.min_supported_ios']);
      expect(d.latestAndroid, kConfigDefaults['version.latest_android']);
      expect(d.latestIos, kConfigDefaults['version.latest_ios']);
      expect(d.forceUpdate, kConfigDefaults['version.force_update']);
      expect(d.androidStoreUrl, kConfigDefaults['version.android_store_url']);
      expect(d.iosStoreUrl, kConfigDefaults['version.ios_store_url']);
      expect(d.updateMessage.isEmpty, true);
      expect((kConfigDefaults['version.update_message'] as Map).isEmpty, true);
    });

    test('MaintenanceConfig defaults', () {
      const d = MaintenanceConfig();
      expect(d.enabled, kConfigDefaults['maintenance.enabled']);
      expect(d.message.isEmpty, true);
      expect((kConfigDefaults['maintenance.message'] as Map).isEmpty, true);
    });

    test('AnnouncementConfig defaults', () {
      const d = AnnouncementConfig();
      expect(d.enabled, kConfigDefaults['announcement.enabled']);
      expect(d.id, kConfigDefaults['announcement.id']);
      expect(d.type, kConfigDefaults['announcement.type']);
      expect(d.ctaUrl, kConfigDefaults['announcement.cta_url']);
      expect(d.dismissible, kConfigDefaults['announcement.dismissible']);
      expect(d.message.isEmpty, true);
      expect((kConfigDefaults['announcement.message'] as Map).isEmpty, true);
    });
  });

  group('Client-only hardcoded constants — no JS counterpart', () {
    test('client.min_age_years == AgeGate.kMinimumAgeYears', () {
      expect(AgeGate.kMinimumAgeYears, kConfigDefaults['client.min_age_years']);
    });

    test('client.max_dishes_per_prompt == PromptService.maxDishesPerPrompt', () {
      expect(PromptService.maxDishesPerPrompt,
          kConfigDefaults['client.max_dishes_per_prompt']);
    });

    test('client.referral_pending_code_ttl_days == ReferralService.pendingCodeTtl', () {
      expect(ReferralService.pendingCodeTtl.inDays,
          kConfigDefaults['client.referral_pending_code_ttl_days']);
    });

    test('client.check_in_radius_m == GymModel.checkInRadius default', () {
      final gym = GymModel(
        id: 'test',
        ownerUid: 'test',
        name: 'Test Gym',
        isPublic: true,
        memberCount: 0,
        subscriptionTier: GymSubscriptionTier.free,
        tags: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(gym.checkInRadius, kConfigDefaults['client.check_in_radius_m']);
    });
  });

  group('privacy.k_anonymity_threshold — the value at the center of the '
      'client-side-only gate fix', () {
    test('matches GymAnalyticsModel.kAnonymityThreshold', () {
      expect(GymAnalyticsModel.kAnonymityThreshold,
          kConfigDefaults['privacy.k_anonymity_threshold']);
    });
  });

  group('gamification.level_curve_coefficient — verified indirectly '
      '(the real constant, XpLevelCurve._coefficient, is private)', () {
    test('xpThresholdForLevel(2) implies the schema-declared coefficient', () {
      final coefficient = kConfigDefaults['gamification.level_curve_coefficient'] as int;
      // xpThresholdForLevel(n) = coefficient * n * (n-1); for n=2 that's
      // coefficient * 2 — solving for the coefficient from the PUBLIC
      // method's observable output, exactly like the existing
      // xp_level_curve_test.dart already does for other levels.
      expect(XpLevelCurve.xpThresholdForLevel(2), coefficient * 2);
    });
  });

  group('cost.pricing — CostAnalyticsService\'s estimation constants', () {
    test('FirebasePricing fields', () {
      final pricing = kConfigDefaults['cost.pricing'] as Map;
      expect(FirebasePricing.firestoreReadPer100k, pricing['firestoreReadPer100k']);
      expect(FirebasePricing.firestoreWritePer100k, pricing['firestoreWritePer100k']);
      expect(FirebasePricing.firestoreDeletePer100k, pricing['firestoreDeletePer100k']);
      expect(FirebasePricing.firestoreStoragePerGiBMonth,
          pricing['firestoreStoragePerGiBMonth']);
      expect(FirebasePricing.firestoreFreeStorageGiB, pricing['firestoreFreeStorageGiB']);
      expect(FirebasePricing.firestoreFreeReadsPerDay, pricing['firestoreFreeReadsPerDay']);
      expect(FirebasePricing.firestoreFreeWritesPerDay, pricing['firestoreFreeWritesPerDay']);
      expect(FirebasePricing.storagePerGBMonth, pricing['storagePerGBMonth']);
      expect(FirebasePricing.storageDownloadPerGB, pricing['storageDownloadPerGB']);
      expect(FirebasePricing.storageFreeGB, pricing['storageFreeGB']);
      expect(FirebasePricing.functionsInvocationPerMillion,
          pricing['functionsInvocationPerMillion']);
      expect(FirebasePricing.functionsFreeInvocationsPerMonth,
          pricing['functionsFreeInvocationsPerMonth']);
      expect(FirebasePricing.visionPer1000, pricing['visionPer1000']);
      expect(FirebasePricing.visionFreePerMonth, pricing['visionFreePerMonth']);
    });

    test('OpenRouterPricing fields', () {
      final pricing = kConfigDefaults['cost.pricing'] as Map;
      expect(OpenRouterPricing.costPerCallUsd, pricing['openRouterCostPerCallUsd']);
      expect(
          OpenRouterPricing.costPerVisionCallUsd, pricing['openRouterCostPerVisionCallUsd']);
    });

    test('RevenueAssumptions fields', () {
      final pricing = kConfigDefaults['cost.pricing'] as Map;
      expect(RevenueAssumptions.premiumMonthlyPrice, pricing['premiumMonthlyPrice']);
      expect(RevenueAssumptions.premiumYearlyPricePerMonth,
          pricing['premiumYearlyPricePerMonth']);
      expect(RevenueAssumptions.aiCreditsPackPrice, pricing['aiCreditsPackPrice']);
      expect(RevenueAssumptions.storeCutFraction, pricing['storeCutFraction']);
    });
  });
}
