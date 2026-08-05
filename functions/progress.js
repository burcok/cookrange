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
//
// ─── Faz 5 §5.1 — XP backbone ──────────────────────────────────────────────
//
// `users/{uid}.xp`/`.level`/`.level_updated_at` are server-write-only (same
// pattern as `reputation_score` above) and `users/{uid}/xp_events/{eventId}`
// is an immutable ledger — `eventId` is the idempotency key (deterministic
// `${kind}_${refId}`), so a client retry of the exact same instance always
// replays the stored outcome instead of re-awarding, and a NEW distinct
// instance beyond a kind's daily cap is rejected by counting today's
// already-awarded events of that kind (a bounded read, `.limit(dailyCap)`).
//
// Trust model per kind — "the client reports WHICH event happened, the
// server decides whether it's real and how many points it's worth, NEVER a
// client-supplied point value" (points/caps below are a fixed, server-owned
// table — `XP_TABLE` — never read off the request):
//   - meal_logged / recipe_cooked / post_created / comment_created /
//     reaction_given: client-reported via `syncProgress`'s `xpEvents` array,
//     but the referenced doc's EXISTENCE + OWNERSHIP is independently
//     verified here (`verifyClientXpEvent`) before anything is awarded — a
//     fabricated refId is rejected outright, awarding nothing. What is NOT
//     independently re-derivable is which SPECIFIC flavor a food_logs doc
//     represents (plain / photo / recipe) — food_logs has no queryable
//     field for that today, the exact same pre-existing, already-accepted
//     gap the justLoggedPhoto/justCookedAndLogged achievement flags above
//     already carry. Not this task's schema change.
//   - streak_day: NEVER client-reported at all — awarded unconditionally
//     inside `runSync` from the same server-stored `onboarding_data.streak`
//     the streak achievements above already trust, gated only by the
//     eventId (`streak_day_<local-date>`) so it fires at most once per
//     calendar day no matter how many times `runSync` runs that day.
//   - check_in: NEVER client-reported — awarded directly by `presence.js`'s
//     `closeSession` and `gym.js`'s `validateGymCheckin`, in-process, right
//     after EACH already writes its own server-verified `checkins/*` doc.
//     Zero additional client trust beyond what Faz 1 already established.
//   - template_accepted: NEVER client-reported — awarded directly by
//     `templates.js`'s `onPlanOfferResponded` trigger, which only ever fires
//     on a REAL Firestore state transition already gated by
//     `firestore.rules` (`pending` -> `accepted`, recipient-owned, exactly
//     once).
//   - achievement_earned: NEVER client-reported — awarded inside `runSync`'s
//     own grant loop, the instant a key is newly earned, using that
//     achievement's own catalog point value (`kAchievementCatalog` in Dart;
//     mirrored here as `ACHIEVEMENT_POINTS` since Cloud Functions can't
//     import the Flutter `lib/` catalog directly).
//
// XP has NO monetary equivalent anywhere in this file — it is never
// converted to AI credits, premium, or any purchasable entitlement. That is
// a deliberate design property from the plan (§5.1: "spam'in getirisi yok" —
// spam has no payoff), not an oversight to fix later. `multiplier_applied`
// is part of the ledger schema (per the plan's exact data model) but always
// `1` in this phase — a premium XP multiplier would contradict "premium XP
// kazandırmaz" (§5.3); the field only exists so §5.2's separate,
// premium-multiplied received-engagement credit system doesn't need a
// schema migration later.
//
// Level curve: increasing-interval triangular numbers, mirrored exactly in
// `lib/core/utils/xp_level_curve.dart` (full derivation/rationale there —
// this copy is the AUTHORITATIVE one, the Dart copy only renders a
// client-side progress bar off an already-server-written `xp` number).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable, writeNotification } = require('./notifications');
const { localWeekKey } = require('./engagement_credit_logic');

