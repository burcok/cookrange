'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// SEC-12 — UGC rate limits, spam and bot protection.
//
// Extends moderation.js's exact reactive-trigger + rules-checked-lock
// pattern (see that file's own header comment for the full design
// rationale — App Check + a client-direct write for the content itself,
// this trigger reacting shortly after to bump a sliding window and lock
// out further writes via a `{kind}_locked_until` field on
// `rate_limits/{uid}`) to six UGC creation paths that had ZERO rate
// limiting before this fix: posts, comments, chat messages, group
// creation, follows, and reactions/likes. Kept in its own file rather than
// added to moderation.js — same reasoning engagement_credit.js's own
// header comment gives for being separate: "a SEPARATE trigger... rather
// than extending an existing, already-shipped function — smallest correct
// change, no regression risk to a working trigger."
//
// Two collections (top-level `posts` vs gym-scoped `gyms/{gymId}/posts`,
// and their respective `comments` subcollections) share ONE budget per
// kind ('post', 'comment') — one spam budget per user, not one per
// collection a user could spam via whichever path has room left. Same for
// reactions: post reactions, post likes, and comment likes all share one
// 'reaction' budget.
//
// HONEST LIMITATION (mirrors moderation.js's own, word for word): enforcement
// is reactive, so a burst can still land up to (maxInWindow + however many
// arrive before the trigger catches up) writes before the lock actually
// engages. This bounds and blunts abuse — it does not guarantee zero-over-
// limit the way a pre-write-gating callable would.
// ─────────────────────────────────────────────────────────────────────────────

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { checkAndBumpSlidingWindow, lockUntil } = require('./rate_limit');
const { getConfig } = require('./app_config');

// Faz A Faz 4 — FALLBACK defaults; app_config/server's `moderation.*_rate_limit`
// objects are the live source once seeded (see ugcModerationConfig() below).
// These are anti-abuse thresholds — deliberately server-only in the config
// split, same reasoning as moderation.js's own report/action/appeal limits.
const POST_RATE_WINDOW_MS_DEFAULT = 10 * 60 * 1000;
const POST_RATE_MAX_IN_WINDOW_DEFAULT = 20;
const POST_LOCK_MS_DEFAULT = 15 * 60 * 1000;

const COMMENT_RATE_WINDOW_MS_DEFAULT = 10 * 60 * 1000;
const COMMENT_RATE_MAX_IN_WINDOW_DEFAULT = 30;
const COMMENT_LOCK_MS_DEFAULT = 15 * 60 * 1000;

const MESSAGE_RATE_WINDOW_MS_DEFAULT = 60 * 1000;
const MESSAGE_RATE_MAX_IN_WINDOW_DEFAULT = 30;
const MESSAGE_LOCK_MS_DEFAULT = 5 * 60 * 1000;

const GROUP_CREATE_RATE_WINDOW_MS_DEFAULT = 60 * 60 * 1000;
const GROUP_CREATE_RATE_MAX_IN_WINDOW_DEFAULT = 5;
const GROUP_CREATE_LOCK_MS_DEFAULT = 60 * 60 * 1000;

const FOLLOW_RATE_WINDOW_MS_DEFAULT = 10 * 60 * 1000;
const FOLLOW_RATE_MAX_IN_WINDOW_DEFAULT = 50;
const FOLLOW_LOCK_MS_DEFAULT = 15 * 60 * 1000;

const REACTION_RATE_WINDOW_MS_DEFAULT = 5 * 60 * 1000;
const REACTION_RATE_MAX_IN_WINDOW_DEFAULT = 100;
const REACTION_LOCK_MS_DEFAULT = 10 * 60 * 1000;

/** Live app_config/server `moderation.*` fields, or {} if unset/unreachable. */
async function ugcModerationConfig() {
  const cfg = await getConfig();
  return (cfg && cfg.moderation) || {};
}

function tripleOrDefault(live, windowDefault, maxDefault, lockDefault) {
  const isObj = live && typeof live === 'object';
  return {
    windowMs: isObj && typeof live.windowMs === 'number' ? live.windowMs : windowDefault,
    max: isObj && typeof live.max === 'number' ? live.max : maxDefault,
    lockMs: isObj && typeof live.lockMs === 'number' ? live.lockMs : lockDefault,
  };
}

/**
 * Shared core for every trigger below: bumps `kind`'s sliding window for
 * `uid` and, if over limit, locks it out. Never throws — a rate-limit
 * bookkeeping failure must not surface as an error on content that has
 * already been successfully created.
 */
