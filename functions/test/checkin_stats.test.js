'use strict';

// Unit tests for the pure, Firebase-independent check-in math
// (checkin_stats.js). No emulator, no firebase-admin:
//
//   node --test functions/test/checkin_stats.test.js
//
// This math is shared by aggregateGymFields (an existing, already-shipped
// per-member progress summary) and getGymSharingAggregate (new — the fix
// for the client-side-only gym k-anonymity gate). Both callables read
// their own live check-in data and pass it through
// computeCheckInFrequencyAndStreak; this file tests that function directly
// with fixed, hand-picked timestamps rather than real Firestore data.

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { computeCheckInFrequencyAndStreak, DAY_MS } = require('../checkin_stats');

const WEEK_MS = 7 * DAY_MS;

describe('computeCheckInFrequencyAndStreak — frequency', () => {
  test('no check-ins at all -> 0 frequency, 0 streak', () => {
    const now = Date.now();
    const result = computeCheckInFrequencyAndStreak([], now);
    assert.equal(result.checkInFrequencyPerWeek, 0);
    assert.equal(result.currentStreakWeeks, 0);
  });

  test('exactly one check-in in the last 30 days -> 0.2/week', () => {
    const now = Date.now();
    const oneCheckin = [now - 5 * DAY_MS];
    const result = computeCheckInFrequencyAndStreak(oneCheckin, now);
    // (1/30)*7 = 0.2333... -> rounds to one decimal -> 0.2
    assert.equal(result.checkInFrequencyPerWeek, 0.2);
  });

  test('a check-in every day for 30 days -> 7.0/week', () => {
    const now = Date.now();
    const daily = Array.from({ length: 30 }, (_, i) => now - i * DAY_MS);
    const result = computeCheckInFrequencyAndStreak(daily, now);
    assert.equal(result.checkInFrequencyPerWeek, 7);
  });

  test('check-ins older than 30 days do not count toward frequency', () => {
    const now = Date.now();
    const stale = [now - 45 * DAY_MS, now - 60 * DAY_MS];
    const result = computeCheckInFrequencyAndStreak(stale, now);
    assert.equal(result.checkInFrequencyPerWeek, 0);
  });
});

describe('computeCheckInFrequencyAndStreak — streak', () => {
  test('a visit in each of the last 8 weeks -> streak of 8', () => {
    const now = Date.now();
    // One visit comfortably inside each of the 8 trailing week windows.
    const timestamps = Array.from({ length: 8 }, (_, w) => now - w * WEEK_MS - DAY_MS);
    const result = computeCheckInFrequencyAndStreak(timestamps, now);
    assert.equal(result.currentStreakWeeks, 8);
  });

  test('visits for 3 consecutive weeks then a gap -> streak stops at 3', () => {
    const now = Date.now();
    // Weeks 0, 1, 2 (from now) have a visit; week 3 does not; weeks 4-7 do
    // (irrelevant — the walk must stop at the first miss).
    const timestamps = [
      now - 0 * WEEK_MS - DAY_MS,
      now - 1 * WEEK_MS - DAY_MS,
      now - 2 * WEEK_MS - DAY_MS,
      // week 3 deliberately empty
      now - 4 * WEEK_MS - DAY_MS,
      now - 5 * WEEK_MS - DAY_MS,
    ];
    const result = computeCheckInFrequencyAndStreak(timestamps, now);
    assert.equal(result.currentStreakWeeks, 3);
  });

  test('no visit in the current week -> streak is 0 even with older visits', () => {
    const now = Date.now();
    const timestamps = [now - 2 * WEEK_MS - DAY_MS, now - 3 * WEEK_MS - DAY_MS];
    const result = computeCheckInFrequencyAndStreak(timestamps, now);
    assert.equal(result.currentStreakWeeks, 0);
  });

  test('week boundary is (weekStart, weekEnd] — exclusive start, inclusive end', () => {
    const now = Date.now();
    // A visit exactly AT this week's start boundary must NOT count as
    // being in "this week" (it belongs to the week before).
    const atStart = [now - 1 * WEEK_MS];
    assert.equal(computeCheckInFrequencyAndStreak(atStart, now).currentStreakWeeks, 0);

    // A visit exactly AT this week's end boundary (i.e. "now" itself) DOES
    // count.
    const atEnd = [now];
    assert.equal(computeCheckInFrequencyAndStreak(atEnd, now).currentStreakWeeks, 1);
  });

  test('streak never exceeds the 8-week search cap', () => {
    const now = Date.now();
    const timestamps = Array.from({ length: 20 }, (_, w) => now - w * WEEK_MS - DAY_MS);
    const result = computeCheckInFrequencyAndStreak(timestamps, now);
    assert.equal(result.currentStreakWeeks, 8);
  });
});
