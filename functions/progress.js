'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authoritative achievements + reputation (audit N2/Faz-0 §0.4).
//
// Both used to be computed AND written entirely client-side
// (AchievementService.earn → users/{uid}/achievements/{key},
// ReputationService._cacheScore → users/{uid}.reputation_score) under a bare
// owner-write rule — any authenticated user could self-grant any badge or
// set their own reputation_score directly. firestore.rules now denies both
// client writes unconditionally; this file is the only writer.
//
// The client still reports WHICH momentary event just happened
// (justLoggedMeal/justLoggedPhoto/justPosted/justCookedAndLogged) — that's a
// deliberately low-stakes, honestly-documented trust boundary: these four
// gate only cosmetic first-time badges with no economic value, and food_logs
// docs don't persist a queryable "was this from a photo/recipe" field today,
// so the server can't independently re-derive them without a schema change
// (tracked separately, not this fix's scope). What the server DOES always
// independently re-derive, never trusting a client-supplied number: the
// user's own stored streak and a real post-count aggregation — so the
// streak- and reputation-tier-based badges (and the score itself) are fully
// server-truth. Event flags are also only honoured for the CALLER's own
// uid — viewing someone else's profile can refresh their cached
// reputation/tier badges (derived from their own already-public streak +
// post count, same as before) but can never self-report an event on their
// behalf.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable } = require('./notifications');

const REPUTATION_POINTS_PER_STREAK_DAY = 2;
const REPUTATION_POINTS_PER_POST = 5;

// Ascending order — index comparison below relies on this.
const TIER_ORDER = ['newcomer', 'active', 'contributor', 'expert', 'legend'];
const TIER_THRESHOLDS = { newcomer: 0, active: 50, contributor: 150, expert: 350, legend: 700 };
const TIER_ACHIEVEMENT_KEY = {
  active: 'tierActive', contributor: 'tierContributor',
  expert: 'tierExpert', legend: 'tierLegend',
};

function tierFromScore(score) {
  let tier = 'newcomer';
  for (const t of TIER_ORDER) {
    if (score >= TIER_THRESHOLDS[t]) tier = t;
  }
  return tier;
}

/**
 * Shared core: re-derives streak/postCount/score/tier from truth, folds in
 * whichever self-reported event flags apply, and writes everything in one
 * batch. Used by both `syncProgress` (normal per-action sync) and
 * `backfillProgress` (one-time catch-up for existing users).
 *
 * @param {string} targetUid whose progress to sync
 * @param {boolean} isSelf whether the caller IS targetUid (gates event flags)
 * @param {object} eventFlags {justLoggedMeal, justLoggedPhoto, justPosted, justCookedAndLogged}
 */
async function runSync(targetUid, isSelf, eventFlags) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(targetUid);
  const achievementsRef = userRef.collection('achievements');

  const [userSnap, earnedSnap, postCountSnap] = await Promise.all([
    userRef.get(),
    achievementsRef.get(),
    db.collection('posts').where('authorId', '==', targetUid).count().get(),
  ]);
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'user doc missing');
  }

  const userData = userSnap.data();
  const streak = (userData.onboarding_data && Number(userData.onboarding_data.streak)) || 0;
  const postCount = postCountSnap.data().count || 0;
  const earned = new Set(earnedSnap.docs.map((d) => d.id));

  const score = streak * REPUTATION_POINTS_PER_STREAK_DAY + postCount * REPUTATION_POINTS_PER_POST;
  const tier = tierFromScore(score);

  const toGrant = [];

  if (isSelf && eventFlags) {
    if (eventFlags.justLoggedMeal === true && !earned.has('firstMealLogged')) {
      toGrant.push('firstMealLogged');
    }
    if (eventFlags.justLoggedPhoto === true && !earned.has('firstPhotoLog')) {
      toGrant.push('firstPhotoLog');
    }
    if (eventFlags.justPosted === true && !earned.has('firstPost')) {
      toGrant.push('firstPost');
    }
    if (eventFlags.justCookedAndLogged === true && !earned.has('firstCook')) {
      toGrant.push('firstCook');
    }
  }

  // Streak- and tier-based badges — always re-derived from server truth,
  // regardless of who triggered this sync.
  if (streak >= 7 && !earned.has('streak7')) toGrant.push('streak7');
  if (streak >= 30 && !earned.has('streak30')) toGrant.push('streak30');
  if (streak >= 100 && !earned.has('streak100')) toGrant.push('streak100');

  const tierIdx = TIER_ORDER.indexOf(tier);
  for (const [tKey, achKey] of Object.entries(TIER_ACHIEVEMENT_KEY)) {
    if (tierIdx >= TIER_ORDER.indexOf(tKey) && !earned.has(achKey)) {
      toGrant.push(achKey);
    }
  }

  const batch = db.batch();
  batch.set(userRef, {
    reputation_score: score,
    reputation_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  for (const key of toGrant) {
    batch.set(achievementsRef.doc(key), {
      earned_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  return { score, tier, granted: toGrant };
}

exports.syncProgress = functions.https.onCall(async (data, context) => {
  const callerUid = assertCallable(context);
  const targetUid = (data && typeof data.targetUid === 'string' && data.targetUid) || callerUid;
  return runSync(targetUid, targetUid === callerUid, data || {});
});

/** One-time catch-up for existing users — grants whatever they already
 * qualify for based on data that predates this system. */
exports.backfillProgress = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const db = admin.firestore();

  const [mealLogSnap, postsSnap] = await Promise.all([
    db.collection('users').doc(uid).collection('food_logs').limit(1).get(),
    db.collection('posts').where('authorId', '==', uid).limit(1).get(),
  ]);

  return runSync(uid, true, {
    justLoggedMeal: !mealLogSnap.empty,
    justPosted: !postsSnap.empty,
  });
});