// ─── XP table (Faz 5 §5.1) ──────────────────────────────────────────────────
// Fixed, server-owned points + daily caps. A client can name a KIND; it can
// never name a point value or a cap.
const XP_TABLE = {
  meal_logged: { points: 5, dailyCap: 4 },
  streak_day: { points: 10, dailyCap: 1 },
  check_in: { points: 15, dailyCap: 1 },
  post_created: { points: 20, dailyCap: 2 },
  comment_created: { points: 5, dailyCap: 10 },
  reaction_given: { points: 1, dailyCap: 20 },
  recipe_cooked: { points: 25, dailyCap: 2 },
  template_accepted: { points: 30, dailyCap: null },
};

// Kinds a CLIENT payload may ever name via syncProgress's `xpEvents` array.
// streak_day/check_in/template_accepted/achievement_earned are granted
// exclusively from server-derived triggers elsewhere (see header comment)
// and are silently dropped if a client tries to name them here — see
// `sanitizeXpEvent`.
const CLIENT_REPORTABLE_XP_KINDS = new Set([
  'meal_logged', 'recipe_cooked', 'post_created', 'comment_created', 'reaction_given',
]);
const MAX_XP_EVENTS_PER_CALL = 10;

// Mirrors lib/core/models/achievement_model.dart's kAchievementCatalog
// `points` column. Cloud Functions can't import Flutter's lib/, so this is a
// deliberate, small, hand-kept-in-sync duplicate (11 entries, changes
// rarely) — used ONLY to size the XP award the instant an achievement is
// newly granted below.
// Faz 5 §5.3: four new badges layered on top of the original 11 — XP/level,
// group-contribution, and gym-presence themed, per the plan's "rozet
// dolabı" bullet. Same catalog, same writer (`runSync`'s grant loop below /
// `grantAchievementIfNew`), never a second catalog.
const ACHIEVEMENT_POINTS = {
  firstMealLogged: 10,
  firstPhotoLog: 15,
  firstPost: 10,
  firstCook: 20,
  streak7: 30,
  streak30: 75,
  streak100: 200,
  tierActive: 20,
  tierContributor: 50,
  tierExpert: 100,
  tierLegend: 250,
  level50: 300,
  groupTop3: 40,
  groupStreak4: 120,
  gymRegular: 60,
};

// `gymRegular`'s threshold — "presence-themed" per §5.3: a real-world,
// repeated gym-visit milestone, independent of the tier/streak ladder above.
// Counted from `xp_events` where `kind == 'check_in'` (server-truth: every
// check_in XP award already independently proves a REAL, server-verified
// check-in happened — presence.js's closeSession / gym.js's
// validateGymCheckin are the only two callers of awardXp('check_in', ...),
// see this file's header comment) rather than a separate counter field.
const GYM_REGULAR_CHECKIN_THRESHOLD = 15;

// `groupStreak4`'s threshold (consecutive WEEKS in a group's weekly top-3
// contribution ranking) — mirrored here only for documentation/consistency;
// the actual streak counter/increment logic lives in `engagement_credit.js`
// (`bumpGroupTop3Streak`), since it's driven by `awardWeeklyGroupTop3`'s own
// sweep, not by `runSync`. Kept here too so both files show the same number
// at a glance rather than a magic `4` appearing unexplained in only one.
const GROUP_STREAK_ACHIEVEMENT_THRESHOLD = 4;

// Turkey has used a fixed UTC+3 offset with no DST since 2016 (mirrors the
// identical constant/comment in presence.js — this app's only real market
// today). Daily XP caps reset at LOCAL midnight, not UTC midnight.
const LOCAL_UTC_OFFSET_HOURS = 3;

function startOfLocalDay() {
  const localNow = new Date(Date.now() + LOCAL_UTC_OFFSET_HOURS * 3600000);
  const localMidnightUtcMs = Date.UTC(
    localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate(),
  );
  return admin.firestore.Timestamp.fromMillis(localMidnightUtcMs - LOCAL_UTC_OFFSET_HOURS * 3600000);
}

/** `YYYY-MM-DD` in local (Turkey) time — the `streak_day` idempotency key material. */
function localDateKey() {
  const localNow = new Date(Date.now() + LOCAL_UTC_OFFSET_HOURS * 3600000);
  return localNow.toISOString().slice(0, 10);
}

// ─── Level curve — see xp_level_curve.dart for the full derivation ─────────
const LEVEL_CURVE_COEFFICIENT = 50;
const MAX_LEVEL = 999;