async function checkAndMaybeLock(db, uid, kind, { windowMs, max, lockMs }, logContext) {
  if (!uid) return;
  try {
    const { limited, count } = await checkAndBumpSlidingWindow(db, uid, kind, windowMs, max);
    if (limited) {
      await lockUntil(db, uid, kind, lockMs);
      functions.logger.warn(`ugc_rate_limit: ${kind} rate-limited`, { uid, count, ...logContext });
    }
  } catch (e) {
    functions.logger.error(`ugc_rate_limit: ${kind} check failed`, {
      uid, error: e.message, ...logContext,
    });
  }
}

// ─── Posts ──────────────────────────────────────────────────────────────────

async function handlePostCreated(snap, logContext) {
  const authorUid = snap.data().authorId || snap.data().author_uid;
  const db = admin.firestore();
  const triple = tripleOrDefault(
    (await ugcModerationConfig()).post_rate_limit,
    POST_RATE_WINDOW_MS_DEFAULT, POST_RATE_MAX_IN_WINDOW_DEFAULT, POST_LOCK_MS_DEFAULT,
  );
  await checkAndMaybeLock(db, authorUid, 'post', triple, logContext);
}

exports.onPostCreatedForRateLimit = functions.firestore
  .document('posts/{postId}')
  .onCreate((snap, context) => handlePostCreated(snap, { postId: context.params.postId }));

exports.onGymPostCreatedForRateLimit = functions.firestore
  .document('gyms/{gymId}/posts/{postId}')
  .onCreate((snap, context) => handlePostCreated(snap, {
    gymId: context.params.gymId, postId: context.params.postId,
  }));

// ─── Comments ───────────────────────────────────────────────────────────────

async function handleCommentCreated(snap, logContext) {
  const authorUid = snap.data().authorId || snap.data().author_uid;
  const db = admin.firestore();
  const triple = tripleOrDefault(
    (await ugcModerationConfig()).comment_rate_limit,
    COMMENT_RATE_WINDOW_MS_DEFAULT, COMMENT_RATE_MAX_IN_WINDOW_DEFAULT, COMMENT_LOCK_MS_DEFAULT,
  );
  await checkAndMaybeLock(db, authorUid, 'comment', triple, logContext);
}

exports.onCommentCreatedForRateLimit = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate((snap, context) => handleCommentCreated(snap, {
    postId: context.params.postId, commentId: context.params.commentId,
  }));

exports.onGymCommentCreatedForRateLimit = functions.firestore
  .document('gyms/{gymId}/posts/{postId}/comments/{commentId}')
  .onCreate((snap, context) => handleCommentCreated(snap, {
    gymId: context.params.gymId, postId: context.params.postId, commentId: context.params.commentId,
  }));

// ─── Chat messages ──────────────────────────────────────────────────────────
// A THIRD independent trigger on this same path — index.js's
// onChatMessageCreated (unread-count fan-out) and engagement_credit.js's
// onGroupChatMessageCreatedForContribution already coexist here; Firestore
// fires every registered trigger on a path independently.

exports.onChatMessageCreatedForRateLimit = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const senderId = snap.data().senderId;
    const db = admin.firestore();
    const triple = tripleOrDefault(
      (await ugcModerationConfig()).message_rate_limit,
      MESSAGE_RATE_WINDOW_MS_DEFAULT, MESSAGE_RATE_MAX_IN_WINDOW_DEFAULT, MESSAGE_LOCK_MS_DEFAULT,
    );
    await checkAndMaybeLock(db, senderId, 'message', triple, {
      chatId: context.params.chatId, messageId: context.params.messageId,
    });
  });

// ─── Group creation ─────────────────────────────────────────────────────────

exports.onGroupCreatedForRateLimit = functions.firestore
  .document('community_groups/{groupId}')
  .onCreate(async (snap, context) => {
    const ownerUid = snap.data().owner_uid;
    const db = admin.firestore();
    const triple = tripleOrDefault(
      (await ugcModerationConfig()).group_create_rate_limit,
      GROUP_CREATE_RATE_WINDOW_MS_DEFAULT, GROUP_CREATE_RATE_MAX_IN_WINDOW_DEFAULT, GROUP_CREATE_LOCK_MS_DEFAULT,
    );
    await checkAndMaybeLock(db, ownerUid, 'group_create', triple, { groupId: context.params.groupId });
  });

// ─── Follows ────────────────────────────────────────────────────────────────
// `{uid}` in this path IS the acting follower (firestore.rules: "owner
// writes their own"), not the target being followed.

