'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 1 §1.5 — server-authoritative gym-presence (background geofence) events.
//
// The client-side 100m proximity check (GymService, pre-Faz-1) and
// firestore.rules' checkins/create rule (Faz 0 §0.1) only ever confirmed
// `uid`/`timestamp`/`method` shape — neither could confirm a check-in
// actually happened near the gym. Faz 1 §1.4 closed the write path entirely
// (gyms/{gymId}/presence/* and presence_sessions/* are `if false` to every
// client); this file is the ONLY writer of both, and the only place that
// ever turns a presence session into a `method: 'geofence'` check-in.
//
// Event semantics (matches Faz 1 §1.2's client design):
//   'enter'  — raw boundary crossing. iOS has no native dwell concept, so it
//              fires this immediately and starts its own 5-minute local
//              timer; Android is configured for GEOFENCE_TRANSITION_DWELL
//              directly and may never send a separate 'enter' at all. Either
//              way this does NOT open a session — "walking past" must not
//              count — it is acknowledged and logged only.
//   'dwell'  — the loitering confirmation (Android's native DWELL callback,
//              or iOS's own timer firing while still inside). THIS is what
//              opens the session — everything server-side-validated lives
//              here.
//   'exit'   — closes whatever session is open. No-op success if none is
//              (dwell can legitimately never have confirmed).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable, writeNotification, fetchActor } = require('./notifications');
const { awardXp, xpEntry } = require('./progress');
const { getConfig } = require('./app_config');

// Faz A Faz 4 — FALLBACK defaults; app_config/server's `presence.*` fields
// are the live source once seeded (see presenceConfig() below).
//
// A client clock more than this far from server time is rejected outright —
// catches a spoofed or badly-drifted device rather than trusting it.
const TIMESTAMP_SKEW_MS_DEFAULT = 5 * 60 * 1000;
// Same gym, same user: a dwell within this long of their last exit is
// rejected (GPS flicker re-triggering the boundary right after leaving).
const RATE_LIMIT_REENTRY_MS_DEFAULT = 10 * 60 * 1000;
// Absolute safety-net expiry from entered_at — nobody's single gym visit
// legitimately runs longer than this; closeStalePresenceSessions sweeps
// anything that outlives it (app killed, phone died, OS killed background
// execution) so a presence doc can never stay "live" forever.
const PRESENCE_TTL_MS_DEFAULT = 4 * 60 * 60 * 1000;
const STALE_SWEEP_LIMIT_DEFAULT = 200;

/** Live app_config/server `presence.*` fields, or {} if unset/unreachable. */
async function presenceConfig() {
  const cfg = await getConfig();
  return (cfg && cfg.presence) || {};
}

function checkTimestampSkew(clientTimestamp, skewMs) {
  if (clientTimestamp === undefined || clientTimestamp === null) return;
  const t = new Date(clientTimestamp).getTime();
  if (!Number.isFinite(t) || Math.abs(Date.now() - t) > skewMs) {
    throw new functions.https.HttpsError('invalid-argument', 'timestamp_skew');
  }
}

async function hasGymPresenceConsent(db, uid) {
  const snap = await db.collection('users').doc(uid)
    .collection('consents').doc('gym_presence').get();
  return snap.exists && snap.data().granted === true;
}

// Faz 1 §1.4: the per-gym toggle on users/{uid}/private/presence_prefs.
// Enforced here too, not just client-side — granting the broader
// `gymPresence` consent must not itself arm tracking at every gym a member
// belongs to.
async function isGymTrackingEnabledForUser(db, uid, gymId) {
  const snap = await db.collection('users').doc(uid)
    .collection('private').doc('presence_prefs').get();
  if (!snap.exists) return false;
  const map = snap.data().gym_tracking_enabled;
  return !!(map && map[gymId] === true);
}

/**
 * Closes whatever presence doc is open for (uid, gymId), if any: writes the
 * immutable session record, decrements live_occupancy, records a
 * `method: 'geofence'` check-in, and refreshes the member's last_check_in.
 * Returns {ok: true, status: 'closed'|'no_active_session'} — never throws
 * for "nothing to close," since exit/timeout firing with no open session is
 * an expected, not exceptional, outcome.
 */
