'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authored follow / friend-request writes (SEC-06).
//
// Until this file existed, `friends`, `friend_requests` and `follow`'s edge
// docs were all written directly by the client SDK under a bare
// `allow create: if isAuthenticated()` rule — any signed-in user could write
// into any OTHER user's friends list, impersonate a friend request, or forge
// a follow edge with an arbitrary actor. firestore.rules now denies client
// writes on all three paths unconditionally; every edge + its notification is
// written here, atomically, with the actor always derived from
// `context.auth.uid`.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable, writeNotification, fetchActor } = require('./notifications');

function requireTargetUid(data) {
  const targetUid = (data && typeof data.targetUid === 'string') ? data.targetUid : '';
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
  }
  return targetUid;
}

exports.followUser = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const targetUid = requireTargetUid(data);
  if (uid === targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'cannot_follow_self');
  }

  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.set(db.collection('users').doc(uid).collection('following').doc(targetUid), { followedAt: now });
  batch.set(db.collection('users').doc(targetUid).collection('followers').doc(uid), { followedAt: now });
  await batch.commit();

  const actor = await fetchActor(db, uid);
  await writeNotification(db, {
    targetUid,
    type: 'follow',
    actorUid: uid,
    actorName: actor.displayName,
    actorPhotoUrl: actor.photoURL,
    relatedId: uid,
  });

  return { ok: true };
});

exports.unfollowUser = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const targetUid = requireTargetUid(data);

  const db = admin.firestore();
  const batch = db.batch();
  batch.delete(db.collection('users').doc(uid).collection('following').doc(targetUid));
  batch.delete(db.collection('users').doc(targetUid).collection('followers').doc(uid));
  await batch.commit();

  return { ok: true };
});

exports.sendFriendRequest = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const targetUid = requireTargetUid(data);
  if (uid === targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'cannot_friend_self');
  }

  const db = admin.firestore();
  const usersRef = db.collection('users');

  // Re-verify server-side — never trust the client's own status check.
  const [friendDoc, reqOutDoc, reqInDoc] = await Promise.all([
    usersRef.doc(uid).collection('friends').doc(targetUid).get(),
    usersRef.doc(uid).collection('friend_requests').doc(targetUid).get(),
    usersRef.doc(targetUid).collection('friend_requests').doc(uid).get(),
  ]);
  if (friendDoc.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'already_friends');
  }
  if (reqOutDoc.exists || reqInDoc.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'request_exists');
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.set(usersRef.doc(uid).collection('friend_requests').doc(targetUid), { type: 'outgoing', timestamp: now });
  batch.set(usersRef.doc(targetUid).collection('friend_requests').doc(uid), { type: 'incoming', timestamp: now });
  await batch.commit();

  const actor = await fetchActor(db, uid);
  await writeNotification(db, {
    targetUid,
    type: 'friendRequest',
    actorUid: uid,
    actorName: actor.displayName,
    actorPhotoUrl: actor.photoURL,
    relatedId: uid, // sender's uid — used by the client's accept/reject actions
  });

  return { ok: true };
});

/** Deletes both sides of a pending friend_requests pair. */
async function deleteRequestPair(db, uid1, uid2) {
  const batch = db.batch();
  batch.delete(db.collection('users').doc(uid1).collection('friend_requests').doc(uid2));
  batch.delete(db.collection('users').doc(uid2).collection('friend_requests').doc(uid1));
  await batch.commit();
}

/** Deletes notification doc(s) matching relatedId+type from a user's inbox. */
async function deleteNotificationsByRelatedId(db, targetUid, relatedId, type) {
  const snap = await db
    .collection('notifications')
    .doc(targetUid)
    .collection('items')
    .where('relatedId', '==', relatedId)
    .where('type', '==', type)
    .get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

/** Accept or reject an incoming friend request. Caller is the receiver. */
exports.respondToFriendRequest = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const senderUid = requireTargetUid({ targetUid: data && data.senderUid });
  const accept = !!(data && data.accept === true);

  const db = admin.firestore();
  const incomingRef = db.collection('users').doc(uid).collection('friend_requests').doc(senderUid);
  const incomingSnap = await incomingRef.get();
  if (!incomingSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'no_such_request');
  }

  await deleteRequestPair(db, uid, senderUid);

  if (accept) {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    batch.set(db.collection('users').doc(uid).collection('friends').doc(senderUid), { since: now });
    batch.set(db.collection('users').doc(senderUid).collection('friends').doc(uid), { since: now });
    await batch.commit();

    const actor = await fetchActor(db, uid);
    await writeNotification(db, {
      targetUid: senderUid,
      type: 'friendAccepted',
      actorUid: uid,
      actorName: actor.displayName,
      actorPhotoUrl: actor.photoURL,
      relatedId: uid,
    });
    // Clean up the original "X sent you a friend request" notification.
    await deleteNotificationsByRelatedId(db, uid, senderUid, 'friendRequest');
  }

  return { ok: true, accepted: accept };
});

/** Cancel my own outgoing friend request. Caller is the original sender. */
exports.cancelFriendRequest = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const targetUid = requireTargetUid(data);
  await deleteRequestPair(admin.firestore(), uid, targetUid);
  return { ok: true };
});
