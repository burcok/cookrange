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
//
// Both triggers below also write an admin_audit entry recording what changed
// and when. NEITHER can record WHO made the change: admin_roles/{uid} and
// admin_users/{uid} are both console/Admin-SDK-only (no callable exists for
// either), and a Firestore onWrite trigger receives no caller identity at
// all — that's fundamentally different from an onCall function's
// context.auth. Google Cloud's own Audit Logs record which Google account
// touched a document via Console, but that's a separate system this
// function doesn't reach into. If "who granted this" ever needs to live
// inside admin_audit itself, that requires a real write path (a callable)
// that knows its caller — not a bigger change to this trigger.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');

function diffDocs(before, after) {
  const keys = new Set([...Object.keys(before || {}), ...Object.keys(after || {})]);
  const diff = [];
  for (const key of keys) {
    const from = before ? before[key] : undefined;
    const to = after ? after[key] : undefined;
    if (JSON.stringify(from) !== JSON.stringify(to)) {
      diff.push({ key, from: from ?? null, to: to ?? null });
    }
  }
  return diff;
}
exports.diffDocs = diffDocs;

async function writeAdminAuditEntry({ action, targetUid, metadata }) {
  try {
    await admin.firestore().collection('admin_audit').add({
      action,
      targetUid,
      adminUid: null, // see file header — no caller identity available here
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata,
    });
  } catch (e) {
    // Best-effort: a failed audit write must never block the real effect
    // (the custom-claim sync below), only get logged.
    functions.logger.error('writeAdminAuditEntry failed', { action, targetUid, error: e.message });
  }
}

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

    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const action = !before && after
      ? 'grant_admin_role'
      : before && !after
        ? 'revoke_admin_role'
        : 'update_admin_role';
    await writeAdminAuditEntry({ action, targetUid: uid, metadata: { before, after } });
  });

// Records every change to the fine-grained admin_users/{uid} doc (role,
// grants, denials, status — DECISIONS.md ADR-024) as an admin_audit entry.
// No write path/callable exists for this doc yet (Console/Admin-SDK-only,
// same as admin_roles) — this trigger only observes and logs, it doesn't
// validate or reject anything.
exports.logAdminUsersChange = functions
  .firestore
  .document('admin_users/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const action = !before && after
      ? 'grant_admin_permissions'
      : before && !after
        ? 'revoke_admin_permissions'
        : 'update_admin_permissions';
    await writeAdminAuditEntry({ action, targetUid: uid, metadata: { diff: diffDocs(before, after) } });
  });
