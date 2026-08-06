'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 5 §5.2 — "Alınan etkileşimden AI kredisi" (credit from RECEIVED
// engagement, not given). Structurally separate from Faz 5 §5.1's XP system
// (`progress.js`) per that file's own header comment: XP rewards the client
// reporting "I just did X"; this file rewards what OTHER accounts do to
// YOUR content, entirely server-derived from real Firestore state — a
// client never reports any event this file acts on.
//
// Credit lands in the EXISTING `ai_credits/{uid}.bonus` pool
// (`entitlements.js`'s `grantBonusCredits`, already used by purchase top-ups)
// rather than a third currency — per this task's explicit instruction and
// `ai_credit_model.dart`'s own doc comment ("Bonus credits from consumable
// top-up purchases stack on top of daily limit"): this is just another
// source of the same bonus pool.
//
// ── Data model (all new; see firestore.rules for the matching guard on each) ──
//   users/{uid}/engagement_credit_events/{eventId}   immutable ledger, mirrors
//     xp_events' exact shape (`eventId = ${source}_${refId}` idempotency +
//     daily/weekly-cap-by-counting-today's-awards, see awardEngagementCredit).
//   credit_restrictions/{uid}          current shadow-restriction state,
//     mirrors ai_credits/entitlements (owner-read, admin/server-write).
//   users/{uid}/credit_moderation/{autoId}   immutable restrict/lift log,
//     mirrors community_groups/{id}/moderation's shape at account scope.
//   reciprocity_pairs/{pairKey}         fully server-only bidirectional
//     interaction counters between two uids (pairKey = sorted "a_b" join).
//   engagement_diversity/{uid}         fully server-only rolling window of
//     the last N distinct-engager uids a RECEIVER has gotten credit-worthy
//     engagement from — the closed-cluster/concentration signal's memory.
//   posts/{postId}/credit_progress/reactions
//   posts/{postId}/comments/{commentId}/credit_progress/likes
//     fully server-only per-content bookkeeping: the cached content-quality/
//     duplicate verdict (computed once, reused by every later reactor/liker
//     AND by the weekly-contribution triggers below) plus the running
//     weighted progress toward each source's distinct-account threshold.
//   community_groups/{groupId}/weekly_contributions/{weekKey}/members/{uid}
//     fully server-only per-member weekly contribution score.
//
// ── Faz 5 §5.3 additions ("Yarışma ve statü") ──────────────────────────────
//   community_groups/{groupId}/weekly_leaderboard/{weekKey}   denormalized,
//     GROUP-MEMBER-readable top-10 summary of the CURRENT week's
//     weekly_contributions ranking (`entries: [{uid, display_name,
//     photo_url, score, rank}]`) — recomputed every 15 min by
//     `computeGroupContributionLeaderboards` below. This is the "denormalized
//     public summary" the `weekly_contributions` doc comment above already
//     promised, never a widened read rule on that internal counter itself.
//   users/{uid}.group_top3_streak / .group_top3_streak_week_key   server-
//     only counter of CONSECUTIVE weeks this user placed top-3 in ANY
//     group's weekly contribution ranking — feeds the `groupStreak4` badge
//     (see `bumpGroupTop3Streak`). Field-locked in firestore.rules exactly
//     like `xp`/`level` (progress.js).
//
// See `engagement_credit_logic.js` for the anti-abuse ALGORITHMS (pure,
// unit-tested there) — this file is the orchestration: Firestore reads/
// writes, triggers, and the scheduled weekly sweep.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const logic = require('./engagement_credit_logic');
const { grantBonusCredits, isPremium } = require('./entitlements');
// Faz 5 §5.3 — `grantAchievementIfNew` for the `groupTop3`/`groupStreak4`
// badges awarded below, alongside the credit itself. Safe, one-directional
// require: `progress.js` never requires this file back (see that file's own
// header comment — its only import is `./notifications`).
const progress = require('./progress');
const { getConfig } = require('./app_config');
// Faz A Faz 4 — engagement_credit_logic.js's anti-abuse THRESHOLDS
// (content-quality, duplicate-content, reciprocity, concentration, account
// age, auto-restrict) live in app_config/server's `moderation.*` fields
// (config_schema.json groups them there, alongside the report/action/appeal
// rate limits moderation.js already reads live) — not a second namespace.
// That file is deliberately Firebase-free and can never call getConfig()
// itself (see its own header comment), so THIS orchestration layer resolves
// the live values and passes them into logic.js's pure functions as
// optional parameters, exactly like awardXp already does for points/caps.
// Reusing moderation.js's own exported helper rather than a second
// `(cfg.moderation || {})` accessor.
const { moderationConfig } = require('./moderation');

// ─── Account eligibility gate ("hesap yaşı >= 3 gün, doğrulanmış e-posta,
// gölge kısıtlama yok") — checked before ANY credit is ever awarded, for
// ANY of the four sources. `emailVerified` has no Firestore mirror anywhere
// in this codebase (confirmed: not written by firestore_service.dart or
// anywhere else) — Admin Auth is the only authoritative source, so this is
// the one place in this file that calls `admin.auth().getUser()` rather
// than reading only Firestore.
async function isAccountEligibleForCredit(db, uid) {
  try {
    const [userSnap, restrictionSnap, authUser, modCfg] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('credit_restrictions').doc(uid).get(),
      admin.auth().getUser(uid).catch(() => null),
      moderationConfig(),
    ]);
    if (!authUser || authUser.emailVerified !== true) return false;
    if (restrictionSnap.exists && restrictionSnap.data().is_shadow_restricted === true) return false;
    const createdAt = userSnap.exists ? userSnap.data().created_at : null;
    const createdMs = createdAt && createdAt.toDate ? createdAt.toDate().getTime() : null;
    const minAccountAgeMs = typeof modCfg.min_account_age_ms === 'number'
      ? modCfg.min_account_age_ms : logic.MIN_ACCOUNT_AGE_MS;
    return logic.isAccountOldEnough(createdMs, Date.now(), minAccountAgeMs);
  } catch (e) {
    // Fails CLOSED — same posture as index.js's isPremium: an infra error
    // means "we can't prove this account is eligible", not "assume yes".
    functions.logger.error('isAccountEligibleForCredit: check failed, failing closed', {
      uid, error: e.message,
    });
    return false;
  }
}

