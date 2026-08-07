'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Multi-device session registry — server side.
//
// Replaces AuthService's old single-session `current_session_id` kickout
// (logging in on a second device used to force-sign-out the first). Each
// installation now has its own `users/{uid}/devices/{deviceId}` doc
// (DeviceRegistryService, lib/core/services/device_registry_service.dart),
// which the client freely merge-writes platform/model/app_version/os_version/
// last_seen_at/push_token into. It can NEVER write `revoked`/`revoked_at`
// itself (firestore.rules forbids both on create and excludes them from the
// update allowlist) — this file is the only path that can flip that flag,
// because a bare Firestore flag can't actually invalidate a session; only
// revoking the underlying Firebase Auth refresh token does that.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');

// IMPORTANT, HONEST LIMITATION — read before changing any UX copy around this
// callable:
//
// `admin.auth().revokeRefreshTokens(uid)` is PER-USER, not per-device. Firebase
// Auth has no API to revoke a single refresh token / a single device's session
// in isolation — every refresh token issued to that uid is invalidated at
// once, and every already-issued ID token stays valid until it naturally
// expires (~1h) or the client is forced to refresh it.
//
//   - "Sign out this device" (allOthers: false, deviceId == caller's own):
//     works exactly as promised. The one device being targeted IS the one
//     whose next refresh we want to kill, so revoking the whole user's
//     tokens here is correct and scoped to the right intent.
//
//   - "Sign out all other devices" (allOthers: true): does NOT mean "every
//     other device is signed out and MY device stays signed in indefinitely
//     afterward." Because revokeRefreshTokens invalidates ALL of this user's
//     refresh tokens, including the CALLER's own, the calling device will
//     ALSO eventually be signed out once its own token next needs to refresh
//     — which can happen within the hour, not just "on next app restart".
//
// We do not attempt to work around this with custom claims or a token-version
// scheme — that is real added complexity, out of scope for this pass. Client
// copy for "sign out all other devices" should NOT promise the caller's own
// session survives indefinitely; it should only promise the OTHER devices are
// signed out immediately (which is fully true and instant via the `revoked`
// Firestore flag each targeted device is watching).
exports.revokeDevice = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const callerDeviceId = (data && typeof data.deviceId === 'string') ? data.deviceId.trim() : '';
  const allOthers = !!(data && data.allOthers === true);
  if (!callerDeviceId) {
    throw new functions.https.HttpsError('invalid-argument', 'deviceId required');
  }

  const db = admin.firestore();
  // Scoped under users/{uid}/devices automatically — the caller can only ever
  // name a device under their OWN uid, so no separate ownership check is
  // needed beyond the auth check above.
  const devicesRef = db.collection('users').doc(uid).collection('devices');
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();
  let revokedCount = 0;

  if (allOthers) {
    // Revoke every device doc EXCEPT the caller's own (the client passes its
    // own current deviceId so we know which one to spare).
    const snap = await devicesRef.get();
    snap.forEach((doc) => {
      if (doc.id === callerDeviceId) return;
      batch.set(doc.ref, { revoked: true, revoked_at: now }, { merge: true });
      revokedCount += 1;
    });
  } else {
    const targetRef = devicesRef.doc(callerDeviceId);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'device_not_found');
    }
    batch.set(targetRef, { revoked: true, revoked_at: now }, { merge: true });
    revokedCount = 1;
  }

  if (revokedCount === 0) {
    // Nothing to revoke (e.g. "sign out all others" with no other devices
    // registered) — skip the batch commit AND the user-wide token revocation
    // below, which would otherwise pointlessly log the caller out too.
    functions.logger.info('revokeDevice: nothing to revoke', { uid, allOthers });
    return { ok: true, revokedCount: 0 };
  }

  await batch.commit();

  // Per-USER, not per-device — see the header comment above. This is what
  // actually invalidates a session; the Firestore `revoked` flag alone is
  // just the signal DeviceRegistryService.watchThisDeviceRevoked uses to
  // force an IMMEDIATE local sign-out on the targeted device(s), ahead of
  // whenever their token would naturally next refresh.
  await admin.auth().revokeRefreshTokens(uid);

  functions.logger.info('revokeDevice: ok', { uid, allOthers, revokedCount });
  return { ok: true, revokedCount };
});
