'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 5 — server-authored system messages ("X joined", "Admin renamed the
// group") for a group's paired chat (`community_groups/{groupId}.chat_id` ->
// `chats/{chatId}/messages`).
//
// Security property this whole file exists for: `firestore.rules`'
// `isValidNewMessage()` enforces `senderId == request.auth.uid` on every
// CLIENT write, and deliberately does NOT allow `system_event`/
// `system_params` in its client-writable field allowlist at all. A Cloud
// Function using the Admin SDK bypasses Firestore rules entirely, so it can
// write `senderId: '__system__'` — a value no client could ever produce for
// itself (their own uid can never equal the literal string `'__system__'`).
// Leaving these two keys OFF the client allowlist is what makes this
// unforgeable; adding them there instead would be a straightforward group-
// chat impersonation vector.
//
// Each message stores an EVENT KEY + PARAMS (never a pre-rendered string) —
// `AppMessageBubble._systemMessageText` (Dart) localizes the actual sentence
// from these via `AppLocalizations` at render time, in the READER's own
// language, matching this app's everywhere-EN/TR-parity rule. `body` is ALSO
// written, as a plain-English fallback for defensive rendering (a future/
// legacy doc with no recognized `system_event`) — and, as a side effect,
// what `onChatMessageCreated` (functions/index.js) uses for the push-
// notification preview text, since that trigger fires for this write too
// (it has no special-case for `type: 'system'`).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');

/** Plain-English rendering of an event — see this file's header comment for why. */
function renderSystemMessageBody(event, params) {
  const name = (params && params.display_name) || 'Someone';
  switch (event) {
    case 'member_joined':
      return `${name} joined the group`;
    case 'member_left':
      return `${name} left the group`;
    case 'member_banned':
      return `${name} was banned from the group`;
    case 'group_renamed':
      return `Group name changed to "${(params && params.new_name) || ''}"`;
    case 'group_photo_changed':
      return 'Group photo was changed';
    default:
      return '';
  }
}

/**
 * Writes one system message into the group's paired chat. Mirrors the shape
 * `functions/templates.js: sendPlanOffer` writes for a `plan_offer`-typed
 * message (server_timestamp/timestamp both set to the same server instant,
 * plus a `lastMessage` mirror on the parent chat doc) — this file's own
 * message-writing precedent within this codebase.
 */
async function writeGroupSystemMessage(db, groupId, event, params) {
  const groupSnap = await db.collection('community_groups').doc(groupId).get();
  if (!groupSnap.exists) {
    functions.logger.warn('writeGroupSystemMessage: group not found', { groupId, event });
    return;
  }
  const chatId = groupSnap.data().chat_id || groupId;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const messageRef = db.collection('chats').doc(chatId).collection('messages').doc();
  const messageId = messageRef.id;
  const body = renderSystemMessageBody(event, params);

  const messageData = {
    id: messageId,
    senderId: '__system__',
    type: 'system',
    body,
    system_event: event,
    system_params: params || {},
    attachments: [],
    reactions: {},
    delivered_to: [],
    read_by: [],
    mentions: [],
    is_deleted: false,
    client_id: messageId,
    server_timestamp: now,
    timestamp: now,
  };

  await messageRef.set(messageData);
  await db.collection('chats').doc(chatId).update({
    lastMessage: messageData,
    updatedAt: now,
  });

  functions.logger.info('writeGroupSystemMessage', { groupId, chatId, event });
}

// ─────────────────────────────────────────────────────────────────────────────
// community_groups/{groupId}/members/{uid} — onCreate -> member_joined,
// onDelete -> member_left, onUpdate (banned false -> true only) -> member_banned.
// One `onWrite` trigger (not three separate exports) so every transition is
// diffed from the SAME before/after pair, the same way `onGroupDocUpdated`
// below diffs the parent group doc.
// ─────────────────────────────────────────────────────────────────────────────

exports.onGroupMemberWritten = functions.firestore
  .document('community_groups/{groupId}/members/{uid}')
  .onWrite(async (change, context) => {
    const { groupId, uid } = context.params;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    let event = null;
    if (!before && after) {
      event = 'member_joined';
    } else if (before && !after) {
      event = 'member_left';
    } else if (before && after) {
      // Only the ban-flag transition on an update — never fires for a
      // delete (handled above), and never fires for any OTHER field change
      // on the member doc (role change, mute, etc.) — those aren't in this
      // file's scope.
      if (before.banned !== true && after.banned === true) {
        event = 'member_banned';
      }
    }
    if (!event) return null;

    const db = admin.firestore();
    let displayName = (after && after.display_name) || (before && before.display_name) || '';
    if (!displayName) {
      try {
        const userSnap = await db.collection('users').doc(uid).get();
        displayName = userSnap.exists ? (userSnap.data().displayName || '') : '';
      } catch (e) {
        functions.logger.error('onGroupMemberWritten: user lookup failed', {
          groupId, uid, error: e.message,
        });
      }
    }

    try {
      await writeGroupSystemMessage(db, groupId, event, { uid, display_name: displayName });
    } catch (e) {
      functions.logger.error('onGroupMemberWritten: write failed', {
        groupId, uid, event, error: e.message,
      });
    }
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// community_groups/{groupId} — onUpdate. Diffs old vs new data itself so this
// only ever fires for `name`/`cover_image_url` actually changing — NOT on
// every unrelated field write (e.g. `computeGroupActivityScores`' 15-minute
// activity_score/activity_updated_at bump, `member_count` increments, etc.).
// ─────────────────────────────────────────────────────────────────────────────

exports.onGroupDocUpdated = functions.firestore
  .document('community_groups/{groupId}')
  .onUpdate(async (change, context) => {
    const { groupId } = context.params;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const db = admin.firestore();

    const events = [];
    if (after.name && before.name !== after.name) {
      events.push({
        event: 'group_renamed',
        params: { old_name: before.name || '', new_name: after.name },
      });
    }
    if (before.cover_image_url !== after.cover_image_url) {
      events.push({ event: 'group_photo_changed', params: {} });
    }

    if (events.length === 0) return null;

    for (const { event, params } of events) {
      try {
        await writeGroupSystemMessage(db, groupId, event, params);
      } catch (e) {
        functions.logger.error('onGroupDocUpdated: write failed', {
          groupId, event, error: e.message,
        });
      }
    }
    return null;
  });
