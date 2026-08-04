'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authored notification writes (BLK-03 / SEC-06).
//
// Canonical path: notifications/{uid}/items/{docId} — matches the existing
// onInAppNotificationCreated trigger (index.js) so every write here fans out
// to push automatically. firestore.rules denies client `create` on this path
// unconditionally; every notification in this codebase is now written by
// Admin SDK code (this file, social.js, economy.js, or the admin.js/index.js
// broadcast path), never by a client SDK write. actorName/actorPhotoUrl are
// always re-fetched here from the caller's own user doc — never trusted from
// the client payload — which is what closes the push-forgery hole.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');

async function fetchActor(db, uid) {
  const snap = await db.collection('users').doc(uid).get();
  const data = snap.exists ? snap.data() : {};
  return {
    displayName: data.displayName || null,
    photoURL: data.photoURL || null,
  };
}

/**
 * Reads a recipient's FCM token from `users/{uid}/private/account` (audit
 * N1 — the token used to live on the world-readable main user doc; a push
 * token is a device fingerprint, the same class of data as email/IP/device
 * history that migration moved off it). Returns null if absent.
 */
async function getFcmToken(db, uid) {
  const snap = await db.collection('users').doc(uid).collection('private').doc('account').get();
  return snap.exists ? (snap.data().fcm_token || null) : null;
}

/** Writes one notification doc at the canonical path. Admin-SDK only. */
async function writeNotification(db, {
  targetUid, type, actorUid, actorName, actorPhotoUrl, relatedId, metadata,
}) {
  const notifRef = db.collection('notifications').doc(targetUid).collection('items').doc();
  const payload = {
    type,
    isRead: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (actorUid) payload.actorUid = actorUid;
  if (actorName) payload.actorName = actorName;
  if (actorPhotoUrl) payload.actorPhotoUrl = actorPhotoUrl;
  if (relatedId) payload.relatedId = relatedId;
  if (metadata) payload.metadata = metadata;
  await notifRef.set(payload);
  return notifRef.id;
}

function assertCallable(context) {
  const callerUid = context.auth && context.auth.uid;
  if (!callerUid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }
  return callerUid;
}

// Types created by an ordinary user acting on someone else's content — the
// actor is always the caller, re-fetched server-side.
const GENERIC_ACTOR_TYPES = new Set(['likePost', 'likeComment', 'reaction', 'comment', 'system']);
// Types with no actor — the recipient is reporting a fact about themselves.
const SELF_TYPES = new Set(['streakMilestone']);

/**
 * Generic notification creation for social interactions (likes, comments,
 * reactions, mentions) and self-reported milestones. Follow/friend-request
 * notifications are created inside their own callables (social.js) because
 * those also need to write the underlying edge atomically; admin-decision
 * notifications go through sendAdminNotification below.
 */
exports.createNotification = functions.https.onCall(async (data, context) => {
  const callerUid = assertCallable(context);

  const targetUid = (data && typeof data.targetUid === 'string') ? data.targetUid : '';
  const type = (data && typeof data.type === 'string') ? data.type : '';
  const relatedId = (data && typeof data.relatedId === 'string') ? data.relatedId : undefined;
  const metadata = (data && typeof data.metadata === 'object' && data.metadata !== null)
    ? data.metadata
    : undefined;

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
  }

  const db = admin.firestore();

  if (SELF_TYPES.has(type)) {
    if (targetUid !== callerUid) {
      throw new functions.https.HttpsError('permission-denied', 'target_must_be_self');
    }
    await writeNotification(db, { targetUid, type, relatedId, metadata });
    return { ok: true };
  }

  if (!GENERIC_ACTOR_TYPES.has(type)) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_type');
  }
  if (targetUid === callerUid) {
    // Self-interaction — the client already filters this out before calling;
    // treat as a benign no-op rather than an error.
    return { ok: true, skipped: 'self' };
  }

  const actor = await fetchActor(db, callerUid);
  await writeNotification(db, {
    targetUid,
    type,
    actorUid: callerUid,
    actorName: actor.displayName,
    actorPhotoUrl: actor.photoURL,
    relatedId,
    metadata,
  });
  return { ok: true };
});