async function closeSession(db, uid, gymId, endedBy) {
  const gymRef = db.collection('gyms').doc(gymId);
  const memberRef = gymRef.collection('members').doc(uid);
  const presenceRef = gymRef.collection('presence').doc(uid);
  const sessionRef = gymRef.collection('presence_sessions').doc();
  const checkinRef = gymRef.collection('checkins').doc();

  const closed = await db.runTransaction(async (tx) => {
    const [presenceSnap, memberSnap] = await Promise.all([
      tx.get(presenceRef),
      tx.get(memberRef),
    ]);
    if (!presenceSnap.exists) return false;

    const p = presenceSnap.data();
    const enteredAt = p.entered_at && p.entered_at.toDate ? p.entered_at.toDate() : new Date();
    const durationMinutes = Math.max(0, Math.round((Date.now() - enteredAt.getTime()) / 60000));
    const nowTs = admin.firestore.FieldValue.serverTimestamp();

    tx.set(sessionRef, {
      uid,
      entered_at: p.entered_at,
      exited_at: nowTs,
      duration_minutes: durationMinutes,
      source: p.source || 'geofence',
      ended_by: endedBy,
    });
    tx.delete(presenceRef);
    tx.update(gymRef, { live_occupancy: admin.firestore.FieldValue.increment(-1) });
    tx.set(checkinRef, {
      uid,
      timestamp: nowTs,
      method: 'geofence',
      ...(p.display_name ? { display_name: p.display_name } : {}),
      ...(p.photo_url ? { photo_url: p.photo_url } : {}),
    });
    if (memberSnap.exists) {
      tx.update(memberRef, { last_check_in: nowTs });
    }
    return true;
  });

  functions.logger.info('recordPresenceEvent: session closed', { uid, gymId, endedBy, closed });

  if (closed) {
    // Faz 5 §5.1: check_in XP — NEVER client-reported (see progress.js's
    // header comment). This runs right after the checkin doc above was
    // itself server-verified (the whole point of Faz 1 §1.5's geofence
    // hardening), so no additional trust is extended here. A courtesy call:
    // failure never unwinds the already-committed check-in.
    const t = await xpEntry('check_in');
    await awardXp(db, uid, 'check_in', checkinRef.id, t.points, t.dailyCap).catch((e) => {
      functions.logger.error('closeSession: awardXp(check_in) failed', { uid, gymId, error: e.message });
    });
  }

  return { ok: true, status: closed ? 'closed' : 'no_active_session' };
}

