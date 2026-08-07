'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 5 — group-chat image storage-scoping fix.
//
// `chat_images/{scopeId}/{fileName}` (storage.rules, pre-existing) enforces
// participants-only access for a 1:1 chat by splitting `scopeId` on `_` —
// but a GROUP chat's `scopeId` is just the chatId, which has no `_`, so that
// check degrades to "any authenticated user can read" for every group-chat
// image ever uploaded. Storage rules cannot call Firestore, so no Storage
// rule alone can close this for a group chat.
//
// The fix: new uploads for a group-backed chat go to
// `chat_media/{chatId}/{uid}/{fileName}` instead (storage.rules: write-only
// for the uploading owner, `allow read: if false` ALWAYS). This callable is
// the ONLY way to ever read one back — it re-verifies the caller is a real
// participant/group-member of the owning chat in Firestore (mirroring
// `firestore.rules`' `isParticipant()`/`canAccessGroupChat()` logic,
// reimplemented here against Firestore via the Admin SDK, since Storage
// rules can't do this themselves) before minting a short-lived V4 signed URL.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');

// Mirrors `ChatMediaUrlCache`'s client-side expiry assumption (Dart).
const SIGNED_URL_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Mirrors `firestore.rules`' `isParticipant()`/`canAccessGroupChat()`: a
 * chat doc's plain `participants` array covers a DM or ad-hoc group chat
 * directly; a `community_groups`-backed chat additionally accepts a live
 * (non-banned) `community_groups/{groupId}/members/{uid}` doc, exactly like
 * `canAccessGroupChat()`/`isActiveGroupMember()` do in firestore.rules.
 */
async function canReadChatMedia(db, uid, chatId) {
  const chatSnap = await db.collection('chats').doc(chatId).get();
  if (!chatSnap.exists) return false;
  const chat = chatSnap.data();

  const participants = chat.participants || [];
  if (participants.includes(uid)) return true;

  const groupId = chat.groupId;
  if (!groupId) return false;

  const memberSnap = await db.collection('community_groups').doc(groupId)
    .collection('members').doc(uid).get();
  return memberSnap.exists && memberSnap.data().banned !== true;
}

exports.getChatMediaUrl = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const chatId = data && typeof data.chatId === 'string' ? data.chatId : '';
  const storagePath = data && typeof data.storagePath === 'string' ? data.storagePath : '';
  if (!chatId || !storagePath) {
    throw new functions.https.HttpsError('invalid-argument', 'chatId and storagePath are required');
  }

  // The path must actually be scoped to THIS chatId — never let a caller
  // pair a chat they legitimately belong to with an unrelated storagePath
  // under a DIFFERENT chat's scope.
  const expectedPrefix = `chat_media/${chatId}/`;
  if (!storagePath.startsWith(expectedPrefix)) {
    throw new functions.https.HttpsError('invalid-argument', 'storagePath does not match chatId');
  }

  const db = admin.firestore();
  const allowed = await canReadChatMedia(db, uid, chatId);
  if (!allowed) {
    throw new functions.https.HttpsError('permission-denied', 'not_a_participant');
  }

  try {
    const [url] = await admin.storage().bucket().file(storagePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + SIGNED_URL_TTL_MS,
    });
    return { url };
  } catch (e) {
    functions.logger.error('getChatMediaUrl: signed URL mint failed', {
      uid, chatId, storagePath, error: e.message,
    });
    throw new functions.https.HttpsError('internal', 'sign_failed');
  }
});
