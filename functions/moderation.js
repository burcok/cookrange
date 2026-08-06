'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 2 §2.6 — automated moderation: abuse-rate throttling for reports,
// group moderation actions (kick/ban/mute/unmute/unban), and moderation
// appeals.
//
// DESIGN — reactive trigger + rules-checked lock, not a write-gating
// callable: reports/moderation-log/moderation_appeals all stay CLIENT-DIRECT
// writes, mirroring this codebase's `privacy_requests` precedent (a client
// creates its own record; an admin/moderator reviews it later — nothing
// here grants ban state or spends money, unlike the entitlements/AI-credit/
// follow-request paths that DO warrant a full callable under ADR-008).
// CommunityGroupService's kickMember/banMember/muteMember/unmuteMember stay
// exactly as built (Faz 2 §2.3) — Faz 2 §2.6 wires UI onto them, it does not
// re-architect their write path; that would be a materially larger, separate
// change than "add a rate limit."
//
// Each trigger below fires shortly after the write it watches (typical
// Firestore trigger latency — often under a couple of seconds, but not
// instant) and bumps the same sliding-window shape as index.js's
// `enforceRateLimitAndQuota` (functions/rate_limit.js). Once a uid crosses
// the threshold, it is locked out of FURTHER writes of that kind via a
// firestore.rules-checked `{kind}_locked_until` timestamp on
// `rate_limits/{uid}` — fully server-only; a client can never clear its own
// lock.
//
// HONEST LIMITATION: because enforcement is reactive, a burst can still
// land up to (maxInWindow + however many arrive before the trigger catches
// up) writes before the lock actually engages. This bounds and blunts abuse
// — it turns "unlimited mass-ban" into "a few dozen actions, then hard-
// stopped, all of it sitting in the immutable moderation/reports log for
// cleanup and audit" — it does not guarantee zero-over-limit the way a
// pre-write-gating callable would. Document this precisely rather than
// overclaiming perfect prevention.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { checkAndBumpSlidingWindow, lockUntil } = require('./rate_limit');
const { getConfig } = require('./app_config');

// Faz A Faz 4 — FALLBACK defaults; app_config/server's `moderation.*_rate_limit`
// objects are the live source once seeded (see moderationConfig() below).
// These are anti-abuse thresholds — deliberately server-only in the config
// split (DECISIONS.md ADR-023): publishing them to any authenticated reader
// would be a printed manual for staying just under every rate limit in the
// product.
//
// Reports: generous enough for a legitimate user flagging several bad posts
// in a row, tight enough to blunt a mass-report brigade trying to silence
// someone via volume.
const REPORT_RATE_WINDOW_MS_DEFAULT = 10 * 60 * 1000; // 10 minutes
const REPORT_RATE_MAX_IN_WINDOW_DEFAULT = 8;
const REPORT_LOCK_MS_DEFAULT = 15 * 60 * 1000;

// Group moderation actions: generous enough for a real moderator clearing
// out a raid in one sitting, tight enough to cap a compromised owner/admin
// account's blast radius.
const MOD_RATE_WINDOW_MS_DEFAULT = 10 * 60 * 1000; // 10 minutes
const MOD_RATE_MAX_IN_WINDOW_DEFAULT = 15;
const MOD_LOCK_MS_DEFAULT = 15 * 60 * 1000;

// Appeals: one per moderation action already (doc id == the action's own
// id, firestore.rules), so this only guards against filing many appeals
// across many actions in a short burst.
const APPEAL_RATE_WINDOW_MS_DEFAULT = 60 * 60 * 1000; // 1 hour
const APPEAL_RATE_MAX_IN_WINDOW_DEFAULT = 5;
const APPEAL_LOCK_MS_DEFAULT = 60 * 60 * 1000;

/** Live app_config/server `moderation.*` fields, or {} if unset/unreachable. */
async function moderationConfig() {
  const cfg = await getConfig();
  return (cfg && cfg.moderation) || {};
}

function tripleOrDefault(live, windowDefault, maxDefault, lockDefault) {
  const isObj = live && typeof live === 'object';
  return {
    windowMs: isObj && typeof live.windowMs === 'number' ? live.windowMs : windowDefault,
    max: isObj && typeof live.max === 'number' ? live.max : maxDefault,
    lockMs: isObj && typeof live.lockMs === 'number' ? live.lockMs : lockDefault,
  };
}

