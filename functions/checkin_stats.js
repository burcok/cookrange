'use strict';

// Pure, Firebase-independent check-in statistics math — no Firestore, no
// Admin SDK, no `Date.now()` read internally (the caller passes `nowMs`, so
// this stays directly testable with a fixed clock). Split out of
// summaries.js specifically so it is unit-testable without an emulator —
// same discipline as engagement_credit_logic.js:
//
//   node --test functions/test/checkin_stats.test.js
//
// Shared by two call sites that must never independently re-derive this
// math (a THIRD hand-copy, after summaries.js's Node version and
// gym_analytics_service.dart's now-removed Dart version, would recreate the
// exact hand-sync problem DECISIONS.md ADR-023's config-migration work
// exists to end):
//   - summaries.js's aggregateGymFields — a per-member, tier-gated progress
//     summary for the requesting gym owner/coach (generateMemberProgressSummary)
//   - summaries.js's getGymSharingAggregate — a cross-member, k-anonymity-
//     gated aggregate for the gym-wide analytics dashboard (fixes the
//     client-side-only k-anonymity gate: see that function's own doc
//     comment for the full story)

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * @param {number[]} timestampsMs Check-in timestamps (ms since epoch), any
 *   order, any window — the caller already decided how far back to fetch.
 * @param {number} nowMs Reference "now," passed in rather than read via
 *   `Date.now()` internally.
 * @returns {{checkInFrequencyPerWeek: number, currentStreakWeeks: number}}
 */
function computeCheckInFrequencyAndStreak(timestampsMs, nowMs) {
  const last30d = timestampsMs.filter((t) => nowMs - t <= 30 * DAY_MS);
  const checkInFrequencyPerWeek = Math.round((last30d.length / 30) * 7 * 10) / 10;

  // Consecutive-week streak, walking backward from the current week while
  // every week has >=1 checkin. 8-week cap — a reasonable ceiling for a
  // "current streak" figure; callers bound their own fetch accordingly
  // (both existing call sites cap at 60 rows, well over 8 weeks' worth for
  // any realistic check-in cadence).
  let streakWeeks = 0;
  for (let w = 0; w < 8; w++) {
    const weekStart = nowMs - (w + 1) * 7 * DAY_MS;
    const weekEnd = nowMs - w * 7 * DAY_MS;
    const hasVisit = timestampsMs.some((t) => t > weekStart && t <= weekEnd);
    if (!hasVisit) break;
    streakWeeks++;
  }

  return { checkInFrequencyPerWeek, currentStreakWeeks: streakWeeks };
}

module.exports = { computeCheckInFrequencyAndStreak, DAY_MS };
