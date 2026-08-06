'use strict';

// Faz A §A3 — shared vector table, asserted here AND in
// test/stable_hash_test.dart against the SAME expected outputs. See that
// file's header comment for the full rationale; the short version: a
// Cloud Function must reproduce the exact rollout bucket a client
// computed for AppConfigService.isInRollout, which String.hashCode could
// not guarantee. This pair of tests is what proves the two independent
// implementations (Dart, Node) actually agree.
//
//   node --test functions/test/stable_hash.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { fnv1a32 } = require('../stable_hash');

const vectors = {
  '': 2166136261,
  a: 3826002220,
  foobar: 3214735720,
  'gym:abc123': 2999454414,
  'coach:xyz789': 1718838574,
  'squad:uid_0001': 3313215373,
  'programs:': 1538371286,
  ':uid': 1822523445,
  'gym_invite_codes:9f8e7d6c5b4a3210': 3511076557,
  [('a').repeat(100)]: 168538585,
  'Türkçe karakterler: çğıöşü': 3039875672,
  0: 890022063,
  '00': 569209421,
  'meal_plan_templates:uidWithMixedCASE123': 820354505,
  'gym_attribution:uid-with-dashes-999': 152514592,
};

describe('fnv1a32 — shared vector table (cross-checked against test/stable_hash_test.dart)', () => {
  for (const [input, expected] of Object.entries(vectors)) {
    const label = input.length > 24 ? `${input.slice(0, 24)}…` : input;
    test(`"${label}" (len ${input.length}) -> ${expected}`, () => {
      assert.equal(fnv1a32(input), expected);
    });
  }
});

describe('fnv1a32 — properties', () => {
  test('always returns a value in the unsigned 32-bit range', () => {
    for (const input of Object.keys(vectors)) {
      const h = fnv1a32(input);
      assert.ok(h >= 0);
      assert.ok(h <= 0xFFFFFFFF);
    }
  });

  test('is deterministic across repeated calls', () => {
    const input = 'gym:repeat-me';
    const first = fnv1a32(input);
    for (let i = 0; i < 5; i++) {
      assert.equal(fnv1a32(input), first);
    }
  });

  test('different inputs produce different hashes (no trivial collision among these vectors)', () => {
    const hashes = new Set(Object.values(vectors));
    assert.equal(hashes.size, Object.keys(vectors).length);
  });
});