// ─── Suspicious-account tracking + shadow-restriction auto-trigger ─────────
// Bumps a rolling flag counter on `credit_restrictions/{uid}` every time
// this account's OWN behavior produced a down-weighted (reciprocity/
// concentration-flagged) engagement event or a duplicate-content block.
// Crossing AUTO_RESTRICT_FLAG_THRESHOLD flips `is_shadow_restricted` and
// writes an immutable `credit_moderation` log entry the appeal path (see
// firestore.rules' `moderation_appeals` extension) references by id.
async function bumpSuspicionFlag(db, uid, reason) {
  const ref = db.collection('credit_restrictions').doc(uid);
  let willRestrict = false;
  try {
    const modCfg = await moderationConfig();
    const autoRestrictThreshold = typeof modCfg.auto_restrict_flag_threshold === 'number'
      ? modCfg.auto_restrict_flag_threshold : logic.AUTO_RESTRICT_FLAG_THRESHOLD;
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() : {};
      if (data.is_shadow_restricted === true) return { alreadyRestricted: true };
      const nextFlagCount = (Number(data.flag_count) || 0) + 1;
      const restrictNow = logic.shouldAutoRestrict(nextFlagCount, autoRestrictThreshold);
      const update = {
        flag_count: nextFlagCount,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (restrictNow) {
        update.is_shadow_restricted = true;
        update.reason = reason;
        update.restricted_at = admin.firestore.FieldValue.serverTimestamp();
      }
      tx.set(ref, update, { merge: true });
      return { restrictNow, nextFlagCount };
    });
    willRestrict = !!result.restrictNow;
  } catch (e) {
    functions.logger.error('bumpSuspicionFlag: transaction failed', { uid, reason, error: e.message });
    return;
  }

  if (willRestrict) {
    try {
      const logRef = db.collection('users').doc(uid).collection('credit_moderation').doc();
      await logRef.set({
        action: 'restrict',
        reason,
        issued_by: 'system',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      await ref.set({ latest_entry_id: logRef.id }, { merge: true });
      functions.logger.warn('bumpSuspicionFlag: account auto-restricted', { uid, reason });
    } catch (e) {
      functions.logger.error('bumpSuspicionFlag: failed to write restrict log entry', {
        uid, reason, error: e.message,
      });
    }
  }
}

// ─── Reciprocity-pair + diversity-window bookkeeping ───────────────────────
function pairKeyFor(uidA, uidB) {
  return uidA < uidB ? `${uidA}_${uidB}` : `${uidB}_${uidA}`;
}

/**
 * Resolves live app_config/server `moderation.*` reciprocity/concentration
 * fields (or their logic.js-exported defaults) into the opts shape
 * `reciprocityWeight`/`concentrationWeight` accept. Called ONCE per
 * caller-level operation (never inside a transaction retry loop) and
 * threaded down through `prepareWeightUpdate`.
 */
function moderationWeightOpts(modCfg) {
  return {
    reciprocityOpts: {
      minPairSample: typeof modCfg.reciprocity_min_pair_sample === 'number'
        ? modCfg.reciprocity_min_pair_sample : logic.RECIPROCITY_MIN_PAIR_SAMPLE,
      ratioThreshold: typeof modCfg.reciprocity_ratio_threshold === 'number'
        ? modCfg.reciprocity_ratio_threshold : logic.RECIPROCITY_RATIO_THRESHOLD,
      downweight: typeof modCfg.reciprocity_downweight === 'number'
        ? modCfg.reciprocity_downweight : logic.RECIPROCITY_DOWNWEIGHT,
    },
    concentrationOpts: {
      windowSize: typeof modCfg.concentration_window === 'number'
        ? modCfg.concentration_window : logic.CONCENTRATION_WINDOW,
      distinctMax: typeof modCfg.concentration_distinct_max === 'number'
        ? modCfg.concentration_distinct_max : logic.CONCENTRATION_DISTINCT_MAX,
      downweight: typeof modCfg.concentration_downweight === 'number'
        ? modCfg.concentration_downweight : logic.CONCENTRATION_DOWNWEIGHT,
    },
  };
}

/**
 * Reads (via already-open transaction gets) the pairwise + diversity state
 * for one (giver -> receiver) engagement event, computes this event's
 * weight, and returns the FieldValue-bearing updates for both docs — the
 * caller applies them (`tx.set(pairRef, pairUpdate, {merge:true})` etc.)
 * inside whatever larger transaction it's already running, so a
 * source-specific doc (e.g. the per-content progress doc) can be updated
 * atomically alongside these two shared trackers.
 */
function prepareWeightUpdate({ pairSnap, diversitySnap, giverUid, receiverUid, weightOpts }) {
  const pair = pairSnap.exists ? pairSnap.data() : {};
  const isLow = giverUid < receiverUid;
  const priorGiverToReceiver = isLow ? (pair.low_to_high || 0) : (pair.high_to_low || 0);
  const priorReceiverToGiver = isLow ? (pair.high_to_low || 0) : (pair.low_to_high || 0);

  const diversity = diversitySnap.exists ? diversitySnap.data() : {};
  const recentGivers = Array.isArray(diversity.recent_givers) ? diversity.recent_givers : [];

  const weight = logic.combinedEngagementWeight({
    priorGivenGiverToReceiver: priorGiverToReceiver,
    priorGivenReceiverToGiver: priorReceiverToGiver,
    receiverRecentGivers: recentGivers,
    giverUid,
    reciprocityOpts: weightOpts.reciprocityOpts,
    concentrationOpts: weightOpts.concentrationOpts,
  });

  const pairUpdate = {
    uid_low: isLow ? giverUid : receiverUid,
    uid_high: isLow ? receiverUid : giverUid,
    [isLow ? 'low_to_high' : 'high_to_low']: admin.firestore.FieldValue.increment(1),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  const diversityUpdate = {
    recent_givers: logic.pushCappedWindow(recentGivers, giverUid, weightOpts.concentrationOpts.windowSize),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  return { weight, pairUpdate, diversityUpdate };
}

// ─── Content-quality + duplicate-content gate (cached once per content item) ─
// Faz A Faz 4 — app_config/server's `moderation.duplicate_recent_window` is
// the live source; evaluateContentEligibilityOnce/
// fetchRecentGroupMessageTexts's call sites resolve it and compute their
// own query limit (`+1`, to allow filtering out the item's own doc) from it.

async function fetchRecentAuthorTexts(db, authorUid, contentType, excludeRefId, queryLimit) {
  const snap = contentType === 'post'
    ? await db.collection('posts')
        .where('authorId', '==', authorUid)
        .orderBy('timestamp', 'desc')
        .limit(queryLimit)
        .get()
    : await db.collectionGroup('comments')
        .where('authorId', '==', authorUid)
        .orderBy('timestamp', 'desc')
        .limit(queryLimit)
        .get();
  return snap.docs
    .filter((d) => d.id !== excludeRefId)
    .map((d) => d.data().content || '');
}

/**
 * Computes (once) and caches whether ONE content item (a post or a comment)
 * is even eligible to earn its author credit — content-quality bar first
 * (cheap, no query), then near-duplicate-of-the-author's-own-recent-content
 * (one bounded query). Cached on `credit_progress` so every subsequent
 * reactor/liker event, AND the weekly-group-contribution triggers below,
 * reuse the same verdict instead of re-computing it.
 */
async function evaluateContentEligibilityOnce(db, {
  progressRef, authorUid, contentType, content, imageCount, excludeRefId,
}) {
  const snap = await progressRef.get();
  const data = snap.exists ? snap.data() : {};
  if (data.content_checked === true) return data.content_eligible === true;

  const modCfg = await moderationConfig();
  const minLength = contentType === 'post'
    ? (typeof modCfg.post_min_text_length === 'number' ? modCfg.post_min_text_length : logic.POST_MIN_TEXT_LENGTH)
    : (typeof modCfg.comment_min_text_length === 'number'
        ? modCfg.comment_min_text_length : logic.COMMENT_MIN_TEXT_LENGTH);
  const duplicateWindow = typeof modCfg.duplicate_recent_window === 'number'
    ? modCfg.duplicate_recent_window : logic.DUPLICATE_RECENT_WINDOW;
  const duplicateThreshold = typeof modCfg.duplicate_similarity_threshold === 'number'
    ? modCfg.duplicate_similarity_threshold : logic.DUPLICATE_SIMILARITY_THRESHOLD;

  const qualityOk = contentType === 'post'
    ? logic.isPostEligibleContent({ content, imageCount }, minLength)
    : logic.isCommentEligibleContent({ content }, minLength);

  let eligible = qualityOk;
  if (eligible) {
    const recentTexts = await fetchRecentAuthorTexts(db, authorUid, contentType, excludeRefId, duplicateWindow + 1);
    if (logic.isNearDuplicateText(content, recentTexts, duplicateThreshold)) {
      eligible = false;
      await bumpSuspicionFlag(db, authorUid, 'duplicate_content');
    }
  }

  await progressRef.set({ content_checked: true, content_eligible: eligible }, { merge: true });
  return eligible;
}

/** Live app_config/server `engagement.*` fields, or {} if unset/unreachable. */
async function engagementConfig() {
  const cfg = await getConfig();
  return (cfg && cfg.engagement) || {};
}

// Shared (not imported — see engagement_credit_logic.js's own comment on why
// it duplicates this rather than requiring progress.js/presence.js) with
// those two files' identical constant; config_schema.json's `gamification.
// local_utc_offset_hours` note requires all three consolidate onto this ONE
// live value.
/** Live app_config/server `gamification.local_utc_offset_hours`, or the logic.js fallback. */
async function liveLocalUtcOffsetHours() {
  const cfg = await getConfig();
  const v = cfg && cfg.gamification && cfg.gamification.local_utc_offset_hours;
  return typeof v === 'number' ? v : logic.LOCAL_UTC_OFFSET_HOURS;
}

// ─── Core award primitive — mirrors progress.js's awardXp shape/spirit ─────
/**
 * The ONLY writer of `users/{uid}/engagement_credit_events/*`. Idempotent
 * per (source, refId); enforces the daily-or-weekly cap by counting
 * already-awarded events of this source since `windowStartMs` (a bounded
 * read, `.limit(cap)` — a capped attempt is never written, so cost stays
 * proportional to real awards, exactly like awardXp's documented rationale).
 * On a real award, credits `ai_credits/{uid}.bonus` via the EXISTING
 * `grantBonusCredits` writer (`entitlements.js`) — never a parallel bonus
 * mechanism.
 *
 * `windowStartMs` scopes the DAILY-capped sources' cap-check ("since local
 * midnight today") — caller-supplied rather than derived internally so it's
 * pinned to one consistent instant across the whole call. Ignored for
 * `weekly_group_top3` — see `weekKey` below for why a time range can't work
 * for that source.
 *
 * `weekKey` is REQUIRED for `weekly_group_top3` and cap-checked by EQUALITY,
 * never a `created_at` time range: the actual award always happens AFTER
 * its target week has already closed (the sweep runs some day INTO the
 * following week), so a range like "created_at >= that week's Monday" stays
 * true forever afterward and would wrongly count THIS week's award against
 * a DIFFERENT, later target week's cap the next time this function runs (a
 * real bug caught in review — a user winning two CONSECUTIVE weeks would
 * have had their second week's award wrongly blocked as "already capped").
 * An equality match on the exact target week's key has no such drift.
 */
async function awardEngagementCredit(db, { uid, source, refId, windowStartMs, weekKey }) {
  const eligible = await isAccountEligibleForCredit(db, uid);
  if (!eligible) {
    return { ok: true, awarded: 0, capped: false, replay: false, ineligible: true };
  }

  const premiumUser = await isPremium(uid).catch(() => false);
  const eCfg = await engagementConfig();
  const creditTable = (eCfg.credit_table && typeof eCfg.credit_table === 'object')
    ? eCfg.credit_table : logic.CREDIT_TABLE;
  const cfg = logic.creditAndCapForPremium(source, premiumUser, creditTable);
  if (!cfg) throw new Error(`awardEngagementCredit: unknown source "${source}"`);
  const isWeekly = source === 'weekly_group_top3';
  const cap = isWeekly ? cfg.weeklyCap : cfg.dailyCap;
  if (isWeekly && !weekKey) throw new Error('awardEngagementCredit: weekKey is required for weekly_group_top3');

  const eventId = `${source}_${refId}`;
  const ledgerCol = db.collection('users').doc(uid).collection('engagement_credit_events');
  const eventRef = ledgerCol.doc(eventId);

  const result = await db.runTransaction(async (tx) => {
    const existing = await tx.get(eventRef);
    if (existing.exists) {
      const d = existing.data();
      return { ok: true, awarded: 0, capped: !!d.capped, replay: true };
    }

    let capped = false;
    if (typeof cap === 'number') {
      const capQuery = isWeekly
        ? ledgerCol.where('source', '==', source).where('week_key', '==', weekKey).limit(cap)
        : ledgerCol.where('source', '==', source)
            .where('created_at', '>=', admin.firestore.Timestamp.fromMillis(windowStartMs))
            .limit(cap);
      const alreadySnap = await tx.get(capQuery);
      capped = alreadySnap.size >= cap;
    }

    if (capped) {
      // Mirrors awardXp: capped attempts are deliberately never written to
      // the ledger — a rejected instance costs one bounded read, not a
      // write, and (since the underlying event here is a one-time
      // threshold-crossing / discrete acceptance / weekly ranking, not a
      // client-retriable action) is simply lost for this window rather than
      // retried later.
      return { ok: true, awarded: 0, capped: true, replay: false };
    }

    tx.set(eventRef, {
      source,
      credit: cfg.credit,
      ref_id: String(refId),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      multiplier_applied: cfg.multiplierApplied,
      ...(isWeekly ? { week_key: weekKey } : {}),
    });

    return { ok: true, awarded: cfg.credit, capped: false, replay: false };
  });

  if (result.awarded > 0) {
    await grantBonusCredits(uid, result.awarded);
    functions.logger.info('awardEngagementCredit: awarded', {
      uid, source, refId, credit: result.awarded, multiplierApplied: cfg.multiplierApplied,
    });
  }
  return result;
}

// ─── Sources 1 & 2: distinct-account reaction/like threshold ───────────────
/**
 * Shared core for both post-reactions and comment-likes: dedups the giver
 * (never counts the same uid twice for the same content item, EVEN across a
 * remove-then-redo toggle — `counted_uids` only ever grows), computes and
 * records this event's reciprocity/concentration weight, accumulates it
 * into the content's running `weighted_score`, and reports whether this
 * event just crossed the source's distinct-account threshold — all in ONE
 * transaction for atomicity with the dedup check.
 */
async function accumulateWeightedEngagement(db, { progressRef, giverUid, receiverUid, source }) {
  const pairRef = db.collection('reciprocity_pairs').doc(pairKeyFor(giverUid, receiverUid));
  const diversityRef = db.collection('engagement_diversity').doc(receiverUid);
  // Read once, outside the transaction — neither is part of this
  // transaction's retry state.
  const [eCfg, modCfg] = await Promise.all([engagementConfig(), moderationConfig()]);
  const creditTable = (eCfg.credit_table && typeof eCfg.credit_table === 'object')
    ? eCfg.credit_table : logic.CREDIT_TABLE;
  const threshold = (creditTable[source] && creditTable[source].threshold)
    || logic.CREDIT_TABLE[source].threshold;
  const weightOpts = moderationWeightOpts(modCfg);

  return db.runTransaction(async (tx) => {
    const [progressSnap, pairSnap, diversitySnap] = await Promise.all([
      tx.get(progressRef), tx.get(pairRef), tx.get(diversityRef),
    ]);
    const progress = progressSnap.exists ? progressSnap.data() : {};
    const countedUids = Array.isArray(progress.counted_uids) ? progress.counted_uids : [];
    if (countedUids.includes(giverUid)) {
      return { crossed: false, alreadyCounted: true, weight: null };
    }

    const { weight, pairUpdate, diversityUpdate } = prepareWeightUpdate({
      pairSnap, diversitySnap, giverUid, receiverUid, weightOpts,
    });

    const previousScore = Number(progress.weighted_score) || 0;
    const newScore = previousScore + weight;
    const crossed = previousScore < threshold && newScore >= threshold;

    tx.set(progressRef, {
      counted_uids: admin.firestore.FieldValue.arrayUnion(giverUid),
      weighted_score: newScore,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(pairRef, pairUpdate, { merge: true });
    tx.set(diversityRef, diversityUpdate, { merge: true });

    return { crossed, alreadyCounted: false, weight };
  });
}

async function handleDistinctAccountEngagement(db, {
  giverUid, receiverUid, source, refId, progressRef, contentType, content, imageCount, excludeRefId,
}) {
  if (!receiverUid || receiverUid === giverUid) return;

  const contentEligible = await evaluateContentEligibilityOnce(db, {
    progressRef, authorUid: receiverUid, contentType, content, imageCount, excludeRefId,
  });
  if (!contentEligible) return;

  const { crossed, weight } = await accumulateWeightedEngagement(db, {
    progressRef, giverUid, receiverUid, source,
  });

  if (weight !== null && weight < 1) {
    // Flagged as reciprocal/concentrated — both sides of the interaction are
    // complicit (the giver's engagement PATTERN looks non-organic; the
    // receiver is the one whose credit-earning attempt benefits from it).
    await Promise.all([
      bumpSuspicionFlag(db, receiverUid, 'reciprocity_or_concentration'),
      bumpSuspicionFlag(db, giverUid, 'reciprocity_or_concentration'),
    ]);
  }

  if (crossed) {
    const offsetHours = await liveLocalUtcOffsetHours();
    await awardEngagementCredit(db, {
      uid: receiverUid, source, refId, windowStartMs: logic.startOfLocalDayMs(Date.now(), offsetHours),
    });
  }
}

exports.onPostReactionCreated = functions.firestore
  .document('posts/{postId}/reactions/{userId}')
  .onCreate(async (snap, context) => {
    const { postId, userId: reactorUid } = context.params;
    const db = admin.firestore();
    try {
      const postSnap = await db.collection('posts').doc(postId).get();
      if (!postSnap.exists) return;
      const post = postSnap.data();
      const authorUid = post.authorId || (post.author && post.author.id);
      await handleDistinctAccountEngagement(db, {
        giverUid: reactorUid,
        receiverUid: authorUid,
        source: 'post_reactions',
        refId: postId,
        progressRef: db.collection('posts').doc(postId).collection('credit_progress').doc('reactions'),
        contentType: 'post',
        content: post.content,
        imageCount: Array.isArray(post.imageUrls) ? post.imageUrls.length : 0,
        excludeRefId: postId,
      });
    } catch (e) {
      functions.logger.error('onPostReactionCreated failed', { postId, reactorUid, error: e.message });
    }
  });

exports.onCommentLikeCreated = functions.firestore
  .document('posts/{postId}/comments/{commentId}/likes/{userId}')
  .onCreate(async (snap, context) => {
    const { postId, commentId, userId: likerUid } = context.params;
    const db = admin.firestore();
    try {
      const commentRef = db.collection('posts').doc(postId).collection('comments').doc(commentId);
      const commentSnap = await commentRef.get();
      if (!commentSnap.exists) return;
      const comment = commentSnap.data();
      const authorUid = comment.authorId;
      await handleDistinctAccountEngagement(db, {
        giverUid: likerUid,
        receiverUid: authorUid,
        source: 'comment_likes',
        refId: `${postId}_${commentId}`,
        progressRef: commentRef.collection('credit_progress').doc('likes'),
        contentType: 'comment',
        content: comment.content,
        imageCount: 0,
        excludeRefId: commentId,
      });
    } catch (e) {
      functions.logger.error('onCommentLikeCreated failed', {
        postId, commentId, likerUid, error: e.message,
      });
    }
  });

// ─── Source 3: template/recipe used by someone else ────────────────────────
/**
 * Called in-process from `templates.js`'s `onPlanOfferResponded` trigger,
 * on the SAME real `pending -> accepted` transition that already awards the
 * acceptor their `template_accepted` XP — that transition is the server-side
 * proof this really happened, exactly like every other server-derived §5.1
 * XP kind. Never exported as an HTTPS callable.
 *
 * No distinct-account THRESHOLD here (unlike sources 1/2) — every
 * qualifying acceptance is its own discrete, one-time credit opportunity
 * (capped per day), so the reciprocity/concentration weight is applied as a
 * binary gate instead of threshold progress: a flagged pair's acceptance
 * doesn't award a "partial" credit (that has no meaning for a one-off
 * event) — it's skipped outright, and both accounts are flagged.
 */
async function awardTemplateUsedCredit(db, { authorUid, acceptingUid, refId }) {
  if (!authorUid || !acceptingUid || authorUid === acceptingUid) return;

  const pairRef = db.collection('reciprocity_pairs').doc(pairKeyFor(acceptingUid, authorUid));
  const diversityRef = db.collection('engagement_diversity').doc(authorUid);
  const weightOpts = moderationWeightOpts(await moderationConfig());

  let weight = 1;
  try {
    weight = await db.runTransaction(async (tx) => {
      const [pairSnap, diversitySnap] = await Promise.all([tx.get(pairRef), tx.get(diversityRef)]);
      const { weight: w, pairUpdate, diversityUpdate } = prepareWeightUpdate({
        pairSnap, diversitySnap, giverUid: acceptingUid, receiverUid: authorUid, weightOpts,
      });
      tx.set(pairRef, pairUpdate, { merge: true });
      tx.set(diversityRef, diversityUpdate, { merge: true });
      return w;
    });
  } catch (e) {
    functions.logger.error('awardTemplateUsedCredit: weight transaction failed', {
      authorUid, acceptingUid, error: e.message,
    });
    return;
  }

  if (weight < 1) {
    await Promise.all([
      bumpSuspicionFlag(db, authorUid, 'reciprocity_or_concentration'),
      bumpSuspicionFlag(db, acceptingUid, 'reciprocity_or_concentration'),
    ]);
    return;
  }

  const offsetHours = await liveLocalUtcOffsetHours();
  await awardEngagementCredit(db, {
    uid: authorUid, source: 'template_used', refId, windowStartMs: logic.startOfLocalDayMs(Date.now(), offsetHours),
  });
}

// ─── Source 4: weekly group contribution top-3 ─────────────────────────────
// Per-member weekly contribution tracking, reusing computeGroupActivityScores'
// (Faz 2 §2.5) own documented weights (message x1, post x3, comment x2) for
// consistency rather than inventing a second formula — but as a flat WEEKLY
// sum (no time-decay: a clean calendar-week bucket that resets on its own,
// unlike that function's "hot right now" rolling 24h score).
// Faz A Faz 4 — FALLBACK defaults; app_config/server's `engagement.*`
// fields (see engagementConfig() above) are the live source once seeded.
const WEEKLY_MIN_ACTIVE_MEMBERS_DEFAULT = 3;
const WEEKLY_CONTRIB_GROUPS_PER_RUN_DEFAULT = 300;
const WEEKLY_TOP_N_DEFAULT = 3;
// Pulled as a ranked buffer so ineligible top-scorers can be skipped in
// favor of the next-ranked eligible member without a second query.
const WEEKLY_CANDIDATE_BUFFER_DEFAULT = 10;

function weeklyContributionRef(db, groupId, weekKey, uid) {
  return db.collection('community_groups').doc(groupId)
    .collection('weekly_contributions').doc(weekKey)
    .collection('members').doc(uid);
}

async function bumpWeeklyContribution(db, groupId, uid, points) {
  try {
    const offsetHours = await liveLocalUtcOffsetHours();
    const weekKey = logic.localWeekKey(Date.now(), offsetHours);
    await weeklyContributionRef(db, groupId, weekKey, uid).set({
      score: admin.firestore.FieldValue.increment(points),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    functions.logger.error('bumpWeeklyContribution failed', { groupId, uid, error: e.message });
  }
}

async function fetchRecentGroupMessageTexts(db, chatId, senderId, excludeMessageId, queryLimit) {
  const snap = await db.collection('chats').doc(chatId).collection('messages')
    .where('senderId', '==', senderId)
    .orderBy('server_timestamp', 'desc')
    .limit(queryLimit)
    .get();
  return snap.docs
    .filter((d) => d.id !== excludeMessageId)
    .map((d) => d.data().body || '');
}

// Message contribution: a SEPARATE trigger from onChatMessageCreated
// (index.js, unread-count fan-out) rather than extending that existing,
// already-shipped function — smallest correct change, no regression risk to
// a working trigger. Costs one extra parent-chat read per message sent
// (any chat, DMs included) before it can tell whether the chat is
// group-backed at all; bounded, same cost class computeGroupActivityScores
// already independently re-reads messages instead of hooking the existing
// trigger.
exports.onGroupChatMessageCreatedForContribution = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const { chatId, messageId } = context.params;
    const db = admin.firestore();
    try {
      const msg = snap.data();
      const senderId = msg.senderId;
      if (!senderId) return;
      const chatSnap = await db.collection('chats').doc(chatId).get();
      if (!chatSnap.exists) return;
      const groupId = chatSnap.data().groupId;
      if (!groupId) return; // DM or non-group chat — out of scope for this source

      const modCfg = await moderationConfig();
      const messageMinLength = typeof modCfg.message_min_text_length === 'number'
        ? modCfg.message_min_text_length : logic.MESSAGE_MIN_TEXT_LENGTH;
      const duplicateWindow = typeof modCfg.duplicate_recent_window === 'number'
        ? modCfg.duplicate_recent_window : logic.DUPLICATE_RECENT_WINDOW;
      const duplicateThreshold = typeof modCfg.duplicate_similarity_threshold === 'number'
        ? modCfg.duplicate_similarity_threshold : logic.DUPLICATE_SIMILARITY_THRESHOLD;

      const eligible = logic.isMessageEligibleContent({
        body: msg.body, attachmentCount: Array.isArray(msg.attachments) ? msg.attachments.length : 0,
      }, messageMinLength);
      if (!eligible) return;

      const recentTexts = await fetchRecentGroupMessageTexts(db, chatId, senderId, messageId, duplicateWindow + 1);
      if (logic.isNearDuplicateText(msg.body, recentTexts, duplicateThreshold)) {
        await bumpSuspicionFlag(db, senderId, 'duplicate_content');
        return;
      }

      await bumpWeeklyContribution(db, groupId, senderId, 1);
    } catch (e) {
      functions.logger.error('onGroupChatMessageCreatedForContribution failed', {
        chatId, messageId, error: e.message,
      });
    }
  });

// Post contribution — reuses the SAME posts/{postId}/credit_progress/reactions
// cache the reaction-credit path (source 1) uses for the content-quality/
// duplicate verdict, so a post already evaluated by one path is never
// re-evaluated by the other.
exports.onGroupPostCreatedForContribution = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const { postId } = context.params;
    const db = admin.firestore();
    try {
      const post = snap.data();
      const groupId = post.groupId;
      if (!groupId) return;
      const authorUid = post.authorId || (post.author && post.author.id);
      if (!authorUid) return;

      const progressRef = db.collection('posts').doc(postId).collection('credit_progress').doc('reactions');
      const eligible = await evaluateContentEligibilityOnce(db, {
        progressRef, authorUid, contentType: 'post',
        content: post.content,
        imageCount: Array.isArray(post.imageUrls) ? post.imageUrls.length : 0,
        excludeRefId: postId,
      });
      if (!eligible) return;

      await bumpWeeklyContribution(db, groupId, authorUid, 3);
    } catch (e) {
      functions.logger.error('onGroupPostCreatedForContribution failed', { postId, error: e.message });
    }
  });

// Comment contribution — same content-progress cache reuse as posts above,
// scoped to posts/{postId}/comments/{commentId}/credit_progress/likes (the
// same doc the comment-likes credit source, source 2, uses).
exports.onGroupCommentCreatedForContribution = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { postId, commentId } = context.params;
    const db = admin.firestore();
    try {
      const comment = snap.data();
      const authorUid = comment.authorId;
      if (!authorUid) return;
      const postSnap = await db.collection('posts').doc(postId).get();
      if (!postSnap.exists) return;
      const groupId = postSnap.data().groupId;
      if (!groupId) return;

      const progressRef = db.collection('posts').doc(postId)
        .collection('comments').doc(commentId).collection('credit_progress').doc('likes');
      const eligible = await evaluateContentEligibilityOnce(db, {
        progressRef, authorUid, contentType: 'comment', content: comment.content, imageCount: 0,
        excludeRefId: commentId,
      });
      if (!eligible) return;

      await bumpWeeklyContribution(db, groupId, authorUid, 2);
    } catch (e) {
      functions.logger.error('onGroupCommentCreatedForContribution failed', {
        postId, commentId, error: e.message,
      });
    }
  });

// ─── Faz 5 §5.3: group-contribution streak + one-time badges ──────────────
// `groupTop3` (first-ever weekly top-3 finish) and `groupStreak4` (4
// CONSECUTIVE weekly top-3 finishes, in any group — not necessarily the same
// one) are granted from THIS sweep only, never from `runSync` — the instant
// a real, server-determined weekly win happens is the only truthful moment
// to grant them.
async function bumpGroupTop3Streak(db, uid, weekKey) {
  const ref = db.collection('users').doc(uid);
  let newStreak = 0;
  try {
    newStreak = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() : {};
      const prevStreak = Number(data.group_top3_streak) || 0;
      const lastWeekKey = data.group_top3_streak_week_key || null;

      let next;
      if (lastWeekKey === weekKey) {
        // Already counted THIS week (e.g. top-3 in more than one group the
        // same week) — do not double-increment.
        next = prevStreak || 1;
      } else if (lastWeekKey === logic.previousWeekKey(weekKey)) {
        next = prevStreak + 1;
      } else {
        next = 1; // gap (or first-ever win) — streak restarts
      }

      tx.set(ref, {
        group_top3_streak: next,
        group_top3_streak_week_key: weekKey,
      }, { merge: true });
      return next;
    });
  } catch (e) {
    functions.logger.error('bumpGroupTop3Streak: transaction failed', {
      uid, weekKey, error: e.message,
    });
    return;
  }

  if (newStreak >= progress.GROUP_STREAK_ACHIEVEMENT_THRESHOLD) {
    await progress.grantAchievementIfNew(db, uid, 'groupStreak4').catch((e) => {
      functions.logger.error('bumpGroupTop3Streak: grantAchievementIfNew(groupStreak4) failed', {
        uid, error: e.message,
      });
    });
  }
}

