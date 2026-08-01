'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Mirrors admin_roles/{uid} (server truth — console/Admin-SDK-written only,
// firestore.rules denies client writes even from an admin) onto a Firebase
// Auth custom claim (`admin: true`). The client can verify a custom claim
// itself via the ID token, so the admin UI can finally gate on something real
// instead of the client-writable `user_roles` array on the user doc.
//
// BLK-05: until this function existed, nothing anywhere wrote admin_roles/{uid}
// at all, so isAdmin() in firestore.rules could never be true and the entire
// admin surface (~7,400 LOC, 9 screens) 403'd on every read. Bootstrapping the
// first admin is still a manual console step — see docs/SECURITY.md §4 for the
// runbook — this function only keeps the claim in sync once that doc exists.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');

exports.syncAdminClaim = functions
  .firestore
  .document('admin_roles/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const isAdmin = change.after.exists && change.after.data().is_admin === true;

    try {
      // No other custom claims exist anywhere in this codebase today, so a
      // full replace (not a merge) is safe. If that changes, read the current
      // user record first and merge instead of clobbering.
      await admin.auth().setCustomUserClaims(uid, isAdmin ? { admin: true } : null);
      functions.logger.info('syncAdminClaim: claim synced', { uid, isAdmin });
    } catch (e) {
      functions.logger.error('syncAdminClaim failed', { uid, error: e.message });
    }
  });