function xpThresholdForLevel(level) {
  const n = level < 1 ? 1 : level;
  return LEVEL_CURVE_COEFFICIENT * n * (n - 1);
}

function levelForXp(xp) {
  if (xp <= 0) return 1;
  let level = 1;
  while (level < MAX_LEVEL && xpThresholdForLevel(level + 1) <= xp) level++;
  return level;
}

// Ascending order — index comparison below relies on this.
const TIER_ORDER = ['newcomer', 'active', 'contributor', 'expert', 'legend'];
// Faz 5 §5.1 migration: ReputationTier now derives from LEVEL BANDS, not the
// old `streak*2 + postCount*5` formula — that formula and its score-cutoff
// thresholds are deleted outright ("no two parallel score systems survive
// this task"). Bands chosen to roughly mirror the old formula's relative
// spacing (each tier roughly doubling in width): newcomer covers the first
// couple of weeks of casual use (below level 5), "legend" is a genuine
// long-haul milestone (level 35 is ~a year of engaged use, or ~10 months of
// daily heavy use — see xp_level_curve.dart's pacing comment).
const TIER_LEVEL_FLOOR = { newcomer: 1, active: 5, contributor: 10, expert: 20, legend: 35 };
const TIER_ACHIEVEMENT_KEY = {
  active: 'tierActive', contributor: 'tierContributor',
  expert: 'tierExpert', legend: 'tierLegend',
};

function tierFromLevel(level) {
  let tier = 'newcomer';
  for (const t of TIER_ORDER) {
    if (level >= TIER_LEVEL_FLOOR[t]) tier = t;
  }
  return tier;
}

/**
 * Core XP-award primitive (Faz 5 §5.1) — the ONLY place
 * `users/{uid}.xp`/`.level`/`.level_updated_at` are ever written, and the
 * ONLY writer of `users/{uid}/xp_events/*`. See this file's top comment for
 * the full trust-model breakdown per kind.
 *
 * Idempotent per (kind, refId): `eventId = ${kind}_${refId}` is the ledger
 * doc's own id, so retrying the exact same instance always replays the
 * already-stored outcome rather than re-awarding. `dailyCap` (null =
 * uncapped) is enforced by counting today's ALREADY-AWARDED events of this
 * kind — capped (zero-point) attempts are deliberately never written to the
 * ledger at all, so a rejected attempt costs one bounded read, not a write;
 * a client retry storm of brand-new distinct refIds beyond the cap keeps
 * hitting the same true count and keeps getting rejected. (Known, accepted
 * edge case: a capped attempt retried after a day boundary rolls over WOULD
 * award on that retry, crediting the new day for an instant that actually
 * happened the day before — low-stakes given XP has no monetary equivalent,
 * and rare in practice since every call site reports this immediately after
 * the local action, not on a delay.)
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @param {string} kind an `XP_TABLE` key, or `'achievement_earned'`
 * @param {string} refId idempotency key material — must uniquely identify
 *   THIS instance of `kind` (e.g. the food_logs doc id, the achievement key,
 *   a synthesized per-day date string for `streak_day`)
 * @param {number} points fixed award for this instance — ALWAYS server-
 *   decided (`XP_TABLE` / `ACHIEVEMENT_POINTS`), never taken from a request
 * @param {number|null} dailyCap null = uncapped
 * @returns {Promise<{ok: true, awarded: number, capped: boolean, replay: boolean, xp: number, level: number, leveledUp: boolean, previousLevel: number}>}
 */
