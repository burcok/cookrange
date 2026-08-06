import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/app_config_model.dart';
import 'package:cookrange/core/config/app_config_defaults.g.dart';

// Faz A Faz 1 — dedicated coverage for the fail-open fix this whole config
// migration exists to close. `AppConfig.isFeatureEnabled`'s old body was
// `features[key] ?? true`: a missing doc, a missing field, or the first
// frames of a cold start all resolved to "every feature enabled," which is
// why gym/coach were live in production despite ADR-012 documenting them
// as deferred-behind-a-switch. These tests pin the corrected three-way
// behavior: explicit override wins > per-key schema default > unknown-key
// closed — never a blanket true.
void main() {
  group('AppConfig.isFeatureEnabled — the fail-open fix', () {
    test('a KNOWN feature key with no explicit value falls back to ITS OWN '
        'schema default, not a blanket true', () {
      const config = AppConfig(); // features: const {} — nothing explicit
      // Per K5, every currently-shipped feature's schema default is true —
      // this assertion is about WHERE that true comes from, verified via
      // the schema-generated map, not hardcoded as a second copy here.
      for (final key in [
        'gym', 'coach', 'programs', 'squad', 'meal_plan_templates',
        'gym_invite_codes', 'gym_attribution', 'community', 'chat',
        'food_scan', 'marketplace', 'referral', 'voice_assistant',
        'nutrition_analytics', 'photo_analysis', 'weekly_recap', 'fitness_twin',
      ]) {
        final schemaDefault = kConfigDefaults['features.$key'];
        expect(schemaDefault, isA<bool>(),
            reason: 'features.$key must be in the schema with a bool default');
        expect(config.isFeatureEnabled(key), schemaDefault,
            reason: 'isFeatureEnabled("$key") must equal the schema default, '
                'not a hardcoded assumption');
      }
    });

    test('an UNKNOWN key (not in the schema at all) is CLOSED, never open', () {
      const config = AppConfig();
      expect(kConfigDefaults.containsKey('features.this_key_does_not_exist'),
          false);
      expect(config.isFeatureEnabled('this_key_does_not_exist'), false);
    });

    test('an explicit admin override of false is respected even though the '
        'schema default is true', () {
      const config = AppConfig(features: {'gym': false});
      expect(kConfigDefaults['features.gym'], true,
          reason: "this test is only meaningful if the schema default IS true");
      expect(config.isFeatureEnabled('gym'), false);
    });

    test('an explicit admin override of true is respected for a key whose '
        'schema default is also true (no accidental flip)', () {
      const config = AppConfig(features: {'gym': true});
      expect(config.isFeatureEnabled('gym'), true);
    });

    test('fromMap: an explicit null value for a KNOWN key falls back to '
        "that key's schema default at PARSE time, not a blanket true — "
        'closing the bug one layer deeper than the outer lookup', () {
      // A key present with an explicit null is an edge case (an admin or a
      // buggy write producing `{"gym": null}`), but must not silently
      // resolve to enabled just because it's syntactically "present."
      final config = AppConfig.fromMap({
        'features': {'gym': null},
      });
      // Parsed value should equal the schema default (true today), and
      // critically arrived at via the schema, not the old blanket literal.
      expect(config.features['gym'], kConfigDefaults['features.gym']);
    });

    test('fromMap: a genuinely absent features map still resolves every '
        'known key via isFeatureEnabled (not just an empty parsed map)', () {
      final config = AppConfig.fromMap(const {});
      expect(config.features, isEmpty);
      expect(config.isFeatureEnabled('coach'), kConfigDefaults['features.coach']);
    });
  });

  group('AiConfig — the resolved AI-quota drift', () {
    test('freeDailyLimit/premiumDailyLimit match the server-enforced values '
        '(2/20), not the old stale client default (5/50)', () {
      const d = AiConfig();
      expect(d.freeDailyLimit, 2);
      expect(d.premiumDailyLimit, 20);
      expect(d.freeDailyLimit, kConfigDefaults['ai.free_daily_limit']);
      expect(d.premiumDailyLimit, kConfigDefaults['ai.premium_daily_limit']);
    });
  });
}