/**
 * Weekly sweep — runs every 24h and always (re)processes the most recently
 * COMPLETED local week. Idempotent per (groupId, weekKey, winnerUid) via
 * awardEngagementCredit's own eventId, so running this daily (rather than
 * trying to land exactly on Monday 00:00) just means 6 of the 7 daily runs
 * find nothing new to do for a given group/week — cheap, safe, no reliance
 * on exact cron timing.
 *
 * Honest limitation: only the top WEEKLY_CANDIDATE_BUFFER (10) scorers per
 * group are ever considered — if more than 7 of them are ineligible
 * (age/email/shadow-restricted), fewer than 3 winners are picked that week
 * rather than paging further. Also: the global 1/week cap
 * (awardEngagementCredit counts ALL `weekly_group_top3` events regardless of
 * which group's refId they came from) means a member who's top-3 in
 * MULTIPLE groups the same week is only credited once — which group "wins"
 * depends on unordered processing order, an accepted, low-stakes tiebreak.
 */
exports.awardWeeklyGroupTop3 = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const db = admin.firestore();
    const nowMs = Date.now();
    const [eCfg, offsetHours] = await Promise.all([engagementConfig(), liveLocalUtcOffsetHours()]);
    const groupsPerRun = typeof eCfg.weekly_contrib_groups_per_run === 'number'
      ? eCfg.weekly_contrib_groups_per_run : WEEKLY_CONTRIB_GROUPS_PER_RUN_DEFAULT;
    const candidateBuffer = typeof eCfg.weekly_candidate_buffer === 'number'
      ? eCfg.weekly_candidate_buffer : WEEKLY_CANDIDATE_BUFFER_DEFAULT;
    const minActiveMembers = typeof eCfg.weekly_min_active_members === 'number'
      ? eCfg.weekly_min_active_members : WEEKLY_MIN_ACTIVE_MEMBERS_DEFAULT;
    const topN = typeof eCfg.weekly_top_n === 'number' ? eCfg.weekly_top_n : WEEKLY_TOP_N_DEFAULT;
    const lastCompletedWeekAnchorMs = logic.startOfLocalWeekMs(nowMs, offsetHours) - (7 * 86400000) + 1000;
    const weekKey = logic.localWeekKey(lastCompletedWeekAnchorMs, offsetHours);

    const groupsSnap = await db.collection('community_groups')
      .limit(groupsPerRun)
      .get();

    let groupsAwarded = 0;
    for (const groupDoc of groupsSnap.docs) {
      try {
        const membersSnap = await groupDoc.ref
          .collection('weekly_contributions').doc(weekKey)
          .collection('members')
          .orderBy('score', 'desc')
          .limit(candidateBuffer)
          .get();
        if (membersSnap.size < minActiveMembers) continue;

        const candidates = [];
        for (const m of membersSnap.docs) {
          const uid = m.id;
          // eslint-disable-next-line no-await-in-loop
          const eligible = await isAccountEligibleForCredit(db, uid);
          candidates.push({ uid, score: Number(m.data().score) || 0, eligible });
        }

        const winners = logic.pickTopNEligible(candidates, topN);
        for (const w of winners) {
          // eslint-disable-next-line no-await-in-loop
          await awardEngagementCredit(db, {
            uid: w.uid,
            source: 'weekly_group_top3',
            refId: `${groupDoc.id}_${weekKey}`,
            weekKey,
          });
          // Faz 5 §5.3 — badge cabinet: first-ever top-3 finish + the
          // consecutive-week streak counter/badge. Best-effort (awaited so
          // errors are caught per-winner below, never allowed to abort the
          // rest of this group's winners or the run).
          // eslint-disable-next-line no-await-in-loop
          await progress.grantAchievementIfNew(db, w.uid, 'groupTop3').catch((e) => {
            functions.logger.error('awardWeeklyGroupTop3: grantAchievementIfNew(groupTop3) failed', {
              uid: w.uid, error: e.message,
            });
          });
          // eslint-disable-next-line no-await-in-loop
          await bumpGroupTop3Streak(db, w.uid, weekKey);
        }
        if (winners.length > 0) groupsAwarded++;
      } catch (e) {
        functions.logger.error('awardWeeklyGroupTop3: failed for one group', {
          groupId: groupDoc.id, error: e.message,
        });
      }
    }

    functions.logger.info('awardWeeklyGroupTop3: done', {
      weekKey, groupsScanned: groupsSnap.size, groupsAwarded,
    });
  });