exports.onFollowCreatedForRateLimit = functions.firestore
  .document('users/{uid}/following/{targetUid}')
  .onCreate((snap, context) => {
    const db = admin.firestore();
    return (async () => {
      const triple = tripleOrDefault(
        (await ugcModerationConfig()).follow_rate_limit,
        FOLLOW_RATE_WINDOW_MS_DEFAULT, FOLLOW_RATE_MAX_IN_WINDOW_DEFAULT, FOLLOW_LOCK_MS_DEFAULT,
      );
      await checkAndMaybeLock(db, context.params.uid, 'follow', triple, {
        targetUid: context.params.targetUid,
      });
    })();
  });

// ─── Reactions / likes ──────────────────────────────────────────────────────
// Three paths, one shared 'reaction' budget: post reactions, post likes,
// comment likes. `{userId}` in each path IS the reacting/liking user
// (firestore.rules: `allow write: if isOwner(userId)`).

async function handleReactionCreated(uid, logContext) {
  const db = admin.firestore();
  const triple = tripleOrDefault(
    (await ugcModerationConfig()).reaction_rate_limit,
    REACTION_RATE_WINDOW_MS_DEFAULT, REACTION_RATE_MAX_IN_WINDOW_DEFAULT, REACTION_LOCK_MS_DEFAULT,
  );
  await checkAndMaybeLock(db, uid, 'reaction', triple, logContext);
}

exports.onPostReactionCreatedForRateLimit = functions.firestore
  .document('posts/{postId}/reactions/{userId}')
  .onCreate((snap, context) => handleReactionCreated(context.params.userId, {
    postId: context.params.postId,
  }));

exports.onPostLikeCreatedForRateLimit = functions.firestore
  .document('posts/{postId}/likes/{userId}')
  .onCreate((snap, context) => handleReactionCreated(context.params.userId, {
    postId: context.params.postId,
  }));

exports.onCommentLikeCreatedForRateLimit = functions.firestore
  .document('posts/{postId}/comments/{commentId}/likes/{userId}')
  .onCreate((snap, context) => handleReactionCreated(context.params.userId, {
    postId: context.params.postId, commentId: context.params.commentId,
  }));

// Faz A (config migration) — export names kept stable, see presence.js's
// identical comment in a sibling file.
Object.assign(module.exports, {
  POST_RATE_WINDOW_MS: POST_RATE_WINDOW_MS_DEFAULT,
  POST_RATE_MAX_IN_WINDOW: POST_RATE_MAX_IN_WINDOW_DEFAULT,
  POST_LOCK_MS: POST_LOCK_MS_DEFAULT,
  COMMENT_RATE_WINDOW_MS: COMMENT_RATE_WINDOW_MS_DEFAULT,
  COMMENT_RATE_MAX_IN_WINDOW: COMMENT_RATE_MAX_IN_WINDOW_DEFAULT,
  COMMENT_LOCK_MS: COMMENT_LOCK_MS_DEFAULT,
  MESSAGE_RATE_WINDOW_MS: MESSAGE_RATE_WINDOW_MS_DEFAULT,
  MESSAGE_RATE_MAX_IN_WINDOW: MESSAGE_RATE_MAX_IN_WINDOW_DEFAULT,
  MESSAGE_LOCK_MS: MESSAGE_LOCK_MS_DEFAULT,
  GROUP_CREATE_RATE_WINDOW_MS: GROUP_CREATE_RATE_WINDOW_MS_DEFAULT,
  GROUP_CREATE_RATE_MAX_IN_WINDOW: GROUP_CREATE_RATE_MAX_IN_WINDOW_DEFAULT,
  GROUP_CREATE_LOCK_MS: GROUP_CREATE_LOCK_MS_DEFAULT,
  FOLLOW_RATE_WINDOW_MS: FOLLOW_RATE_WINDOW_MS_DEFAULT,
  FOLLOW_RATE_MAX_IN_WINDOW: FOLLOW_RATE_MAX_IN_WINDOW_DEFAULT,
  FOLLOW_LOCK_MS: FOLLOW_LOCK_MS_DEFAULT,
  REACTION_RATE_WINDOW_MS: REACTION_RATE_WINDOW_MS_DEFAULT,
  REACTION_RATE_MAX_IN_WINDOW: REACTION_RATE_MAX_IN_WINDOW_DEFAULT,
  REACTION_LOCK_MS: REACTION_LOCK_MS_DEFAULT,
  ugcModerationConfig,
});
