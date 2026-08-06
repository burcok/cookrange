'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authoritative QR check-in validation (Faz 0 §0.7).
//
// GymService.validateQRCheckIn used to compare a scanned token against
// gyms/{gymId}.qr_token entirely client-side — and that field lived on the
// PUBLIC gym doc, readable by any authenticated user with a plain get(), no
// scan required. Worse, firestore.rules' checkins/create rule only ever
// checked `uid`/`timestamp`/`method` shape (Faz 0 §0.1) — it had no way to
// confirm a valid scan happened at all, so a modified client could call
// _recordCheckIn directly and skip validateQRCheckIn entirely.
//
// Fix: the token now lives at gyms/{gymId}/private/qr_token, readable only
// by the gym's owner/admin (firestore.rules) — members obtain it exclusively
// by scanning the rendered QR image, never via a Firestore read. This
// function is the ONLY place that ever compares a scanned value against the
// stored token, and the ONLY writer of a QR-method check-in; the client no
// longer writes checkins/* directly for this method.
//
// SEC-08 fix (this session): GPS check-ins used to be exactly what the
// paragraph above warned about — the client computed Haversine distance
// itself and, if "close enough," wrote `checkins/*` directly, gated only by
// firestore.rules' shape check (uid/timestamp/method — no membership check
// AT ALL, worse than this file's own header implied, and no server-side
// distance recompute of any kind). `validateGymGpsCheckin` below closes
// this the same way `validateGymCheckin` already closed the QR path:
// membership re-derived server-side, distance recomputed server-side from
// the gym's own stored coordinates, Admin SDK is the only writer.
// firestore.rules' `checkins` collection is now `create: if false` for
// EVERY method — both real client check-in paths (QR, GPS) go through a
// callable; 'manual' was already unreachable from any current client UI
// (Faz 0 §0.7 removed its entry point, kept only the enum/rule value for a
// hypothetical future front-desk flow — now that hypothetical flow would
// need its own callable too, not a rules exemption).
//
// Both callables now also rate-limit (SEC-12's shared pattern,
// functions/rate_limit.js) — this file's own header already flagged "no
// rate limit" as an open gap even for the QR path.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable } = require('./notifications');
const { awardXp, xpEntry } = require('./progress');
const { checkAndBumpSlidingWindow, lockUntil } = require('./rate_limit');
const { getConfig } = require('./app_config');

// Faz A Faz 4 — FALLBACK; app_config/server's `moderation.checkin_rate_limit`
// is the live source once seeded. Shared by both callables below — one
// budget per user across QR + GPS, not one per method.
const CHECKIN_RATE_WINDOW_MS_DEFAULT = 60 * 60 * 1000;
const CHECKIN_RATE_MAX_IN_WINDOW_DEFAULT = 6;
const CHECKIN_LOCK_MS_DEFAULT = 60 * 60 * 1000;

async function checkinRateLimitTriple() {
  const cfg = await getConfig();
  const live = cfg && cfg.moderation && cfg.moderation.checkin_rate_limit;
  const isObj = live && typeof live === 'object';
  return {
    windowMs: isObj && typeof live.windowMs === 'number' ? live.windowMs : CHECKIN_RATE_WINDOW_MS_DEFAULT,
    max: isObj && typeof live.max === 'number' ? live.max : CHECKIN_RATE_MAX_IN_WINDOW_DEFAULT,
    lockMs: isObj && typeof live.lockMs === 'number' ? live.lockMs : CHECKIN_LOCK_MS_DEFAULT,
  };
}

/** Throws resource-exhausted if uid is over the shared checkin budget. */
async function enforceCheckinRateLimit(db, uid) {
  const { windowMs, max, lockMs } = await checkinRateLimitTriple();
  const { limited } = await checkAndBumpSlidingWindow(db, uid, 'checkin', windowMs, max);
  if (limited) {
    await lockUntil(db, uid, 'checkin', lockMs);
    throw new functions.https.HttpsError('resource-exhausted', 'checkin_rate_limited');
  }
}

// Great-circle distance in kilometres — verbatim port of
// lib/core/utils/haversine.dart's haversineKm, so the two stay
// numerically identical (same formula, same earth radius constant).
function haversineKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371.0;
  const toRad = (deg) => deg * (Math.PI / 180);
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
    + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

/**
 * Shared by both callables below: re-derives membership, enforces the
 * checkin rate limit, writes the checkin doc + last_check_in via one
 * batch (Admin SDK), and awards check_in XP. `method` is 'qr' or 'gps'.
 */
