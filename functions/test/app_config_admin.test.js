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
  setNestedValue, getNestedValue, crossFieldInvariantErrors, schemaEntriesForDoc,
} = require('../app_config_admin');

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
    const schema = require('../config_schema.json');
    const allKeys = Object.keys(schema).filter((k) => k !== '_meta');
    const covered = new Set([
      ...schemaEntriesForDoc('critical').keys(),
      ...schemaEntriesForDoc('client').keys(),
      ...schemaEntriesForDoc('server').keys(),
    ]);
    assert.equal(covered.size, allKeys.length);
  });
});
