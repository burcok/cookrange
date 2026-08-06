'use strict';

// Unit tests for the pure logic inside app_config_admin.js — no Firestore,
// no Admin SDK. The callables themselves (updateAppConfig/
// rollbackAppConfig/updateContentFilter) are covered by the emulator-based
// Firestore rules suite (test/firestore_rules/rules.test.mjs), which is
// where an admin-check/rate-limit/write-lockdown claim actually needs to
// be proven against real security rules, not mocked.
//
//   node --test functions/test/app_config_admin.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const {
  setNestedValue, getNestedValue, crossFieldInvariantErrors, schemaEntriesForDoc, validateValueShape,
} = require('../app_config_admin');
const schema = require('../config_schema.json');

describe('setNestedValue / getNestedValue', () => {
  test('sets a top-level key', () => {
    const target = {};
    setNestedValue(target, 'foo', 1);
    assert.deepEqual(target, { foo: 1 });
  });

  test('creates intermediate nested objects as needed', () => {
    const target = {};
    setNestedValue(target, 'ai.free_daily_limit', 2);
    assert.deepEqual(target, { ai: { free_daily_limit: 2 } });
  });

  test('does not disturb sibling keys at any level', () => {
    const target = { ai: { text_model: 'x', timeout_s: 90 } };
    setNestedValue(target, 'ai.free_daily_limit', 2);
    assert.deepEqual(target, { ai: { text_model: 'x', timeout_s: 90, free_daily_limit: 2 } });
  });

  test('overwrites a non-object intermediate value with an object rather than throwing', () => {
    const target = { ai: 'not-an-object' };
    setNestedValue(target, 'ai.free_daily_limit', 2);
    assert.deepEqual(target, { ai: { free_daily_limit: 2 } });
  });

  test('getNestedValue reads back exactly what setNestedValue wrote', () => {
    const target = {};
    setNestedValue(target, 'gamification.tier_level_floor.active', 5);
    assert.equal(getNestedValue(target, 'gamification.tier_level_floor.active'), 5);
  });

  test('getNestedValue returns undefined for a missing path, never throws', () => {
    assert.equal(getNestedValue({}, 'a.b.c'), undefined);
    assert.equal(getNestedValue({ a: 1 }, 'a.b.c'), undefined);
    assert.equal(getNestedValue(null, 'a.b'), undefined);
  });
});

describe('crossFieldInvariantErrors', () => {
  test('no errors on an empty document', () => {
    assert.deepEqual(crossFieldInvariantErrors({}), []);
  });

  test('rejects premium_daily_limit < free_daily_limit', () => {
    const errors = crossFieldInvariantErrors({ ai: { free_daily_limit: 20, premium_daily_limit: 2 } });
    assert.ok(errors.some((e) => e.includes('premium_daily_limit')));
  });

  test('accepts premium_daily_limit >= free_daily_limit', () => {
    const errors = crossFieldInvariantErrors({ ai: { free_daily_limit: 2, premium_daily_limit: 20 } });
    assert.equal(errors.length, 0);
  });

  test('rejects quiet_hours_start >= quiet_hours_end', () => {
    const errors = crossFieldInvariantErrors({ presence: { quiet_hours_start: 23, quiet_hours_end: 7 } });
    assert.ok(errors.some((e) => e.includes('quiet_hours')));
  });

  test('rejects quiet_hours_start == quiet_hours_end (not just start > end)', () => {
    const errors = crossFieldInvariantErrors({ presence: { quiet_hours_start: 8, quiet_hours_end: 8 } });
    assert.ok(errors.some((e) => e.includes('quiet_hours')));
  });

  test('rejects a text_model not present in a non-empty allowed_models list', () => {
    const errors = crossFieldInvariantErrors({
      ai: { text_model: 'not-allowed', allowed_models: ['openrouter/free'] },
    });
    assert.ok(errors.some((e) => e.includes('allowed_models')));
  });

  test('accepts a text_model present in allowed_models', () => {
    const errors = crossFieldInvariantErrors({
      ai: { text_model: 'openrouter/free', allowed_models: ['openrouter/free'] },
    });
    assert.equal(errors.length, 0);
  });

  test('an EMPTY allowed_models list means no restriction at all', () => {
    const errors = crossFieldInvariantErrors({ ai: { text_model: 'anything', allowed_models: [] } });
    assert.equal(errors.length, 0);
  });

  test('rejects a non-ascending tier_level_floor', () => {
    const errors = crossFieldInvariantErrors({
      gamification: { tier_level_floor: { newcomer: 1, active: 5, contributor: 3, expert: 20, legend: 35 } },
    });
    assert.ok(errors.some((e) => e.includes('tier_level_floor')));
  });

  test('accepts a strictly ascending tier_level_floor', () => {
    const errors = crossFieldInvariantErrors({
      gamification: { tier_level_floor: { newcomer: 1, active: 5, contributor: 10, expert: 20, legend: 35 } },
    });
    assert.equal(errors.length, 0);
  });

  test('multiple simultaneous violations are all reported, not just the first', () => {
    const errors = crossFieldInvariantErrors({
      ai: { free_daily_limit: 20, premium_daily_limit: 2 },
      presence: { quiet_hours_start: 23, quiet_hours_end: 7 },
    });
    assert.equal(errors.length, 2);
  });
});

