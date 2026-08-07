'use strict';

// Faz 3+4 — unit tests for the pure chat fan-out decision logic
// (`chat_fanout_logic.js`). No emulator, no firebase-admin:
//
//   node --test functions/test/chat_fanout_logic.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const logic = require('../chat_fanout_logic');

describe('chunk', () => {
  test('splits evenly', () => {
    assert.deepEqual(logic.chunk([1, 2, 3, 4], 2), [[1, 2], [3, 4]]);
  });

  test('handles a remainder', () => {
    assert.deepEqual(logic.chunk([1, 2, 3], 2), [[1, 2], [3]]);
  });

  test('empty array yields no chunks', () => {
    assert.deepEqual(logic.chunk([], 5), []);
  });

  test('chunk size larger than array yields one chunk', () => {
    assert.deepEqual(logic.chunk([1, 2], 10), [[1, 2]]);
  });
});

describe('fanoutTier', () => {
  test('at or below the threshold is per_user', () => {
    assert.equal(logic.fanoutTier(1), 'per_user');
    assert.equal(logic.fanoutTier(200), 'per_user');
  });

  test('above the threshold is cursor', () => {
    assert.equal(logic.fanoutTier(201), 'cursor');
    assert.equal(logic.fanoutTier(5000), 'cursor');
  });

  test('a custom threshold is respected', () => {
    assert.equal(logic.fanoutTier(50, 10), 'cursor');
    assert.equal(logic.fanoutTier(5, 10), 'per_user');
  });
});

describe('isEventStale', () => {
  test('a recent event is not stale', () => {
    const now = Date.parse('2026-01-01T00:10:00.000Z');
    assert.equal(logic.isEventStale('2026-01-01T00:09:30.000Z', now), false);
  });

  test('an event older than the max age is stale', () => {
    const now = Date.parse('2026-01-01T00:20:00.000Z');
    assert.equal(logic.isEventStale('2026-01-01T00:00:00.000Z', now), true);
  });

  test('exactly at the boundary is not yet stale', () => {
    const now = Date.parse('2026-01-01T00:10:00.000Z');
    assert.equal(
      logic.isEventStale('2026-01-01T00:00:00.000Z', now, 10 * 60 * 1000),
      false,
    );
  });

  test('an unparsable timestamp is treated as not stale (fail open on the '
      + 'parse, not the delivery)', () => {
    const now = Date.now();
    assert.equal(logic.isEventStale('not-a-timestamp', now), false);
  });
});

describe('previewTextFor', () => {
  test('image type gets the camera-emoji preview regardless of body', () => {
    assert.equal(logic.previewTextFor({ type: 'image', body: 'ignored' }), '📷 Photo');
  });

  test('voice type gets the mic-emoji preview', () => {
    assert.equal(logic.previewTextFor({ type: 'voice' }), '🎤 Voice message');
  });

  test('plan_offer type gets its own preview', () => {
    assert.equal(logic.previewTextFor({ type: 'plan_offer' }), '📋 Plan offer');
  });

  test('text type uses the body, truncated', () => {
    const long = 'x'.repeat(200);
    const result = logic.previewTextFor({ type: 'text', body: long });
    assert.equal(result.length, logic.PREVIEW_MAX_CHARS);
  });

  test('a legacy doc with `text` instead of `body` still works', () => {
    assert.equal(logic.previewTextFor({ type: 'text', text: 'hi' }), 'hi');
  });

  test('system type uses body verbatim (already localized client text), '
      + 'truncated the same as text', () => {
    assert.equal(
      logic.previewTextFor({ type: 'system', body: 'Ayşe joined the group' }),
      'Ayşe joined the group',
    );
  });
});

describe('buildLastMessagePreview', () => {
  test('assembles sender + kind + text', () => {
    const preview = logic.buildLastMessagePreview({
      senderId: 'u1',
      senderName: 'Ayşe',
      msg: { type: 'text', body: 'merhaba' },
    });
    assert.deepEqual(preview, {
      sender_id: 'u1',
      sender_name: 'Ayşe',
      kind: 'text',
      text: 'merhaba',
    });
  });

  test('defaults kind to text when the message has no type', () => {
    const preview = logic.buildLastMessagePreview({
      senderId: 'u1',
      senderName: 'Ayşe',
      msg: { body: 'hi' },
    });
    assert.equal(preview.kind, 'text');
  });
});
