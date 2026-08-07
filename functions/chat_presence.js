'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Chat Upgrade Phase 2 — Realtime Database presence/typing mirror.
//
// NOT related to functions/presence.js — that file is the UNRELATED Faz 1
// gym-geofence check-in system (`recordPresenceEvent`,
// `closeStalePresenceSessions`, `onGymPresenceCreated`), entirely
// Firestore-based. Sharing the word "presence" is a coincidence, not a
// relationship. This file is the only thing in the backend that talks to
// Realtime Database, and the only writer of `users/{uid}.is_online` /
// `.last_active_at` going forward — see
// `lib/core/services/presence_service.dart`'s header comment for the full
// picture: the client only ever writes RTDB (`onDisconnect`-backed, so a
// killed app converges to offline even with no code ever running again);
// this file mirrors the AGGREGATE of that RTDB state back onto the exact
// same Firestore fields every existing reader (`chat_service.dart`,
// `profile_screen.dart`, `chat_list_screen.dart`, `select_friend_sheet.dart`)
// already reads, so none of those need to change.
//
// Two-tier design:
//   mirrorPresence         — RTDB-triggered (`/presence/{uid}/{deviceId}`
//                            onWrite), near-real-time. Going online (or
//                            "away", which still mirrors to
//                            `is_online: true` below) is applied
//                            IMMEDIATELY, no debounce. Going offline is
//                            debounced ~60s so a brief reconnect blip on an
//                            otherwise-healthy device doesn't flip
//                            `is_online` off and immediately back on.
//   reconcileStalePresence — `pubsub.schedule('every 1 minutes')` backstop
//                            sweep. Two jobs: (a) flip any device whose
//                            `onDisconnect` never fired — e.g. the app
//                            crashed before the registration completed, the
//                            one sequencing bug the client's ordering
//                            discipline is built to avoid, but a backstop
//                            costs little; (b) mature any pending-offline
//                            debounce older than the ~60s window, since an
//                            RTDB trigger has no way to schedule its own
//                            future re-check — only a scheduled sweep can.
//
// `is_online` stays the plain boolean `UserModel.isOnline` already reads —
// this phase does not add a three-state "away" concept to Firestore.
// Aggregate `online` OR `away` both mirror to `is_online: true`; only a
// fully-`offline` aggregate mirrors to `false`. The `away` distinction lives
// only in RTDB for now (available for a future three-state presence dot).
//
// Debounce bookkeeping lives at the SIBLING path `/mirror_state/{uid}`, not
// under `/presence/{uid}` itself — writing back into the path this function
// is triggered on would retrigger itself on every write, the single most
// common bug in this exact "aggregate + mirror" pattern. Nothing in this
// file ever writes under `/presence/**` except `reconcileStalePresence`'s
// own stale-device flip, which is a deliberate, self-contained one-time
// correction, not part of the mirror's own read/write cycle.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');

// A device with no heartbeat/reconnect in this long is considered stale —
// reconcileStalePresence's backstop sweep flips it to offline in RTDB.
// Comfortably above PresenceService's ~120s heartbeat interval so a single
// missed beat under normal jitter never trips this.
const STALE_AFTER_MS_DEFAULT = 90 * 1000;
// mirrorPresence's "everyone just went offline" debounce window before
// reconcileStalePresence commits it to Firestore.
const OFFLINE_DEBOUNCE_MS_DEFAULT = 60 * 1000;
// Firestore batches cap at 500 writes — flush defensively well under that,
// matching functions/groups.js's computeGroupActivityScores idiom exactly.
const FIRESTORE_BATCH_LIMIT = 400;
// Safety valve on reconcileStalePresence's full-tree scan (RTDB has no
// cross-uid query at this nesting depth, so the sweep reads the whole
// `/presence` node — this just bounds the worst case rather than changing
// behavior at any realistic scale).
const PRESENCE_UID_SCAN_LIMIT_DEFAULT = 2000;