// ─── Faz 5 §5.3: group contribution leaderboard (denormalized, group-member-
// readable) ───────────────────────────────────────────────────────────────
// `weekly_contributions/{weekKey}/members/{uid}` above is deliberately fully
// server-only — its own doc comment already anticipated exactly this:
// "a future leaderboard UI (§5.3) would read a denormalized public summary,
// never this." This is that summary. Recomputed every 15 minutes, mirroring
// `computeGroupActivityScores`'s cadence (`functions/groups.js`) — the same
// "periodically denormalize a server-only counter for display" shape,
// reused rather than invented fresh.
//
// Deliberately reads the CURRENT (still-accumulating) local week, unlike
// `awardWeeklyGroupTop3` above (which always processes the most recently
// COMPLETED week, for awarding credit AFTER a week closes) — this is a live
// "who's winning right now" display, and the whole point, per the plan's
// own reasoning, is that members can watch their rank move DURING the week
// ("grup kullanımı artar" — group usage increases because people can see
// and chase this ranking).
// Faz A Faz 4 — FALLBACK defaults; app_config/server's `engagement.*`
// fields are the live source once seeded.
const CONTRIB_LEADERBOARD_GROUPS_PER_RUN_DEFAULT = 300; // mirrors WEEKLY_CONTRIB_GROUPS_PER_RUN_DEFAULT
const CONTRIB_LEADERBOARD_TOP_N_DEFAULT = 10; // mirrors WEEKLY_CANDIDATE_BUFFER_DEFAULT

