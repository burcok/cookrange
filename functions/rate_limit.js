'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 2 §2.6 — shared sliding-window rate-limit helper.
//
// Mirrors index.js's `enforceRateLimitAndQuota` transaction shape
// (RATE_WINDOW_MS/RATE_MAX_IN_WINDOW, a per-uid Firestore doc storing a
// window-start Timestamp + a count, reset when the window has expired)
// rather than inventing a second mechanism — generalized here so the three
// Faz 2 §2.6 callers (reports, group moderation actions, moderation appeals;
// see functions/moderation.js) don't each duplicate the transaction. Lives in
// its own module instead of being copy-pasted per caller.
//
// Ledger: `rate_limits/{uid}` — fully server-only (firestore.rules denies
// every client read/write on this collection unconditionally). Field
// naming is `{kind}_window_start` / `{kind}_count` / `{kind}_locked_until`,
// e.g. kind='report' -> report_window_start/report_count/report_locked_until.
// The `_locked_until` field is what firestore.rules' isReportRateLimited()/
// isModerationRateLimited()/isAppealRateLimited() actually check before
// allowing a client write to the corresponding collection — this module sets
// it, never clears it early (it simply expires on its own once request.time
// passes it).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Atomically checks + bumps a per-uid sliding-window counter. Returns
 * `{ limited: bool, count }`. Has no opinion on CONSEQUENCES (undo, lock,
 * log) — callers decide, since reports/moderation actions/appeals each
 * react differently to being over-limit.
 */
async function checkAndBumpSlidingWindow(db, uid, kind, windowMs, maxInWindow) {
  const ref = db.collection('rate_limits').doc(uid);
  const startField = `${kind}_window_start`;
  const countField = `${kind}_count`;
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? (snap.data() || {}) : {};

    const winStart = data[startField] && data[startField].toDate
      ? data[startField].toDate().getTime()
      : null;
    const windowExpired = !winStart || (now - winStart) > windowMs;
    const count = windowExpired ? 0 : (data[countField] || 0);
    const nextCount = count + 1;

    const update = { [countField]: nextCount };
    if (windowExpired) {
      update[startField] = admin.firestore.Timestamp.fromMillis(now);
    }
    tx.set(ref, update, { merge: true });

    return { limited: nextCount > maxInWindow, count: nextCount };
  });
}

/**
 * Stamps `{kind}_locked_until` = now + lockMs on `rate_limits/{uid}` — the
 * field firestore.rules checks to deny further client writes of that kind
 * until it passes. Merge-only write; never touches the sliding-window
 * counter fields for OTHER kinds on the same doc.
 */
async function lockUntil(db, uid, kind, lockMs) {
  const ref = db.collection('rate_limits').doc(uid);
  await ref.set({
    [`${kind}_locked_until`]: admin.firestore.Timestamp.fromMillis(Date.now() + lockMs),
  }, { merge: true });

  // M5.1 (admin_stats rollup) — a day-bucket increment mirroring index.js's
  // recordUsage/ai_usage_stats pattern. Nothing before this wrote ANY
  // Firestore-visible signal that a rate limit was actually TRIGGERED
  // (_locked_until only stores a future expiry, not a "this happened"
  // event) — one shared edit point here covers every caller (gym.js's
  // checkin limit, moderation.js's report/moderation/appeal limits)
  // instead of four separate call-site edits. Best-effort: never let a
  // stats write fail the rate-limit enforcement it's reporting on.
  const dayKey = new Date().toISOString().slice(0, 10);
  await db
    .collection('admin_stats')
    .doc(`day_${dayKey}`)
    .set(
      {
        day: dayKey,
        moderation: {
          rate_limit_triggers: admin.firestore.FieldValue.increment(1),
          [`rate_limit_triggers_by_kind.${kind}`]: admin.firestore.FieldValue.increment(1),
        },
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    )
    .catch((e) => functions.logger.error('lockUntil: admin_stats increment failed', { uid, kind, error: e.message }));
}

module.exports = { checkAndBumpSlidingWindow, lockUntil };