describe('schemaEntriesForDoc', () => {
  test('every returned entry actually has doc === the requested doc', () => {
    for (const doc of ['critical', 'client', 'server']) {
      const entries = schemaEntriesForDoc(doc);
      assert.ok(entries.size > 0, `expected at least one entry for doc="${doc}"`);
      for (const entry of entries.values()) {
        assert.equal(entry.doc, doc);
      }
    }
  });

  test('a made-up doc name returns an empty map, not an error', () => {
    assert.equal(schemaEntriesForDoc('not_a_real_doc').size, 0);
  });

  test('critical/client/server partition config_schema.json exhaustively (every non-_meta key lands in exactly one)', () => {
    const allKeys = Object.keys(schema).filter((k) => k !== '_meta');
    const covered = new Set([
      ...schemaEntriesForDoc('critical').keys(),
      ...schemaEntriesForDoc('client').keys(),
      ...schemaEntriesForDoc('server').keys(),
    ]);
    assert.equal(covered.size, allKeys.length);
  });
});

// M3.5 — the 15 object/map<string,object> entries used to accept ANY object
// shape at all (validateType only checked "is this an object"). validateType
// itself is unchanged (still not exported — see file header); these tests
// go straight at validateValueShape, the new second pass that actually
// checks what's INSIDE the object, against the real schema entries rather
// than hand-rolled fixtures, so a future edit to one of these 15 entries'
// value_shape is what these tests actually exercise.
describe('validateValueShape', () => {
  test('every one of the 15 object/map<string,object> schema entries declares a value_shape', () => {
    const objectEntries = Object.entries(schema).filter(
      ([k, e]) => k !== '_meta' && (e.type === 'object' || e.type === 'map<string,object>'),
    );
    assert.equal(objectEntries.length, 15, 'expected exactly 15 object-shaped entries as of M3.1/M3.5');
    for (const [key, entry] of objectEntries) {
      assert.ok(entry.value_shape, `${key} is missing value_shape`);
    }
  });

  test('a no-op for entries with no value_shape (the other ~114 scalar/array entries)', () => {
    assert.doesNotThrow(() => validateValueShape('ai.free_daily_limit', schema['ai.free_daily_limit'], 2));
  });

  describe('fixed_object — moderation.*_rate_limit (all 10 share one shape)', () => {
    const entry = schema['moderation.post_rate_limit'];

    test('accepts the real default shape', () => {
      assert.doesNotThrow(() => validateValueShape('moderation.post_rate_limit', entry, entry.default));
    });

    test('rejects a string where an int is expected (windowMs)', () => {
      assert.throws(
        () => validateValueShape('moderation.post_rate_limit', entry, { windowMs: '600000', max: 20, lockMs: 900000 }),
        /windowMs: expected an integer/,
      );
    });

    test('rejects a missing required field', () => {
      assert.throws(
        () => validateValueShape('moderation.post_rate_limit', entry, { windowMs: 600000, lockMs: 900000 }),
        /max: required field is missing/,
      );
    });

    test('rejects an extra/typo\'d field even when every real required field is also present', () => {
      // A missing-required check runs before the extra-key check (report
      // the more fundamental problem first) -- so this fixture keeps the
      // real `lockMs` AND adds a typo'd extra `lockMS`, rather than
      // renaming it, to isolate the extra-key path specifically.
      assert.throws(
        () => validateValueShape('moderation.post_rate_limit', entry, { windowMs: 600000, max: 20, lockMs: 900000, lockMS: 900000 }),
        /unexpected field "lockMS"/,
      );
    });

    test('rejects max: 0 (below the >=1 floor -- would disable the rate limit)', () => {
      assert.throws(
        () => validateValueShape('moderation.post_rate_limit', entry, { windowMs: 600000, max: 0, lockMs: 900000 }),
        /max: below minimum 1/,
      );
    });

    test('every one of the 10 rate_limit entries shares the identical value_shape', () => {
      const keys = [
        'moderation.report_rate_limit', 'moderation.action_rate_limit', 'moderation.appeal_rate_limit',
        'moderation.post_rate_limit', 'moderation.comment_rate_limit', 'moderation.message_rate_limit',
        'moderation.group_create_rate_limit', 'moderation.follow_rate_limit', 'moderation.reaction_rate_limit',
        'moderation.checkin_rate_limit',
      ];
      for (const key of keys) {
        assert.doesNotThrow(() => validateValueShape(key, schema[key], schema[key].default), key);
      }
    });
  });

  describe('fixed_object — cost.pricing', () => {
    test('accepts the real default', () => {
      const entry = schema['cost.pricing'];
      assert.doesNotThrow(() => validateValueShape('cost.pricing', entry, entry.default));
    });

    test('rejects storeCutFraction above 1 (it is a fraction, not a percent)', () => {
      const entry = schema['cost.pricing'];
      const bad = { ...entry.default, storeCutFraction: 15 };
      assert.throws(() => validateValueShape('cost.pricing', entry, bad), /storeCutFraction: above maximum 1/);
    });
  });

  describe('map_of_fixed_object — ai.model_pricing (arbitrary model-name keys, fixed per-value shape)', () => {
    const entry = schema['ai.model_pricing'];

    test('accepts the real default (multiple arbitrary model-name keys)', () => {
      assert.doesNotThrow(() => validateValueShape('ai.model_pricing', entry, entry.default));
    });

    test('rejects a negative price', () => {
      assert.throws(
        () => validateValueShape('ai.model_pricing', entry, { 'some/model': { in: -0.1, out: 0.4 } }),
        /some\/model\.in: below minimum 0/,
      );
    });

    test('rejects a non-object value under an arbitrary key', () => {
      assert.throws(
        () => validateValueShape('ai.model_pricing', entry, { 'some/model': 'free' }),
        /some\/model: expected an object/,
      );
    });
  });

  describe('map_of_fixed_object — purchases.products (the plan\'s own motivating example)', () => {
    const entry = schema['purchases.products'];

    test('accepts the real default (mixed subscription/consumable shapes)', () => {
      assert.doesNotThrow(() => validateValueShape('purchases.products', entry, entry.default));
    });

    test('rejects days as a string -- the exact drift this was built to catch ({days: "31"} instead of 31)', () => {
      assert.throws(
        () => validateValueShape('purchases.products', entry, {
          'com.cookrange.premium.monthly': { kind: 'subscription', tier: 'premium', days: '31' },
        }),
        /days: expected an integer/,
      );
    });

    test('rejects an unknown "kind"', () => {
      assert.throws(
        () => validateValueShape('purchases.products', entry, {
          'x': { kind: 'giftcard' },
        }),
        /kind: expected one of/,
      );
    });
  });

  describe('map_of_fixed_object — gamification.xp_table (dailyCap is nullable)', () => {
    const entry = schema['gamification.xp_table'];

    test('accepts the real default, including a null dailyCap (template_accepted)', () => {
      assert.doesNotThrow(() => validateValueShape('gamification.xp_table', entry, entry.default));
    });

    test('rejects a negative points value', () => {
      assert.throws(
        () => validateValueShape('gamification.xp_table', entry, { meal_logged: { points: -5, dailyCap: 4 } }),
        /points: below minimum 0/,
      );
    });
  });

  describe('map_of_fixed_object — engagement.credit_table (per-key optional fields genuinely vary)', () => {
    test('accepts the real default, including weekly_group_top3\'s weeklyCap-instead-of-dailyCap shape', () => {
      const entry = schema['engagement.credit_table'];
      assert.doesNotThrow(() => validateValueShape('engagement.credit_table', entry, entry.default));
    });
  });
});
