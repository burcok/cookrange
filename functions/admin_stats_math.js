'use strict';

// Pure, Firebase-independent math for the admin_stats rollup
// (admin_stats.js) -- no firebase-admin, same convention as
// checkin_stats.js:
//
//   node --test functions/test/admin_stats_math.test.js

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * The [start, end) UTC range for "yesterday" relative to `now`, plus its
 * `day_YYYY-MM-DD` key. The rollup deliberately finalizes the PREVIOUS
 * complete day rather than a still-accumulating "today" -- ai_usage_stats'
 * day_X docs are genuinely live/incremental all day (every AI request
 * bumps them in real time), but most of admin_stats' domains have no
 * per-event write hook to accumulate through the day; computing them via
 * range-filtered aggregation queries only gives a stable, correct number
 * once the day has fully closed.
 */
function yesterdayUtcRange(now) {
  const end = new Date(now);
  end.setUTCHours(0, 0, 0, 0); // today's midnight UTC
  const start = new Date(end.getTime() - DAY_MS); // yesterday's midnight UTC
  const dayKey = start.toISOString().slice(0, 10);
  return { start, end, dayKey };
}

/**
 * Average of (resolvedAt - createdAt) in whole minutes across a list of
 * {createdAt, resolvedAt} Date pairs. Entries missing either timestamp are
 * skipped rather than treated as zero (a zero would silently understate
 * the real average). Returns null for an empty/all-skipped input rather
 * than 0 -- "no data" and "resolved instantly" must stay distinguishable
 * on a dashboard.
 */
function averageResolutionMinutes(pairs) {
  const minutes = [];
  for (const { createdAt, resolvedAt } of pairs) {
    if (createdAt instanceof Date && resolvedAt instanceof Date) {
      minutes.push((resolvedAt.getTime() - createdAt.getTime()) / 60000);
    }
  }
  if (minutes.length === 0) return null;
  return minutes.reduce((a, b) => a + b, 0) / minutes.length;
}

/** reportsFiled / contentVolume, or 0 (not NaN/Infinity) when there was no content at all that day. */
function reportRate(reportsFiled, contentVolume) {
  return contentVolume > 0 ? reportsFiled / contentVolume : 0;
}

module.exports = { DAY_MS, yesterdayUtcRange, averageResolutionMinutes, reportRate };
