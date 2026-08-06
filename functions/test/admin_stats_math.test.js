'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { DAY_MS, yesterdayUtcRange, averageResolutionMinutes, reportRate } = require('../admin_stats_math');

describe('yesterdayUtcRange', () => {
  test('start is exactly 24h before end, both at UTC midnight', () => {
    const now = new Date('2026-08-06T14:32:00Z');
    const { start, end } = yesterdayUtcRange(now);
    assert.equal(end.getTime() - start.getTime(), DAY_MS);
    assert.equal(end.toISOString(), '2026-08-06T00:00:00.000Z');
    assert.equal(start.toISOString(), '2026-08-05T00:00:00.000Z');
  });

  test('dayKey matches the start (yesterday), not `now`', () => {
    const now = new Date('2026-08-06T14:32:00Z');
    assert.equal(yesterdayUtcRange(now).dayKey, '2026-08-05');
  });

  test('a `now` right at UTC midnight still rolls back a full day, not zero', () => {
    const now = new Date('2026-08-06T00:00:00.000Z');
    const { dayKey, start, end } = yesterdayUtcRange(now);
    assert.equal(dayKey, '2026-08-05');
    assert.equal(end.toISOString(), '2026-08-06T00:00:00.000Z');
    assert.equal(start.toISOString(), '2026-08-05T00:00:00.000Z');
  });

  test('correctly rolls back across a month/year boundary', () => {
    const now = new Date('2026-01-01T09:00:00Z');
    assert.equal(yesterdayUtcRange(now).dayKey, '2025-12-31');
  });
});

describe('averageResolutionMinutes', () => {
  test('empty input -> null, not 0 or NaN', () => {
    assert.equal(averageResolutionMinutes([]), null);
  });

  test('a single pair 30 minutes apart -> 30', () => {
    const createdAt = new Date('2026-08-05T10:00:00Z');
    const resolvedAt = new Date('2026-08-05T10:30:00Z');
    assert.equal(averageResolutionMinutes([{ createdAt, resolvedAt }]), 30);
  });

  test('averages across multiple pairs', () => {
    const base = new Date('2026-08-05T10:00:00Z').getTime();
    const pairs = [
      { createdAt: new Date(base), resolvedAt: new Date(base + 10 * 60000) },
      { createdAt: new Date(base), resolvedAt: new Date(base + 20 * 60000) },
    ];
    assert.equal(averageResolutionMinutes(pairs), 15);
  });

  test('entries missing either timestamp are skipped, not treated as 0', () => {
    const base = new Date('2026-08-05T10:00:00Z').getTime();
    const pairs = [
      { createdAt: new Date(base), resolvedAt: new Date(base + 10 * 60000) },
      { createdAt: null, resolvedAt: new Date(base) },
      { createdAt: new Date(base), resolvedAt: null },
    ];
    assert.equal(averageResolutionMinutes(pairs), 10);
  });

  test('all entries missing a timestamp -> null', () => {
    assert.equal(averageResolutionMinutes([{ createdAt: null, resolvedAt: null }]), null);
  });
});

describe('reportRate', () => {
  test('zero content volume -> 0, not NaN/Infinity', () => {
    assert.equal(reportRate(5, 0), 0);
  });

  test('normal division', () => {
    assert.equal(reportRate(3, 30), 0.1);
  });

  test('zero reports with real content volume -> 0', () => {
    assert.equal(reportRate(0, 100), 0);
  });
});