exports.onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap) => {
    const reporterId = snap.data().reporterId;
    if (!reporterId) return;
    const db = admin.firestore();
    try {
      const { windowMs, max, lockMs } = tripleOrDefault(
        (await moderationConfig()).report_rate_limit,
        REPORT_RATE_WINDOW_MS_DEFAULT, REPORT_RATE_MAX_IN_WINDOW_DEFAULT, REPORT_LOCK_MS_DEFAULT,
      );
      const { limited, count } = await checkAndBumpSlidingWindow(db, reporterId, 'report', windowMs, max);
      if (limited) {
        await lockUntil(db, reporterId, 'report', lockMs);
        functions.logger.warn('onReportCreated: reporter rate-limited', { reporterId, count });
      }
    } catch (e) {
      functions.logger.error('onReportCreated: rate-limit check failed', {
        reporterId, error: e.message,
      });
    }
  });

exports.onGroupModerationActionCreated = functions.firestore
  .document('community_groups/{groupId}/moderation/{actionId}')
  .onCreate(async (snap, context) => {
    const issuedBy = snap.data().issued_by;
    if (!issuedBy) return;
    const db = admin.firestore();
    try {
      const { windowMs, max, lockMs } = tripleOrDefault(
        (await moderationConfig()).action_rate_limit,
        MOD_RATE_WINDOW_MS_DEFAULT, MOD_RATE_MAX_IN_WINDOW_DEFAULT, MOD_LOCK_MS_DEFAULT,
      );
      const { limited, count } = await checkAndBumpSlidingWindow(db, issuedBy, 'moderation', windowMs, max);
      if (limited) {
        await lockUntil(db, issuedBy, 'moderation', lockMs);
        functions.logger.warn('onGroupModerationActionCreated: moderator rate-limited', {
          issuedBy, groupId: context.params.groupId, count,
        });
      }
    } catch (e) {
      functions.logger.error('onGroupModerationActionCreated: rate-limit check failed', {
        issuedBy, error: e.message,
      });
    }
  });

exports.onModerationAppealCreated = functions.firestore
  .document('moderation_appeals/{appealId}')
  .onCreate(async (snap) => {
    const uid = snap.data().uid;
    if (!uid) return;
    const db = admin.firestore();
    try {
      const { windowMs, max, lockMs } = tripleOrDefault(
        (await moderationConfig()).appeal_rate_limit,
        APPEAL_RATE_WINDOW_MS_DEFAULT, APPEAL_RATE_MAX_IN_WINDOW_DEFAULT, APPEAL_LOCK_MS_DEFAULT,
      );
      const { limited, count } = await checkAndBumpSlidingWindow(db, uid, 'appeal', windowMs, max);
      if (limited) {
        await lockUntil(db, uid, 'appeal', lockMs);
        functions.logger.warn('onModerationAppealCreated: appellant rate-limited', { uid, count });
      }
    } catch (e) {
      functions.logger.error('onModerationAppealCreated: rate-limit check failed', {
        uid, error: e.message,
      });
    }
  });

// Faz A (config migration) — export names kept stable for
// functions/test/config_schema_defaults.test.js (Faz 4 renamed the
// INTERNAL constants *_DEFAULT once the live-config read path above was
// wired in; the equality this test proves hasn't changed).
Object.assign(module.exports, {
  REPORT_RATE_WINDOW_MS: REPORT_RATE_WINDOW_MS_DEFAULT,
  REPORT_RATE_MAX_IN_WINDOW: REPORT_RATE_MAX_IN_WINDOW_DEFAULT,
  REPORT_LOCK_MS: REPORT_LOCK_MS_DEFAULT,
  MOD_RATE_WINDOW_MS: MOD_RATE_WINDOW_MS_DEFAULT,
  MOD_RATE_MAX_IN_WINDOW: MOD_RATE_MAX_IN_WINDOW_DEFAULT,
  MOD_LOCK_MS: MOD_LOCK_MS_DEFAULT,
  APPEAL_RATE_WINDOW_MS: APPEAL_RATE_WINDOW_MS_DEFAULT,
  APPEAL_RATE_MAX_IN_WINDOW: APPEAL_RATE_MAX_IN_WINDOW_DEFAULT,
  APPEAL_LOCK_MS: APPEAL_LOCK_MS_DEFAULT,
  moderationConfig,
});
