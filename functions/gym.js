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
// GPS/manual check-ins are NOT covered here — the client still records those
// directly (firestore.rules' shape checks only) and their own server-side
// re-validation (e.g. confirming real geofence proximity) is out of scope
// for this fix, tracked separately as Faz 1.5.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable } = require('./notifications');

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
  const userRef = db.collection('users').doc(uid);

  const [memberSnap, tokenSnap, userSnap] = await Promise.all([
    memberRef.get(),
    tokenRef.get(),
    userRef.get(),
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

  // Actor identity is re-derived server-side from the caller's own user doc
  // rather than trusted from the client — a client can't spoof someone
  // else's name/photo into the check-in feed this way.
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  const now = admin.firestore.FieldValue.serverTimestamp();
  const checkinData = { uid, timestamp: now, method: 'qr' };
  if (userData.displayName) checkinData.display_name = userData.displayName;
  if (userData.photoURL) checkinData.photo_url = userData.photoURL;

  const batch = db.batch();
  batch.set(gymRef.collection('checkins').doc(), checkinData);
  batch.update(memberRef, { last_check_in: now });
  await batch.commit();

  functions.logger.info('validateGymCheckin: ok', { uid, gymId });
  return { ok: true };
});