async function commitCheckin(db, { uid, gymId, method }) {
  const gymRef = db.collection('gyms').doc(gymId);
  const memberRef = gymRef.collection('members').doc(uid);
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.exists ? userSnap.data() || {} : {};

  const now = admin.firestore.FieldValue.serverTimestamp();
  const checkinData = { uid, timestamp: now, method };
  if (userData.displayName) checkinData.display_name = userData.displayName;
  if (userData.photoURL) checkinData.photo_url = userData.photoURL;

  const checkinRef = gymRef.collection('checkins').doc();
  const batch = db.batch();
  batch.set(checkinRef, checkinData);
  batch.update(memberRef, { last_check_in: now });
  await batch.commit();

  // Faz 5 §5.1: check_in XP — NEVER client-reported (see progress.js's
  // header comment). Membership + (for GPS) distance re-verification above
  // IS the server-side proof; a courtesy call, failure never unwinds the
  // already-committed check-in.
  const t = await xpEntry('check_in');
  await awardXp(db, uid, 'check_in', checkinRef.id, t.points, t.dailyCap).catch((e) => {
    functions.logger.error('commitCheckin: awardXp(check_in) failed', { uid, gymId, method, error: e.message });
  });

  return checkinRef.id;
}

exports.validateGymCheckin = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const gymId = data && typeof data.gymId === 'string' ? data.gymId : '';
  const token = data && typeof data.token === 'string' ? data.token : '';
  if (!gymId || !token) {
    throw new functions.https.HttpsError('invalid-argument', 'gymId and token are required');
  }

  const db = admin.firestore();
  const gymRef = db.collection('gyms').doc(gymId);
  const memberRef = gymRef.collection('members').doc(uid);
  const tokenRef = gymRef.collection('private').doc('qr_token');

  const [memberSnap, tokenSnap] = await Promise.all([
    memberRef.get(),
    tokenRef.get(),
  ]);

  // Mirrors the implicit gate the old client path relied on: _recordCheckIn's
  // batch.update(memberRef, ...) fails outright on a nonexistent member doc,
  // since Firestore update() requires the doc to already exist.
  if (!memberSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'not_a_member');
  }
  if (!tokenSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'invalid_token');
  }

  const tokenData = tokenSnap.data() || {};
  const expiresAt = tokenData.expires_at;
  const expiresDate = expiresAt && typeof expiresAt.toDate === 'function' ? expiresAt.toDate() : null;
  if (tokenData.token !== token || !expiresDate || expiresDate.getTime() <= Date.now()) {
    throw new functions.https.HttpsError('failed-precondition', 'invalid_or_expired_token');
  }

  await enforceCheckinRateLimit(db, uid);
  await commitCheckin(db, { uid, gymId, method: 'qr' });

  functions.logger.info('validateGymCheckin: ok', { uid, gymId });
  return { ok: true };
});

/**
 * validateGymGpsCheckin({gymId, userLat, userLng}) — SEC-08 fix. Re-derives
 * membership AND recomputes the Haversine distance server-side against the
 * gym's own stored `latitude`/`longitude`/`check_in_radius` — the client's
 * self-reported coordinates are the only untrusted input; everything they're
 * compared against, and the pass/fail decision itself, is server-side.
 */
exports.validateGymGpsCheckin = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const gymId = data && typeof data.gymId === 'string' ? data.gymId : '';
  const userLat = data && typeof data.userLat === 'number' ? data.userLat : null;
  const userLng = data && typeof data.userLng === 'number' ? data.userLng : null;
  if (!gymId || userLat === null || userLng === null) {
    throw new functions.https.HttpsError('invalid-argument', 'gymId, userLat and userLng are required');
  }

  const db = admin.firestore();
  const gymRef = db.collection('gyms').doc(gymId);
  const memberRef = gymRef.collection('members').doc(uid);

  const [memberSnap, gymSnap] = await Promise.all([
    memberRef.get(),
    gymRef.get(),
  ]);

  if (!memberSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'not_a_member');
  }
  if (!gymSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'gym_not_found');
  }
  const gym = gymSnap.data() || {};
  const gymLat = typeof gym.latitude === 'number' ? gym.latitude : null;
  const gymLng = typeof gym.longitude === 'number' ? gym.longitude : null;
  if (gymLat === null || gymLng === null) {
    throw new functions.https.HttpsError('failed-precondition', 'gym_has_no_location');
  }
  const radiusM = typeof gym.check_in_radius === 'number' ? gym.check_in_radius : 100;

  const distanceM = haversineKm(gymLat, gymLng, userLat, userLng) * 1000;
  if (distanceM > radiusM) {
    throw new functions.https.HttpsError('failed-precondition', 'too_far_from_gym');
  }

  await enforceCheckinRateLimit(db, uid);
  await commitCheckin(db, { uid, gymId, method: 'gps' });

  functions.logger.info('validateGymGpsCheckin: ok', { uid, gymId, distanceM: Math.round(distanceM) });
  return { ok: true };
});

// Faz A (config migration) — export names kept stable, see presence.js's
// identical comment in a sibling file.
Object.assign(module.exports, {
  CHECKIN_RATE_WINDOW_MS: CHECKIN_RATE_WINDOW_MS_DEFAULT,
  CHECKIN_RATE_MAX_IN_WINDOW: CHECKIN_RATE_MAX_IN_WINDOW_DEFAULT,
  CHECKIN_LOCK_MS: CHECKIN_LOCK_MS_DEFAULT,
});