exports.recordPresenceEvent = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const gymId = data && typeof data.gymId === 'string' ? data.gymId : '';
  const type = data && typeof data.type === 'string' ? data.type : '';
  if (!gymId || !['enter', 'dwell', 'exit'].includes(type)) {
    throw new functions.https.HttpsError('invalid-argument', 'gymId and a valid type are required');
  }
  // Read once, outside any transaction — config isn't part of this call's
  // transactional state, so there's no reason to re-fetch it on a retry.
  const pCfg = await presenceConfig();
  const skewMs = typeof pCfg.timestamp_skew_ms === 'number' ? pCfg.timestamp_skew_ms : TIMESTAMP_SKEW_MS_DEFAULT;
  const reentryMs = typeof pCfg.rate_limit_reentry_ms === 'number'
    ? pCfg.rate_limit_reentry_ms : RATE_LIMIT_REENTRY_MS_DEFAULT;
  const ttlMs = typeof pCfg.presence_ttl_ms === 'number' ? pCfg.presence_ttl_ms : PRESENCE_TTL_MS_DEFAULT;
  checkTimestampSkew(data && data.clientTimestamp, skewMs);

  const db = admin.firestore();

  if (type === 'enter') {
    functions.logger.info('recordPresenceEvent: enter noted', { uid, gymId });
    return { ok: true, status: 'noted' };
  }

  if (type === 'exit') {
    return closeSession(db, uid, gymId, 'exit');
  }

  // type === 'dwell' — the only event that actually opens a session.
  // 'qr' is exclusively validateGymCheckin's territory, so the only two
  // legitimate sources here are the automatic geofence path and its
  // foreground-fallback tier (Faz 1 §1.2's 4-tier chain).
  const source = data && data.source === 'manual_confirm' ? 'manual_confirm' : 'geofence';
  const gymRef = db.collection('gyms').doc(gymId);
  const memberRef = gymRef.collection('members').doc(uid);
  const presenceRef = gymRef.collection('presence').doc(uid);
  const sessionsRef = gymRef.collection('presence_sessions');
  const userRef = db.collection('users').doc(uid);

  const [
    memberSnap, gymSnap, hasConsent, trackingEnabled,
    existingPresenceSnap, lastSessionSnap, userSnap,
  ] = await Promise.all([
    memberRef.get(),
    gymRef.get(),
    hasGymPresenceConsent(db, uid),
    isGymTrackingEnabledForUser(db, uid, gymId),
    presenceRef.get(),
    sessionsRef.where('uid', '==', uid).orderBy('entered_at', 'desc').limit(1).get(),
    userRef.get(),
  ]);

  if (!memberSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'not_a_member');
  }
  if (!gymSnap.exists || gymSnap.data().geofence_enabled !== true) {
    throw new functions.https.HttpsError('failed-precondition', 'geofence_disabled');
  }
  if (!hasConsent) {
    throw new functions.https.HttpsError('failed-precondition', 'consent_required');
  }
  if (!trackingEnabled) {
    throw new functions.https.HttpsError('failed-precondition', 'tracking_disabled_for_gym');
  }
  if (existingPresenceSnap.exists) {
    // Duplicate dwell (client retry after a flaky response) — already open.
    return { ok: true, status: 'already_active' };
  }
  if (!lastSessionSnap.empty) {
    const last = lastSessionSnap.docs[0].data();
    const lastExit = last.exited_at && last.exited_at.toDate ? last.exited_at.toDate() : null;
    if (lastExit && (Date.now() - lastExit.getTime()) < reentryMs) {
      throw new functions.https.HttpsError('resource-exhausted', 'rate_limited');
    }
  }

  const userData = userSnap.exists ? (userSnap.data() || {}) : {};
  const nowTs = admin.firestore.FieldValue.serverTimestamp();
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + ttlMs);

  await db.runTransaction(async (tx) => {
    // Re-check inside the transaction: a concurrent duplicate dwell could
    // have created the doc between the read above and now.
    const freshSnap = await tx.get(presenceRef);
    if (freshSnap.exists) return;
    tx.set(presenceRef, {
      entered_at: nowTs,
      source,
      last_seen_at: nowTs,
      expires_at: expiresAt,
      display_name: userData.displayName || null,
      photo_url: userData.photoURL || null,
    });
    tx.update(gymRef, { live_occupancy: admin.firestore.FieldValue.increment(1) });
  });

  functions.logger.info('recordPresenceEvent: dwell opened session', { uid, gymId, source });
  return { ok: true, status: 'entered' };
});

/**
 * Every 15 minutes: closes any presence doc whose expires_at has passed
 * without a real exit ever arriving. Deliberately independent of any gym's
 * opening hours (Faz 1.1) so this doesn't depend on that schema landing
 * first, and frequent enough that a stuck "ghost" presence self-heals the
 * same day rather than skewing live_occupancy until a nightly job runs.
 */