exports.computeGroupContributionLeaderboards = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const [eCfg, offsetHours] = await Promise.all([engagementConfig(), liveLocalUtcOffsetHours()]);
    const groupsPerRun = typeof eCfg.contrib_leaderboard_groups_per_run === 'number'
      ? eCfg.contrib_leaderboard_groups_per_run : CONTRIB_LEADERBOARD_GROUPS_PER_RUN_DEFAULT;
    const topN = typeof eCfg.contrib_leaderboard_top_n === 'number'
      ? eCfg.contrib_leaderboard_top_n : CONTRIB_LEADERBOARD_TOP_N_DEFAULT;
    const weekKey = logic.localWeekKey(Date.now(), offsetHours);

    const groupsSnap = await db.collection('community_groups')
      .limit(groupsPerRun)
      .get();

    let written = 0;
    for (const groupDoc of groupsSnap.docs) {
      try {
        // eslint-disable-next-line no-await-in-loop
        const membersSnap = await groupDoc.ref
          .collection('weekly_contributions').doc(weekKey)
          .collection('members')
          .orderBy('score', 'desc')
          .limit(topN)
          .get();
        // No contributions yet this week for this group — skip the write
        // entirely (weekly_contributions only ever grows within a week, so
        // there is nothing stale to reconcile by writing an empty doc).
        if (membersSnap.empty) continue;

        const uids = membersSnap.docs.map((d) => d.id);
        const userRefs = uids.map((uid) => db.collection('users').doc(uid));
        // eslint-disable-next-line no-await-in-loop
        const userSnaps = await db.getAll(...userRefs);
        const userByUid = new Map(userSnaps.map((s) => [s.id, s.exists ? s.data() : {}]));

        const entries = membersSnap.docs.map((d, i) => {
          const u = userByUid.get(d.id) || {};
          return {
            uid: d.id,
            // users/{uid} root doc mirrors Firebase Auth in camelCase
            // (displayName/photoURL) — this NEW doc denormalizes them
            // snake_case, matching every other denormalized summary in this
            // codebase (gym/group member docs, presence docs, etc).
            display_name: u.displayName || null,
            photo_url: u.photoURL || null,
            score: Number(d.data().score) || 0,
            rank: i + 1,
          };
        });

        // eslint-disable-next-line no-await-in-loop
        await groupDoc.ref.collection('weekly_leaderboard').doc(weekKey).set({
          entries,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        written++;
      } catch (e) {
        functions.logger.error('computeGroupContributionLeaderboards: failed for one group', {
          groupId: groupDoc.id, error: e.message,
        });
      }
    }

    functions.logger.info('computeGroupContributionLeaderboards: done', {
      weekKey, groupsScanned: groupsSnap.size, written,
    });
  });

