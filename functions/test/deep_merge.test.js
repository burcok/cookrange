'use strict';

// Mirrors test/deep_merge_test.dart exactly — see that file's header for
// the full rationale (a real design flaw caught before shipping: three
// schema groups are split across more than one app_config/* document, so
// a shallow {...a, ...b} spread would silently discard sibling sub-fields).
//
//   node --test functions/test/deep_merge.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { deepMerge } = require('../deep_merge');

describe('deepMerge', () => {
  test('a later, PARTIAL nested object only overrides its own keys — the exact bug this exists to prevent', () => {
    const earlier = { ai: { text_model: 'gpt-4o-mini', timeout_s: 90 } };
    const later = { ai: { model_by_type: {}, max_tokens: 8192 } };
    const merged = deepMerge([earlier, later]);
    assert.deepEqual(merged.ai, {
      text_model: 'gpt-4o-mini',
      timeout_s: 90,
      model_by_type: {},
      max_tokens: 8192,
    });
  });

  test("a later source's LEAF value overrides an earlier one for the SAME key", () => {
    const earlier = { maintenance: { enabled: false } };
    const later = { maintenance: { enabled: true } };
    const merged = deepMerge([earlier, later]);
    assert.deepEqual(merged.maintenance, { enabled: true });
  });

  test('a group entirely ABSENT from a later source is preserved from an earlier one', () => {
    const global = {
      ai: { text_model: 'x' },
      maintenance: { enabled: false },
      version: { force_update: false },
    };
    const merged = deepMerge([global, {}, {}]);
    assert.deepEqual(merged, global);
  });

  test('three-way merge — global < client < server, matching app_config.js\'s actual precedence order', () => {
    const global = {
      ai: { text_model: 'old-model', timeout_s: 60 },
      features: { gym: true },
    };
    const client = { ai: { text_model: 'new-model' } };
    const server = {
      features: { gym: false },
      maintenance: { enabled: true },
    };
    const merged = deepMerge([global, client, server]);
    assert.deepEqual(merged.ai, { text_model: 'new-model', timeout_s: 60 });
    assert.deepEqual(merged.features, { gym: false });
    assert.deepEqual(merged.maintenance, { enabled: true });
  });

  test('non-object values (arrays) are REPLACED wholesale, never merged element-wise', () => {
    const earlier = { ai: { allowed_models: ['a', 'b'] } };
    const later = { ai: { allowed_models: ['c'] } };
    const merged = deepMerge([earlier, later]);
    assert.deepEqual(merged.ai.allowed_models, ['c']);
  });

  test('a later scalar replaces an earlier nested object wholesale', () => {
    const earlier = { ai: { text_model: 'x' } };
    const later = { ai: 'not-an-object-anymore' };
    const merged = deepMerge([earlier, later]);
    assert.equal(merged.ai, 'not-an-object-anymore');
  });

  test('empty input array returns an empty object', () => {
    assert.deepEqual(deepMerge([]), {});
  });

  test('a single object is returned equivalent to itself', () => {
    const only = { a: { b: 1 } };
    assert.deepEqual(deepMerge([only]), only);
  });

  test('non-object entries in the input array (null/undefined) are skipped, not thrown on', () => {
    const merged = deepMerge([{ a: 1 }, null, undefined, { b: 2 }]);
    assert.deepEqual(merged, { a: 1, b: 2 });
  });
});