exports.closeStalePresenceSessions = functions
  .pubsub
  .schedule('every 15 minutes')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const pCfg = await presenceConfig();
    const sweepLimit = typeof pCfg.stale_sweep_limit === 'number'
      ? pCfg.stale_sweep_limit : STALE_SWEEP_LIMIT_DEFAULT;
    const snap = await db.collectionGroup('presence')
      .where('expires_at', '<=', now)
      .limit(sweepLimit)
      .get();

    if (snap.empty) {
      functions.logger.info('closeStalePresenceSessions: none stale');
      return;
    }

    let closedCount = 0;
    for (const presenceDoc of snap.docs) {
      // Path is gyms/{gymId}/presence/{uid}.
      const gymId = presenceDoc.ref.parent.parent.id;
      const uid = presenceDoc.id;
      try {
        const result = await closeSession(db, uid, gymId, 'timeout');
        if (result.status === 'closed') closedCount++;
      } catch (e) {
        functions.logger.error('closeStalePresenceSessions: failed for one doc', {
          gymId, uid, error: e.message,
        });
      }
    }

    functions.logger.info('closeStalePresenceSessions: done', {
      processed: snap.size, closed: closedCount,
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// Faz 1 §1.7 — "a friend is at the gym" notification.
//
// Fires once per real visit (a presence doc is only ever created by a
// dwell-confirmed 'dwell' event above, never by 'enter'). Fans out to
// whichever of the arriving member's friends are ALSO members of this same
// gym — intersected via one membership existence check per friend rather
// than a `whereIn` (capped at 30 values, and a popular user's friend list
// can exceed that).
// ─────────────────────────────────────────────────────────────────────────────

// Defensive cap on the friends list this fan-out reads, independent of any
// cap (or lack of one) on how many friends a user can actually have —
// mirrors the "no unbounded query" discipline from Faz 0 §0.5.
const MAX_FRIENDS_FANOUT_DEFAULT = 300;
// One notification per (receiver, arriving friend, gym) per calendar day.
const NOTIFY_LOG_TTL_DAYS_DEFAULT = 2;
// Turkey has used a fixed UTC+3 offset with no DST since 2016 — this is the
// app's only real market today, so a fixed offset is accurate, not merely an
// approximation. Revisit if the app expands beyond Türkiye. Shared with (not
// imported from — see progress.js's own comment) progress.js/
// engagement_credit_logic.js; config_schema.json's `gamification.
// local_utc_offset_hours` note documents all three call sites and requires
// they consolidate onto this ONE live value.
const LOCAL_UTC_OFFSET_HOURS_DEFAULT = 3;
const QUIET_HOURS_START_DEFAULT = 7;
const QUIET_HOURS_END_DEFAULT = 23;

/** Live app_config/server `gamification.local_utc_offset_hours`, or the fallback. */
async function liveLocalUtcOffsetHours() {
  const cfg = await getConfig();
  const v = cfg && cfg.gamification && cfg.gamification.local_utc_offset_hours;
  return typeof v === 'number' ? v : LOCAL_UTC_OFFSET_HOURS_DEFAULT;
}

function isWithinNotifyWindow(date, offsetHours, quietStart, quietEnd) {
  const localHour = (date.getUTCHours() + offsetHours) % 24;
  return localHour >= quietStart && localHour < quietEnd;
}

function dayKeyFor(date) {
  // UTC calendar day used as the dedup bucket — a receiver could in theory
  // get 2 notifications for the same friend/gym within a few hours of a UTC
  // midnight boundary instead of a strict rolling 24h window. Acceptable:
  // this is an anti-spam cap, not a security boundary, and it still bounds
  // the worst case to a small, fixed number of extra notifications.
  return date.toISOString().slice(0, 10).replace(/-/g, '');
}

exports.onGymPresenceCreated = functions
  .firestore
  .document('gyms/{gymId}/presence/{uid}')
  .onCreate(async (snap, context) => {
    const { gymId, uid: arrivingUid } = context.params;
    const db = admin.firestore();
    const now = new Date();

    // Read once — none of this is part of any transaction's retry state.
    const [pCfg, offsetHours] = await Promise.all([presenceConfig(), liveLocalUtcOffsetHours()]);
    const quietStart = typeof pCfg.quiet_hours_start === 'number'
      ? pCfg.quiet_hours_start : QUIET_HOURS_START_DEFAULT;
    const quietEnd = typeof pCfg.quiet_hours_end === 'number'
      ? pCfg.quiet_hours_end : QUIET_HOURS_END_DEFAULT;
    const maxFriendsFanout = typeof pCfg.max_friends_fanout === 'number'
      ? pCfg.max_friends_fanout : MAX_FRIENDS_FANOUT_DEFAULT;
    const notifyLogTtlDays = typeof pCfg.notify_log_ttl_days === 'number'
      ? pCfg.notify_log_ttl_days : NOTIFY_LOG_TTL_DAYS_DEFAULT;

    if (!isWithinNotifyWindow(now, offsetHours, quietStart, quietEnd)) {
      functions.logger.info('onGymPresenceCreated: outside notify window, skipping', {
        gymId, arrivingUid,
      });
      return;
    }

    const [arrivingPrefsSnap, gymSnap] = await Promise.all([
      db.collection('users').doc(arrivingUid).collection('private').doc('presence_prefs').get(),
      db.collection('gyms').doc(gymId).get(),
    ]);
    const arrivingPrefs = arrivingPrefsSnap.exists ? arrivingPrefsSnap.data() : {};
    if (arrivingPrefs.notify_friends_enabled !== true) {
      functions.logger.info('onGymPresenceCreated: broadcaster opted out, skipping', {
        gymId, arrivingUid,
      });
      return;
    }
    if (!gymSnap.exists) return;
    const gymName = gymSnap.data().name || '';

    const friendsSnap = await db.collection('users').doc(arrivingUid)
      .collection('friends').limit(maxFriendsFanout).get();
    if (friendsSnap.empty) return;
    if (friendsSnap.size === maxFriendsFanout) {
      functions.logger.warn('onGymPresenceCreated: friends list truncated at cap', {
        arrivingUid, cap: maxFriendsFanout,
      });
    }
    const friendUids = friendsSnap.docs.map((d) => d.id);

    // Intersect with this gym's membership — one existence check per
    // friend, not a whereIn (30-item cap).
    const memberChecks = await Promise.all(friendUids.map((fUid) =>
      db.collection('gyms').doc(gymId).collection('members').doc(fUid).get()));
    const memberFriendUids = friendUids.filter((_, i) => memberChecks[i].exists);
    if (!memberFriendUids.length) return;

    const actor = await fetchActor(db, arrivingUid);
    const dayKey = dayKeyFor(now);
    let sent = 0;

    await Promise.all(memberFriendUids.map(async (receiverUid) => {
      try {
        const receiverPrefsSnap = await db.collection('users').doc(receiverUid)
          .collection('private').doc('presence_prefs').get();
        const mutedFriends = (receiverPrefsSnap.exists
          && receiverPrefsSnap.data().muted_friend_uids) || [];
        if (mutedFriends.includes(arrivingUid)) return;

        // Idempotent dedup: deterministic doc id, create-if-absent.
        const logRef = db.collection('gyms').doc(gymId)
          .collection('presence_notify_log').doc(`${receiverUid}_${arrivingUid}_${dayKey}`);
        const logSnap = await logRef.get();
        if (logSnap.exists) return;
        await logRef.set({
          receiver_uid: receiverUid,
          arriving_uid: arrivingUid,
          day_key: dayKey,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          expires_at: admin.firestore.Timestamp.fromMillis(
            now.getTime() + notifyLogTtlDays * 24 * 60 * 60 * 1000),
        });

        await writeNotification(db, {
          targetUid: receiverUid,
          type: 'friendAtGym',
          actorUid: arrivingUid,
          actorName: actor.displayName,
          actorPhotoUrl: actor.photoURL,
          relatedId: gymId,
          metadata: { gymName },
        });
        sent++;
      } catch (e) {
        functions.logger.error('onGymPresenceCreated: failed for one receiver', {
          gymId, arrivingUid, receiverUid, error: e.message,
        });
      }
    }));

    functions.logger.info('onGymPresenceCreated: done', {
      gymId, arrivingUid, candidates: memberFriendUids.length, sent,
    });
  });

// Faz A (config migration) — export names kept stable for
// functions/test/config_schema_defaults.test.js (Faz 4 renamed the INTERNAL
// constants *_DEFAULT once the live-config read path above was wired in;
// the equality this test proves hasn't changed).
Object.assign(module.exports, {
  TIMESTAMP_SKEW_MS: TIMESTAMP_SKEW_MS_DEFAULT,
  RATE_LIMIT_REENTRY_MS: RATE_LIMIT_REENTRY_MS_DEFAULT,
  PRESENCE_TTL_MS: PRESENCE_TTL_MS_DEFAULT,
  STALE_SWEEP_LIMIT: STALE_SWEEP_LIMIT_DEFAULT,
  MAX_FRIENDS_FANOUT: MAX_FRIENDS_FANOUT_DEFAULT,
  NOTIFY_LOG_TTL_DAYS: NOTIFY_LOG_TTL_DAYS_DEFAULT,
  QUIET_HOURS_START: QUIET_HOURS_START_DEFAULT,
  QUIET_HOURS_END: QUIET_HOURS_END_DEFAULT,
  presenceConfig,
});