// `awardTemplateUsedCredit` — exported for in-process use by
// `templates.js`'s `onPlanOfferResponded` trigger, mirroring exactly how
// `progress.js` exports `awardXp`/`XP_TABLE` at the bottom of that file for
// the same kind of cross-module, non-callable reuse. `isAccountEligibleForCredit`/
// `bumpSuspicionFlag` are exported too for completeness / potential reuse
// elsewhere (e.g. a future admin-panel manual-restrict button — not built in
// this pass, see report) — never as HTTPS callables of their own.
exports.awardTemplateUsedCredit = awardTemplateUsedCredit;
exports.isAccountEligibleForCredit = isAccountEligibleForCredit;
exports.bumpSuspicionFlag = bumpSuspicionFlag;

// Faz A (config migration) — export names kept stable, see presence.js's
// identical comment.
Object.assign(module.exports, {
  WEEKLY_MIN_ACTIVE_MEMBERS: WEEKLY_MIN_ACTIVE_MEMBERS_DEFAULT,
  WEEKLY_CONTRIB_GROUPS_PER_RUN: WEEKLY_CONTRIB_GROUPS_PER_RUN_DEFAULT,
  WEEKLY_TOP_N: WEEKLY_TOP_N_DEFAULT,
  WEEKLY_CANDIDATE_BUFFER: WEEKLY_CANDIDATE_BUFFER_DEFAULT,
  CONTRIB_LEADERBOARD_GROUPS_PER_RUN: CONTRIB_LEADERBOARD_GROUPS_PER_RUN_DEFAULT,
  CONTRIB_LEADERBOARD_TOP_N: CONTRIB_LEADERBOARD_TOP_N_DEFAULT,
  engagementConfig,
});