/**
 * online > away > offline — same precedence as
 * lib/core/utils/presence_aggregate.dart's PresenceAggregate.resolve.
 * Deliberately reimplemented here rather than shared: this stack has no
 * mechanism to share code between the Dart client and the Node.js backend,
 * so keeping the (tiny, three-line) rule in sync by hand is simpler than
 * inventing one.
 */
function aggregateState(devicesByDeviceId) {
  const states = Object.values(devicesByDeviceId || {}).map((d) => d && d.state);
  if (states.includes('online')) return 'online';
  if (states.includes('away')) return 'away';
  return 'offline';
}

/** Reads /presence/{uid} once and returns its aggregate ('online'|'away'|'offline'). */
async function readAggregateForUid(db, uid) {
  const snap = await db.ref(`presence/${uid}`).once('value');
  return aggregateState(snap.val());
}

/** The sibling debounce-bookkeeping path — see header comment for why it's not under /presence. */
function mirrorStateRef(db, uid) {
  return db.ref(`mirror_state/${uid}`);
}

exports.mirrorPresence = functions
  .database
  .ref('/presence/{uid}/{deviceId}')
  .onWrite(async (_change, context) => {
    const { uid } = context.params;
    const db = admin.database();
    const firestore = admin.firestore();

    try {
      const aggregate = await readAggregateForUid(db, uid);
      const isOnline = aggregate !== 'offline';

      if (isOnline) {
        // Immediate — no debounce for going online/away.
        const userRef = firestore.collection('users').doc(uid);
        const userSnap = await userRef.get();
        const current = userSnap.exists ? userSnap.data().is_online : undefined;
        let changed = false;
        if (current !== true) {
          await userRef.set({
            is_online: true,
            last_active_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          changed = true;
        }
        // Clear any pending "going offline" bookkeeping from a previous
        // debounce cycle — we're back, so that cycle is moot.
        await mirrorStateRef(db, uid).remove();
        functions.logger.info('mirrorPresence: online/away, mirrored immediately', {
          uid, aggregate, changed,
        });
        return;
      }

      // Aggregate is offline — debounce ~60s before committing to
      // Firestore. Only reconcileStalePresence's sweep actually matures
      // this (an RTDB trigger has no way to schedule its own future
      // re-check), so this just records WHEN the debounce started, once.
      const stateSnap = await mirrorStateRef(db, uid).once('value');
      const alreadyPending = stateSnap.exists() && stateSnap.val()
        && stateSnap.val().pending_offline_since;
      if (alreadyPending) {
        functions.logger.info('mirrorPresence: still offline, debounce already pending', { uid });
        return;
      }
      await mirrorStateRef(db, uid).set({
        pending_offline_since: admin.database.ServerValue.TIMESTAMP,
      });
      functions.logger.info('mirrorPresence: all devices offline, starting debounce', { uid });
    } catch (e) {
      functions.logger.error('mirrorPresence: failed for uid', { uid, error: e.message });
    }
  });

exports.reconcileStalePresence = functions
  .pubsub
  .schedule('every 1 minutes')
  .onRun(async (_context) => {
    const db = admin.database();
    const firestore = admin.firestore();
    const now = Date.now();

    // ── Pass 1: flip devices RTDB's own onDisconnect missed ──────────────
    // RTDB has no query across uids at this nesting depth (presence/{uid}/
    // {deviceId}), so this reads the whole tree once and filters in code —
    // bounded by PRESENCE_UID_SCAN_LIMIT_DEFAULT as a safety valve, not a
    // behavior change at this app's realistic scale.
    let presenceSnap;
    try {
      presenceSnap = await db.ref('presence').once('value');
    } catch (e) {
      functions.logger.error('reconcileStalePresence: failed to read /presence', { error: e.message });
      return;
    }

    const allUids = [];
    presenceSnap.forEach((uidSnap) => { allUids.push(uidSnap.key); return false; });
    if (allUids.length > PRESENCE_UID_SCAN_LIMIT_DEFAULT) {
      functions.logger.warn('reconcileStalePresence: uid scan truncated at cap', {
        total: allUids.length, cap: PRESENCE_UID_SCAN_LIMIT_DEFAULT,
      });
    }
    const uidsToScan = allUids.slice(0, PRESENCE_UID_SCAN_LIMIT_DEFAULT);

    const affectedUids = new Set();
    let flippedCount = 0;

    for (const uid of uidsToScan) {
      const devices = presenceSnap.child(uid).val() || {};
      for (const deviceId of Object.keys(devices)) {
        try {
          const d = devices[deviceId];
          if (!d || d.state === 'offline') continue;
          const lastActiveMs = typeof d.last_active === 'number' ? d.last_active
            : (typeof d.connected_at === 'number' ? d.connected_at : null);
          if (lastActiveMs === null || (now - lastActiveMs) <= STALE_AFTER_MS_DEFAULT) continue;

          await db.ref(`presence/${uid}/${deviceId}`).update({ state: 'offline' });
          affectedUids.add(uid);
          flippedCount++;
          functions.logger.info('reconcileStalePresence: flipped stale device offline', {
            uid, deviceId, ageMs: now - lastActiveMs,
          });
        } catch (e) {
          functions.logger.error('reconcileStalePresence: failed for one device', {
            uid, deviceId, error: e.message,
          });
        }
      }
    }

    // ── Pass 2: mature any pending-offline debounce older than the window ─
    try {
      const pendingSnap = await db.ref('mirror_state').once('value');
      pendingSnap.forEach((uidSnap) => {
        const pendingSince = uidSnap.val() && uidSnap.val().pending_offline_since;
        if (typeof pendingSince === 'number' && (now - pendingSince) >= OFFLINE_DEBOUNCE_MS_DEFAULT) {
          affectedUids.add(uidSnap.key);
        }
        return false;
      });
    } catch (e) {
      functions.logger.error('reconcileStalePresence: failed to read /mirror_state', { error: e.message });
    }

    // ── Re-mirror every affected uid to Firestore, batched at 400/commit ──
    // (functions/groups.js's computeGroupActivityScores idiom, mirrored
    // exactly, even though this is a different collection.)
    let batch = firestore.batch();
    let batchCount = 0;
    let mirroredCount = 0;

    for (const uid of affectedUids) {
      try {
        const aggregate = await readAggregateForUid(db, uid);
        const isOnline = aggregate !== 'offline';
        const userRef = firestore.collection('users').doc(uid);
        const userSnap = await userRef.get();
        const current = userSnap.exists ? userSnap.data().is_online : undefined;

        if (current !== isOnline) {
          batch.update(userRef, {
            is_online: isOnline,
            last_active_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          batchCount++;
          mirroredCount++;
          if (batchCount >= FIRESTORE_BATCH_LIMIT) {
            await batch.commit();
            batch = firestore.batch();
            batchCount = 0;
          }
        }
        // Debounce bookkeeping is independent of whether Firestore actually
        // changed — clear it whenever this uid has been resolved (online
        // again, or the offline transition has just been committed). A
        // future new all-offline transition creates a fresh marker via
        // mirrorPresence, which is the correct behavior for a new cycle.
        await mirrorStateRef(db, uid).remove();
      } catch (e) {
        functions.logger.error('reconcileStalePresence: failed to mirror one uid', {
          uid, error: e.message,
        });
      }
    }
    if (batchCount > 0) await batch.commit();

    functions.logger.info('reconcileStalePresence: done', {
      uidsScanned: uidsToScan.length,
      devicesFlipped: flippedCount,
      uidsMirrored: mirroredCount,
    });
  });

Object.assign(module.exports, {
  STALE_AFTER_MS: STALE_AFTER_MS_DEFAULT,
  OFFLINE_DEBOUNCE_MS: OFFLINE_DEBOUNCE_MS_DEFAULT,
  FIRESTORE_BATCH_LIMIT,
  PRESENCE_UID_SCAN_LIMIT: PRESENCE_UID_SCAN_LIMIT_DEFAULT,
  aggregateState,
});