/**
 * Undoes a createNotification call (e.g. un-like, un-react) by deleting the
 * matching doc(s) from the target's inbox. Scoped to `actorUid == caller` so
 * a client can only retract notifications its own prior action created.
 */
exports.retractNotification = functions.https.onCall(async (data, context) => {
  const callerUid = assertCallable(context);

  const targetUid = (data && typeof data.targetUid === 'string') ? data.targetUid : '';
  const type = (data && typeof data.type === 'string') ? data.type : '';
  const relatedId = (data && typeof data.relatedId === 'string') ? data.relatedId : '';

  if (!targetUid || !type || !relatedId) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid, type and relatedId required');
  }

  const db = admin.firestore();
  const snap = await db
    .collection('notifications')
    .doc(targetUid)
    .collection('items')
    .where('relatedId', '==', relatedId)
    .where('type', '==', type)
    .where('actorUid', '==', callerUid)
    .get();

  if (snap.empty) return { ok: true, deleted: 0 };

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  return { ok: true, deleted: snap.size };
});

// Coach/gym application decisions — admin-authored, "Cookrange Team" as actor.
const ADMIN_DECISION_TYPES = new Set([
  'coachApplicationApproved',
  'coachApplicationRejected',
  'gymApplicationApproved',
  'gymApplicationRejected',
]);

/**
 * Admin-only notification sender. Covers the two admin surfaces that used to
 * write the notification doc directly from the client:
 *  - application decisions (coach/gym approve/reject), fired after the admin
 *    client's own batch (status update + profile/role grant) commits;
 *  - free-text single-user messages (admin_service.dart: sendNotificationToUser).
 * Requires the `admin` custom claim (BLK-05) — never trust `user_roles`.
 */
exports.sendAdminNotification = functions.https.onCall(async (data, context) => {
  const adminUid = assertCallable(context);
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'admin_required');
  }

  const targetUid = (data && typeof data.targetUid === 'string') ? data.targetUid : '';
  const type = (data && typeof data.type === 'string') ? data.type : '';
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
  }

  const db = admin.firestore();

  if (ADMIN_DECISION_TYPES.has(type)) {
    const relatedId = (data && typeof data.relatedId === 'string') ? data.relatedId : undefined;
    const notes = (data && typeof data.notes === 'string') ? data.notes : undefined;
    await writeNotification(db, {
      targetUid,
      type,
      actorUid: adminUid,
      actorName: 'Cookrange Team',
      relatedId,
      metadata: notes ? { notes } : undefined,
    });
    return { ok: true };
  }

  if (type === 'system') {
    const title = (data && typeof data.title === 'string') ? data.title.trim() : '';
    const body = (data && typeof data.body === 'string') ? data.body.trim() : '';
    if (!title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'title and body required');
    }
    if (title.length > 200 || body.length > 2000) {
      throw new functions.https.HttpsError('invalid-argument', 'title_or_body_too_long');
    }

    // No actorUid/metadata: NotificationModel.isLegacy relies on their absence
    // to render this title/body verbatim instead of the generic 'system' copy.
    const notifRef = db.collection('notifications').doc(targetUid).collection('items').doc();
    await notifRef.set({
      type: 'system',
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      title,
      body,
    });

    await db.collection('admin_audit').add({
      action: 'send_notification',
      targetUid,
      adminUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: { title },
    });
    return { ok: true };
  }

  throw new functions.https.HttpsError('invalid-argument', 'invalid_type');
});

module.exports.writeNotification = writeNotification;
module.exports.fetchActor = fetchActor;
module.exports.assertCallable = assertCallable;
module.exports.getFcmToken = getFcmToken;