async function awardXp(db, uid, kind, refId, points, dailyCap) {
  const userRef = db.collection('users').doc(uid);
  const eventId = `${kind}_${refId}`;
  const eventRef = userRef.collection('xp_events').doc(eventId);

  const result = await db.runTransaction(async (tx) => {
    const existingEventSnap = await tx.get(eventRef);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.exists ? userSnap.data() : {};
    // First-touch migration: a user who predates this system has no `xp`
    // field yet — seed it from their old `reputation_score` (streak*2 +
    // postCount*5) rather than resetting them to 0, so standing carries
    // over instead of a visible regression. Only ever consulted once —
    // the moment `xp` exists as a real number, this fallback never fires
    // again for that user.
    const previousXp = typeof userData.xp === 'number'
      ? userData.xp
      : (Number(userData.reputation_score) || 0);
    const previousLevel = levelForXp(previousXp);

    if (existingEventSnap.exists) {
      const d = existingEventSnap.data();
      return {
        ok: true, awarded: d.points || 0, capped: !!d.capped, replay: true,
        xp: previousXp, level: previousLevel, leveledUp: false, previousLevel,
      };
    }

    let capped = false;
    if (dailyCap !== null && dailyCap !== undefined) {
      const todaySnap = await tx.get(
        userRef.collection('xp_events')
          .where('kind', '==', kind)
          .where('created_at', '>=', startOfLocalDay())
          .limit(dailyCap),
      );
      capped = todaySnap.size >= dailyCap;
    }

    if (capped) {
      return {
        ok: true, awarded: 0, capped: true, replay: false,
        xp: previousXp, level: previousLevel, leveledUp: false, previousLevel,
      };
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const newXp = previousXp + points;
    const newLevel = levelForXp(newXp);
    const leveledUp = newLevel > previousLevel;

    tx.set(eventRef, {
      kind, points, ref_id: String(refId), created_at: now, multiplier_applied: 1,
    });
    tx.set(userRef, {
      xp: newXp, level: newLevel,
      ...(leveledUp ? { level_updated_at: now } : {}),
    }, { merge: true });

    // Faz 5 §5.3 weekly community/gym leaderboard rollup — denormalized
    // sibling write, same transaction so it can never drift from the XP
    // grant above. `community_weekly_xp/{weekKey}/members/{uid}` is read by
    // `LeaderboardService.getWeeklyXpLeaderboardStream` (community-wide) and
    // `GymLeaderboardService._fetchWeeklyXp` (per-gym) — see
    // firestore.rules' own comment on this collection, which already
    // documented this exact shape (displayName/photoURL reused from the
    // userSnap read just above, no extra read needed) before this write
    // existed to match it. `localWeekKey` (functions/engagement_credit_logic.js)
    // is the SAME Monday-anchored key `LocalWeek.key()` computes client-side
    // — must stay byte-identical between the two.
    const weekKey = localWeekKey(Date.now());
    const weeklyXpRef = db.collection('community_weekly_xp').doc(weekKey)
      .collection('members').doc(uid);
    tx.set(weeklyXpRef, {
      xp: admin.firestore.FieldValue.increment(points),
      display_name: userData.displayName || null,
      photo_url: userData.photoURL || null,
      updated_at: now,
    }, { merge: true });

    return {
      ok: true, awarded: points, capped: false, replay: false,
      xp: newXp, level: newLevel, leveledUp, previousLevel,
    };
  });

  if (result.leveledUp) {
    // Celebration hook (§5.1: "her seviye atlamada kutlama") — reuses the
    // EXISTING notification pipeline verbatim (writeNotification ->
    // notifications/{uid}/items, onInAppNotificationCreated already fans
    // this out to push), the same mechanism achievementEarned/
    // streakMilestone/gymWarEnded already use. No confetti/animation
    // library exists anywhere in this codebase (checked pubspec.yaml + a
    // repo-wide search) — the notification IS the established celebration
    // primitive here, not a fallback for lacking one. A profile-facing
    // level chip is the "+ profil çipi" half (ProfileScreen's
    // `_buildLevelBadge`, sourced straight from `users/{uid}.level`).
    await writeNotification(db, {
      targetUid: uid,
      type: 'levelUp',
      metadata: { level: result.level, xp: result.xp },
    }).catch((e) => functions.logger.error('awardXp: levelUp notification failed', {
      uid, level: result.level, error: e.message,
    }));
  }

  return result;
}

/**
 * Grants ONE achievement key if the user hasn't already earned it —
 * idempotent (checked via a plain doc read, not a transaction: the caller
 * is always either `runSync`'s own single-user batch, which already holds
 * `earned` in memory, or an external server-derived trigger like
 * `awardWeeklyGroupTop3`, which only ever calls this once per (uid, key)
 * per run — a double-grant race would at worst re-run `awardXp`, which is
 * itself idempotent via `eventId = achievement_earned_<key>`, so this is
 * belt-and-suspenders safe even without a transaction here).
 *
 * Exists as a narrow, standalone primitive — NOT routed through the full
 * `runSync` — because some new Faz 5 §5.3 badges (`groupTop3`,
 * `groupStreak4`) are earned from a SCHEDULED sweep (`engagement_credit.js`'s
 * `awardWeeklyGroupTop3`), not from a live `syncProgress` call a user is
 * making right now; re-running the user's entire streak/tier/XP re-sync
 * just to grant one unrelated badge would be wasteful and, worse, would
 * require that scheduled sweep to fabricate `eventFlags`/`isSelf` context
 * it doesn't have.
 *
 * @returns {Promise<boolean>} true if this call newly granted it, false if
 *   already earned (never throws for "already earned" — that's the normal,
 *   expected case on every call after the first)
 */
async function grantAchievementIfNew(db, uid, key) {
  const ref = db.collection('users').doc(uid).collection('achievements').doc(key);
  const snap = await ref.get();
  if (snap.exists) return false;

  await ref.set({ earned_at: admin.firestore.FieldValue.serverTimestamp() });
  const pts = ACHIEVEMENT_POINTS[key] || 0;
  if (pts > 0) {
    await awardXp(db, uid, 'achievement_earned', key, pts, null);
  }
  return true;
}

/**
 * Independently verifies a CLIENT-reported xp event actually corresponds to
 * a real doc the caller owns, before any points are decided — closes the
 * "fabricated refId" attack the daily-cap/idempotency scheme alone wouldn't
 * stop (a bot could otherwise mint arbitrary fresh refIds forever). Does
 * NOT (and per this file's header comment, currently CANNOT) verify which
 * semantic FLAVOR of an action happened (e.g. "was this specific food_logs
 * doc really a recipe cook") — only that the referenced doc is real and
 * owned by this uid. See the header comment for why that gap is accepted.
 */
async function verifyClientXpEvent(db, uid, event) {
  switch (event.kind) {
    case 'meal_logged':
    case 'recipe_cooked': {
      const snap = await db.collection('users').doc(uid)
        .collection('food_logs').doc(event.refId).get();
      return snap.exists;
    }
    case 'post_created': {
      const snap = await db.collection('posts').doc(event.refId).get();
      return snap.exists && snap.data().authorId === uid;
    }
    case 'comment_created': {
      const snap = await db.collection('posts').doc(event.postId)
        .collection('comments').doc(event.refId).get();
      return snap.exists && snap.data().authorId === uid;
    }
    case 'reaction_given': {
      const parentRef = event.commentId
        ? db.collection('posts').doc(event.postId).collection('comments').doc(event.commentId)
        : db.collection('posts').doc(event.postId);
      const snap = await parentRef.collection('reactions').doc(uid).get();
      if (!snap.exists) return false;
      const d = snap.data();
      const emojis = Array.isArray(d.emojis) ? d.emojis : (d.emoji ? [d.emoji] : []);
      return emojis.includes(event.emoji);
    }
    default:
      return false;
  }
}

/**
 * Validates one raw `xpEvents[]` request entry. Returns null (silently
 * dropped by the caller, never throws — one bad entry shouldn't fail the
 * rest of a syncProgress call) unless the shape is exactly right for its
 * `kind`. `reaction_given` has no natural doc id of its own (a reaction
 * TOGGLE isn't a doc creation), so its idempotency-key material is
 * synthesized from (postId, commentId, emoji) rather than taking a
 * client-supplied `refId` at all.
 */
function sanitizeXpEvent(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const kind = typeof raw.kind === 'string' ? raw.kind : '';
  if (!CLIENT_REPORTABLE_XP_KINDS.has(kind)) return null;

  const postId = typeof raw.postId === 'string' && raw.postId ? raw.postId : null;
  const commentId = typeof raw.commentId === 'string' && raw.commentId ? raw.commentId : null;
  const emoji = typeof raw.emoji === 'string' && raw.emoji ? raw.emoji : null;
  const refId = typeof raw.refId === 'string' && raw.refId ? raw.refId : null;

  if (kind === 'reaction_given') {
    if (!postId || !emoji) return null;
    return { kind, postId, commentId, emoji, refId: `${postId}_${commentId || 'p'}_${emoji}` };
  }
  if (kind === 'comment_created') {
    if (!postId || !refId) return null;
    return { kind, postId, refId };
  }
  if (!refId) return null;
  return { kind, refId };
}

/**
 * Shared core: re-derives streak/tier/XP-level from truth, folds in
 * whichever self-reported event flags/xp events apply, and writes everything
 * (achievements + the reputation_score mirror) in one batch, plus whatever
 * XP awards ran via their own transactions. Used by both `syncProgress`
 * (normal per-action sync) and `backfillProgress` (one-time catch-up for
 * existing users).
 *
 * @param {string} targetUid whose progress to sync
 * @param {boolean} isSelf whether the caller IS targetUid (gates event flags/xpEvents)
 * @param {object} eventFlags {justLoggedMeal, justLoggedPhoto, justPosted, justCookedAndLogged, xpEvents}
 */
async function runSync(targetUid, isSelf, eventFlags) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(targetUid);
  const achievementsRef = userRef.collection('achievements');

  const [userSnap, earnedSnap] = await Promise.all([
    userRef.get(),
    achievementsRef.get(),
  ]);
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'user doc missing');
  }

  const userData = userSnap.data();
  const streak = (userData.onboarding_data && Number(userData.onboarding_data.streak)) || 0;
  const earned = new Set(earnedSnap.docs.map((d) => d.id));

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

  // Streak-based badges — always re-derived from server truth, regardless
  // of who triggered this sync. Tier-based badges are appended further
  // below, once the post-XP-award tier is known.
  if (streak >= 7 && !earned.has('streak7')) toGrant.push('streak7');
  if (streak >= 30 && !earned.has('streak30')) toGrant.push('streak30');
  if (streak >= 100 && !earned.has('streak100')) toGrant.push('streak100');

  // ─── Faz 5 §5.1: XP awards ────────────────────────────────────────────
  // Tracks the latest known xp/level as awards run — starts from whatever
  // is already stored (or the first-touch reputation_score fallback,
  // resolved fresh inside each awardXp call) and is overwritten by every
  // award below, so the final response/mirror always reflects the true
  // end state of this sync, not a stale snapshot from before it ran.
  let latestXp = typeof userData.xp === 'number' ? userData.xp : (Number(userData.reputation_score) || 0);
  let latestLevel = levelForXp(latestXp);
  let leveledUpThisSync = false;
  const xpAwarded = [];

  async function applyAward(kind, refId, points, dailyCap) {
    try {
      const r = await awardXp(db, targetUid, kind, refId, points, dailyCap);
      latestXp = r.xp;
      latestLevel = r.level;
      if (r.leveledUp) leveledUpThisSync = true;
      xpAwarded.push({ kind, refId, awarded: r.awarded, capped: r.capped });
    } catch (e) {
      functions.logger.error('runSync: awardXp failed for one event', {
        targetUid, kind, refId, error: e.message,
      });
    }
  }

  // Client-reported instantaneous actions — isSelf-gated exactly like the
  // four achievement event flags above (a client can only ever report an
  // event for ITSELF, never on behalf of a profile it merely views).
  if (isSelf && eventFlags && Array.isArray(eventFlags.xpEvents)) {
    for (const raw of eventFlags.xpEvents.slice(0, MAX_XP_EVENTS_PER_CALL)) {
      const event = sanitizeXpEvent(raw);
      if (!event) continue;
      const verified = await verifyClientXpEvent(db, targetUid, event).catch(() => false);
      if (!verified) {
        functions.logger.warn('runSync: xp event failed verification, skipping', {
          targetUid, kind: event.kind, refId: event.refId,
        });
        continue;
      }
      const table = XP_TABLE[event.kind];
      await applyAward(event.kind, event.refId, table.points, table.dailyCap);
    }
  }

  // Streak day — NEVER client-reported (see header comment). Always
  // re-derived from the same server-stored streak the achievements above
  // already trust, regardless of who triggered this sync; the eventId
  // (`streak_day_<local date>`) alone enforces the 1/day cap.
  if (streak > 0) {
    const t = XP_TABLE.streak_day;
    await applyAward('streak_day', localDateKey(), t.points, t.dailyCap);
  }

  // Tier now derives from the POST-award level (Faz 5 §5.1 migration).
  const tier = tierFromLevel(latestLevel);
  const tierIdx = TIER_ORDER.indexOf(tier);
  for (const [tKey, achKey] of Object.entries(TIER_ACHIEVEMENT_KEY)) {
    if (tierIdx >= TIER_ORDER.indexOf(tKey) && !earned.has(achKey)) {
      toGrant.push(achKey);
    }
  }

  // ─── Faz 5 §5.3: new XP/presence-themed badges ──────────────────────────
  // `level50` — a genuine milestone BEYOND the tier ladder above (`legend`
  // tops out at level 35), re-derived from the same post-award `latestLevel`
  // just computed — zero extra reads.
  if (latestLevel >= 50 && !earned.has('level50')) {
    toGrant.push('level50');
  }

  // `gymRegular` — guarded by `!earned.has(...)` FIRST so the one-time
  // aggregation read below is only ever paid by users who haven't earned it
  // yet (never again afterward); `count()` aggregation queries are billed
  // per 1000 matched docs, not per doc, so this stays cheap even for a
  // heavy gym-goer. Re-derives from `xp_events` (server-truth: every
  // `check_in`-kind event already independently proves a real, server-
  // verified check-in — see this file's header comment) rather than
  // trusting any client-supplied visit count.
  if (!earned.has('gymRegular')) {
    const checkInAgg = await userRef.collection('xp_events')
      .where('kind', '==', 'check_in')
      .count()
      .get();
    if ((checkInAgg.data().count || 0) >= GYM_REGULAR_CHECKIN_THRESHOLD) {
      toGrant.push('gymRegular');
    }
  }

  // Achievement-earned XP — NEVER client-reported. Awarded the instant a
  // key is newly granted, using that achievement's own catalog point value;
  // uncapped (idempotent forever via eventId = achievement_earned_<key>,
  // and an achievement is only ever granted once per user regardless).
  for (const key of toGrant) {
    const pts = ACHIEVEMENT_POINTS[key] || 0;
    if (pts > 0) {
      await applyAward('achievement_earned', key, pts, null);
    }
  }

  const batch = db.batch();
  batch.set(userRef, {
    // reputation_score/reputation_updated_at are now a MIRROR of xp, not an
    // independently-computed value — see this file's top comment ("no two
    // parallel score systems survive this task"). Kept (not deleted) purely
    // for any consumer still reading the old field name; ReputationService
    // prefers `xp`/`level` directly when present (fromUserData).
    reputation_score: latestXp,
    reputation_updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  for (const key of toGrant) {
    batch.set(achievementsRef.doc(key), {
      earned_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  return {
    score: latestXp, tier, granted: toGrant,
    xp: latestXp, level: latestLevel, leveledUp: leveledUpThisSync, xpAwarded,
  };
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

/**
 * Server-authoritative daily login streak + freeze processing (SEC-14).
 *
 * This used to be computed AND written entirely client-side
 * (`firestore_service.dart`'s `handleUserLogin`, existing-user branch) via a
 * plain `batch.update()` — neither `onboarding_data.streak` nor
 * `streak_freeze_count` was in `touchesProtectedUserFields()`'s denylist, so
 * a client could skip the "reset to 1" branch and just keep incrementing/
 * preserving its own streak, or refill its own freeze count, directly.
 * `firestore.rules` now denies both client writes unconditionally; this is
 * the only writer. Mirrors the ORIGINAL Dart logic exactly:
 *   diff == 1             → streak + 1
 *   diff > 1, freeze > 0  → freeze - 1, streak preserved, streak_freeze_used_at set
 *   diff > 1, freeze == 0 → streak resets to 1
 *   diff == 0 (or no prior last_login_at) → no-op
 *
 * Only ever affects the CALLER's own doc — no `targetUid` param, unlike
 * `syncProgress` (advancing a login streak never makes sense for anyone but
 * the caller themselves).
 *
 * Returns `incremented` (true only for the `diff == 1` case) separately from
 * `freezeConsumed` so the client can decide whether to fire its streak-
 * milestone notification with the exact same precision the original
 * client-side code had — that code only ever notified on a consecutive-day
 * increment, never on a freeze-preserved (or reset, or same-day-no-op) day.
 */
exports.processStreakLogin = functions.https.onCall(async (data, context) => {
  const uid = assertCallable(context);
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'User document does not exist');
    }
    const before = snap.data();
    const lastLoginAt = before.last_login_at ? before.last_login_at.toDate() : null;
    const currentStreak = (before.onboarding_data && typeof before.onboarding_data.streak === 'number')
      ? before.onboarding_data.streak : 1;
    const freezeCount = typeof before.streak_freeze_count === 'number' ? before.streak_freeze_count : 0;

    const now = admin.firestore.Timestamp.now();
    const nowDate = now.toDate();

    // This function also writes last_login_at itself, even though the Dart
    // client keeps its own separate, unchanged write of
    // last_login_at/last_active_at/is_online in its own batch right after
    // calling this. That's a deliberate harmless redundant write, not a
    // conflict — it exists purely for THIS function's own idempotency: if
    // the callable is retried (network blip, client-side retry logic)
    // before the client's own subsequent batch commits, a second invocation
    // reads the now-just-set last_login_at (≈ "now"), computes diffDays ===
    // 0 against itself, and correctly no-ops instead of double-consuming a
    // freeze or double-incrementing the streak.
    const update = { last_login_at: now };

    if (!lastLoginAt) {
      // No prior login timestamp recorded — nothing to diff against, leave
      // streak as-is. Matches the original Dart behavior: the whole
      // `if (lastLoginTs != null)` block (increment/freeze/reset, and the
      // milestone notification nested inside it) was skipped entirely in
      // this case, and no state actually changes — so, unlike the branches
      // below, this path doesn't need the idempotency write above; a retry
      // just recomputes the same no-op again.
      return { streak: currentStreak, freezeConsumed: false, freezeCount, incremented: false };
    }

    const todayMidnight = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate());
    const lastMidnight = new Date(lastLoginAt.getFullYear(), lastLoginAt.getMonth(), lastLoginAt.getDate());
    const diffDays = Math.round((todayMidnight - lastMidnight) / 86400000);

    let newStreak = currentStreak;
    let newFreezeCount = freezeCount;
    let freezeConsumed = false;
    const incremented = diffDays === 1;

    if (diffDays === 1) {
      newStreak = currentStreak + 1;
    } else if (diffDays > 1) {
      if (freezeCount > 0) {
        newFreezeCount = freezeCount - 1;
        freezeConsumed = true;
        update.streak_freeze_used_at = now;
      } else {
        newStreak = 1;
      }
    }
    // diffDays === 0 (or negative, e.g. clock skew) → no-op on streak/freeze,
    // matching the original Dart behavior's "same day, do nothing".

    if (newStreak !== currentStreak) update['onboarding_data.streak'] = newStreak;
    if (newFreezeCount !== freezeCount) update.streak_freeze_count = newFreezeCount;

    tx.update(userRef, update);
    return { streak: newStreak, freezeConsumed, freezeCount: newFreezeCount, incremented };
  });
});

// Exported for direct, in-process use by other trigger/callable modules
// that award XP for a SERVER-VERIFIED event of their own (never a client
// payload) — presence.js's closeSession (check_in via geofence/manual),
// gym.js's validateGymCheckin (check_in via QR), templates.js's
// onPlanOfferResponded (template_accepted). Never re-export as an HTTPS
// callable of its own — `syncProgress` stays the single client-facing entry
// gate (see this file's top comment).
exports.awardXp = awardXp;
exports.XP_TABLE = XP_TABLE;
// Faz 5 §5.3 — exported for in-process use by `engagement_credit.js`'s
// `awardWeeklyGroupTop3` (grants `groupTop3`/`groupStreak4` the instant a
// real weekly-contribution win is determined). Never re-exported as an
// HTTPS callable of its own — mirrors `awardXp`'s own export comment.
exports.grantAchievementIfNew = grantAchievementIfNew;
exports.GROUP_STREAK_ACHIEVEMENT_THRESHOLD = GROUP_STREAK_ACHIEVEMENT_THRESHOLD;
