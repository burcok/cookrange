'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 5 §5.2 — pure, Firebase-independent logic for the received-engagement
// credit system. Deliberately has ZERO `require('firebase-admin')` (or any
// other Firebase import) anywhere in this file — every function here takes
// plain numbers/strings/arrays and returns plain values, so it can be
// `require()`-d and unit-tested directly with Node's built-in test runner,
// no emulator needed (see `functions/test/engagement_credit_logic.test.js`).
// `engagement_credit.js` is the orchestration layer: it does the Firestore
// reads/writes and calls into these functions for every DECISION that has
// to be made along the way. This split mirrors this codebase's existing
// `rate_limit.js` (shared helper) vs `moderation.js` (trigger orchestration)
// separation.
//
// This is the part of Faz 5 §5.2 the plan explicitly does NOT hand over an
// algorithm for ("karşılıklılık halkası tespiti... plan doesn't hand you an
// algorithm, so pick a reasonable, defensible one"). What's built here and
// why, concretely:
//
// 1. RECIPROCITY-RING weighting (`reciprocityWeight`) — tracks a rolling,
//    per-PAIR bidirectional interaction count (maintained by the
//    orchestration layer in the `reciprocity_pairs/{pairKey}` ledger) and
//    down-weights a new engagement between two accounts once their history
//    is both (a) large enough to judge and (b) roughly balanced in both
//    directions — the concrete signature of "A reacts to B, B reacts to A,
//    repeat" farming. A single genuine mutual-friend interaction or two
//    never triggers this (MIN_PAIR_SAMPLE guards against small-sample false
//    positives); a account pair that has spent a dozen interactions
//    exclusively reacting to EACH OTHER and no one else does.
//
// 2. CLOSED-CLUSTER weighting (`concentrationWeight`) — reciprocity alone
//    only catches PAIRS. A small ring of 4-5 accounts that mostly engage
//    with each other (but not perfectly 1:1 pairwise) would slip past a
//    pure pairwise check. Instead of building real graph clustering (the
//    plan explicitly warns against over-engineering this), this tracks,
//    PER RECEIVER, a bounded rolling window of the last N distinct-engager
//    events they've received (maintained in `engagement_diversity/{uid}`)
//    and flags when that whole window is dominated by a handful of
//    repeat accounts — i.e. this receiver's "audience" isn't actually
//    diverse, regardless of whether any ONE pair looks reciprocal. This is
//    a concentration/diversity heuristic, not a graph algorithm — cheap to
//    compute, cheap to store, easy to explain to a future reader: "if
//    almost all of your last 20 reactions came from 3 people or fewer,
//    those 3 people's reactions stop counting at full value."
//
// Both signals are combined by taking the MORE punitive of the two
// (`combinedEngagementWeight`) — they're independent detectors of the same
// underlying concern (non-organic, coordinated engagement), not additive
// penalties.
//
// HONEST LIMITATION (documented rather than silently accepted): neither
// mechanism catches a one-directional "many disposable bot accounts react
// to one target, target never reciprocates" ring — that shows up as high
// audience concentration on the TARGET's side (which concentrationWeight
// DOES catch, once the bot accounts recur across enough of the target's
// content) but if every bot account only ever does it ONCE each (never
// recurring), neither check fires. Closing that fully would need
// account-level trust scoring (new-account velocity, device/IP
// fingerprinting) that this codebase has no infrastructure for today — the
// account-age + email-verification gate (Faz 5 §5.2's other mandatory gate,
// enforced in `engagement_credit.js`) is the primary defense against
// disposable one-shot bot accounts specifically, not this file.
// ─────────────────────────────────────────────────────────────────────────────

// ─── Content-quality gate ("minimum içerik eşiği") ─────────────────────────
// A post/comment/message must clear this bar before it's even ELIGIBLE to
// earn credit for its author — independent of how much engagement it later
// receives. An image is treated as sufficient content on its own (a photo
// post with a two-word caption is still real content); text-only content
// needs real length. Numbers are a deliberate, documented, easily-retuned
// choice — not derived from any data, since none exists yet for a
// pre-launch app (PROJECT_STATE.md).
const POST_MIN_TEXT_LENGTH = 20;
const COMMENT_MIN_TEXT_LENGTH = 10;
const MESSAGE_MIN_TEXT_LENGTH = 10;

function isPostEligibleContent({ content, imageCount = 0 }) {
  if (Number(imageCount) > 0) return true;
  return String(content || '').trim().length >= POST_MIN_TEXT_LENGTH;
}

function isCommentEligibleContent({ content }) {
  return String(content || '').trim().length >= COMMENT_MIN_TEXT_LENGTH;
}

// Used only for the weekly-group-contribution source's message gate (§5.2's
// anti-abuse section applies broadly, not source-by-source) — a group chat
// message with an attachment (photo/voice-note-equivalent today: image)
// counts even with little/no body text, mirroring isPostEligibleContent's
// same image-carries-its-own-value stance.
function isMessageEligibleContent({ body, attachmentCount = 0 }) {
  if (Number(attachmentCount) > 0) return true;
  return String(body || '').trim().length >= MESSAGE_MIN_TEXT_LENGTH;
}

// ─── Duplicate/copied-content detection ────────────────────────────────────
// Deliberately simple per the plan's own instruction ("a simple, defensible
// heuristic is fine... don't over-engineer a full plagiarism detector"):
// normalize, then compare against the AUTHOR'S OWN recent content (never a
// site-wide corpus — this is "did YOU just repost the same thing", not
// cross-user plagiarism) via exact-match-after-normalization OR a
// word-level Jaccard similarity above a threshold (catches near-identical
// reposts with a word or two changed, not just byte-identical copies).
function normalizeText(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFKC')
    // Strip punctuation/symbols, keep letters (any script)/digits/spaces —
    // \p{L}/\p{N} need the 'u' flag, which this codebase's Node 22 runtime
    // (functions/package.json engines.node) fully supports.
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function textWordSet(text) {
  const norm = normalizeText(text);
  return new Set(norm.length ? norm.split(' ') : []);
}

function jaccardSimilarity(setA, setB) {
  if (setA.size === 0 && setB.size === 0) return 0;
  let intersection = 0;
  for (const w of setA) {
    if (setB.has(w)) intersection++;
  }
  const unionSize = setA.size + setB.size - intersection;
  return unionSize === 0 ? 0 : intersection / unionSize;
}

const DUPLICATE_SIMILARITY_THRESHOLD = 0.85;
// How many of the author's own most recent items (posts, or comments,
// tracked separately by the caller) get compared against.
const DUPLICATE_RECENT_WINDOW = 20;

function isNearDuplicateText(text, recentTexts, threshold = DUPLICATE_SIMILARITY_THRESHOLD) {
  const norm = normalizeText(text);
  if (!norm) return false;
  const ws = textWordSet(text);
  for (const prev of recentTexts || []) {
    const prevNorm = normalizeText(prev);
    if (!prevNorm) continue;
    if (prevNorm === norm) return true;
    if (jaccardSimilarity(ws, textWordSet(prev)) >= threshold) return true;
  }
  return false;
}

// ─── Reciprocity-ring weighting ────────────────────────────────────────────
// See header comment. Inputs are the PRIOR (before this event) bidirectional
// counts between the giver and the receiver — the orchestration layer reads
// these from `reciprocity_pairs/{pairKey}` before recording the current
// event, so the current event never influences its own weight.
const RECIPROCITY_MIN_PAIR_SAMPLE = 4;
const RECIPROCITY_RATIO_THRESHOLD = 0.5;
const RECIPROCITY_DOWNWEIGHT = 0.2;

function reciprocityWeight(priorGivenGiverToReceiver, priorGivenReceiverToGiver) {
  const a = Math.max(0, Number(priorGivenGiverToReceiver) || 0);
  const b = Math.max(0, Number(priorGivenReceiverToGiver) || 0);
  const total = a + b;
  if (total < RECIPROCITY_MIN_PAIR_SAMPLE) return 1;
  const bigger = Math.max(a, b);
  const smaller = Math.min(a, b);
  const ratio = bigger === 0 ? 0 : smaller / bigger;
  return ratio >= RECIPROCITY_RATIO_THRESHOLD ? RECIPROCITY_DOWNWEIGHT : 1;
}

// ─── Closed-cluster (engagement concentration) weighting ──────────────────
// `recentGivers` is the RECEIVER's bounded rolling window of the last
// CONCENTRATION_WINDOW distinct-engagement-event giver uids (oldest first),
// maintained by the orchestration layer in `engagement_diversity/{uid}`.
// Only judges once the window is FULL (avoids flagging a brand-new
// account's first few genuine reactions as "concentrated" just because
// there's no data yet).
const CONCENTRATION_WINDOW = 20;
const CONCENTRATION_DISTINCT_MAX = 3;
const CONCENTRATION_DOWNWEIGHT = 0.2;

function concentrationWeight(recentGivers, candidateUid) {
  const window = Array.isArray(recentGivers) ? recentGivers : [];
  if (window.length < CONCENTRATION_WINDOW) return 1;
  const distinct = new Set(window);
  if (distinct.size > CONCENTRATION_DISTINCT_MAX) return 1;
  return distinct.has(candidateUid) ? CONCENTRATION_DOWNWEIGHT : 1;
}

// Appends `value` to `window`, evicting from the front once over `maxLen` —
// a plain bounded FIFO. Pure so the eviction boundary itself is unit-tested;
// the orchestration layer is the one that actually persists the result.
function pushCappedWindow(window, value, maxLen) {
  const next = [...(Array.isArray(window) ? window : []), value];
  return next.length > maxLen ? next.slice(next.length - maxLen) : next;
}

// The single entry point the orchestration layer calls per qualifying
// engagement event — combines both signals by taking the MORE punitive
// (lower) weight, since they're independent detectors of the same
// underlying concern rather than stacking penalties.
function combinedEngagementWeight({
  priorGivenGiverToReceiver,
  priorGivenReceiverToGiver,
  receiverRecentGivers,
  giverUid,
}) {
  const rw = reciprocityWeight(priorGivenGiverToReceiver, priorGivenReceiverToGiver);
  const cw = concentrationWeight(receiverRecentGivers, giverUid);
  return Math.min(rw, cw);
}

// ─── Account eligibility gate ("hesap yaşı >= 3 gün ve >= 1 doğrulanmış e-posta") ─
const MIN_ACCOUNT_AGE_MS = 3 * 24 * 60 * 60 * 1000;

function isAccountOldEnough(createdAtMs, nowMs) {
  if (!createdAtMs) return false;
  return (nowMs - createdAtMs) >= MIN_ACCOUNT_AGE_MS;
}

// ─── Shadow-restriction auto-trigger ────────────────────────────────────────
// `flagCount` is a rolling counter the orchestration layer bumps on
// `credit_restrictions/{uid}` every time ONE of this account's OWN content
// items has a credit-worthy engagement event down-weighted to the punitive
// factor (reciprocity/concentration) or blocked as near-duplicate content —
// i.e. every time this account's OWN behavior (not someone else reacting to
// them) looks non-organic. Deliberately a simple counter threshold, not a
// decaying score — easy to explain, easy to appeal ("you were flagged N
// times"), and the counter only ever grows via SERVER-DECIDED events, never
// client input.
const AUTO_RESTRICT_FLAG_THRESHOLD = 5;

function shouldAutoRestrict(flagCount) {
  return (Number(flagCount) || 0) >= AUTO_RESTRICT_FLAG_THRESHOLD;
}

// ─── Credit table + premium 2x multiplier ──────────────────────────────────
// Fixed, server-owned base values — mirrors progress.js's XP_TABLE shape/
// spirit exactly ("a client can name a KIND; it can never name a point
// value or a cap"). `threshold` (distinct-account counts) is NOT doubled by
// premium — only the credit value and the cap are ("tavanlar da 2×" — the
// plan names caps and the per-source value, never the popularity bar
// itself; doubling the bar would be backwards, not a reward).
const CREDIT_TABLE = {
  post_reactions: { credit: 1, dailyCap: 2, threshold: 10 },
  comment_likes: { credit: 1, dailyCap: 1, threshold: 5 },
  template_used: { credit: 1, dailyCap: 3 },
  weekly_group_top3: { credit: 5, weeklyCap: 1 },
};

function creditAndCapForPremium(sourceKey, isPremiumUser) {
  const entry = CREDIT_TABLE[sourceKey];
  if (!entry) return null;
  const multiplier = isPremiumUser ? 2 : 1;
  return {
    credit: entry.credit * multiplier,
    dailyCap: typeof entry.dailyCap === 'number' ? entry.dailyCap * multiplier : null,
    weeklyCap: typeof entry.weeklyCap === 'number' ? entry.weeklyCap * multiplier : null,
    threshold: entry.threshold,
    multiplierApplied: multiplier,
  };
}

// ─── Local-time (Turkey, fixed UTC+3) day/week helpers ─────────────────────
// Duplicated from (rather than imported from) progress.js/presence.js
// DELIBERATELY — this codebase's own established, documented precedent
// (see progress.js's LOCAL_UTC_OFFSET_HOURS comment: "mirrors the identical
// constant/comment in presence.js"). This file additionally has a hard
// constraint the other two don't: it must stay Firebase-free, so it can
// never `require('./progress')` (which itself requires firebase-admin).
const LOCAL_UTC_OFFSET_HOURS = 3;

function shiftedDate(nowMs, offsetHours = LOCAL_UTC_OFFSET_HOURS) {
  return new Date(nowMs + offsetHours * 3600000);
}

function startOfLocalDayMs(nowMs, offsetHours = LOCAL_UTC_OFFSET_HOURS) {
  const shifted = shiftedDate(nowMs, offsetHours);
  const localMidnightUtcMs = Date.UTC(
    shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate(),
  );
  return localMidnightUtcMs - offsetHours * 3600000;
}

// Start of the CURRENT local week (Monday 00:00 local), as a true UTC
// instant — mirrors startOfLocalDayMs's shift-then-unshift pattern.
function startOfLocalWeekMs(nowMs, offsetHours = LOCAL_UTC_OFFSET_HOURS) {
  const shifted = shiftedDate(nowMs, offsetHours);
  const dayNum = (shifted.getUTCDay() + 6) % 7; // Mon=0 .. Sun=6
  const localMidnightUtcMs = Date.UTC(
    shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate(),
  );
  const mondayLocalMidnightUtcMs = localMidnightUtcMs - dayNum * 86400000;
  return mondayLocalMidnightUtcMs - offsetHours * 3600000;
}

// A stable, sortable, human-readable key for "which local week is this" —
// the Monday's own local calendar date (e.g. "2026-08-03"), NOT an ISO-8601
// week number. Deliberate choice: real ISO week numbering has year-boundary
// edge cases (week 52/53 rollovers, a week's Thursday landing in a
// different year than its Monday) that add risk for zero benefit here —
// this key only needs to be unique-per-week and usable in a Firestore doc
// id/eventId, not calendar-standard.
function localWeekKey(nowMs, offsetHours = LOCAL_UTC_OFFSET_HOURS) {
  const mondayUtcMs = startOfLocalWeekMs(nowMs, offsetHours);
  const shifted = shiftedDate(mondayUtcMs, offsetHours);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const d = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// ─── Group-contribution streak support (Faz 5 §5.3) ────────────────────────
// The `weekKey` immediately BEFORE `weekKey` — pure calendar-date arithmetic
// on the key's own `YYYY-MM-DD` string (a `localWeekKey` output is always a
// Monday's local calendar date), deliberately NOT re-derived from `Date.now()`
// with another offset shift: subtracting exactly 7 days in UTC ms from a
// date already normalized to local midnight lands on the correct previous
// Monday's calendar date regardless of timezone, so this needs no
// LOCAL_UTC_OFFSET_HOURS involvement at all. Used by
// `engagement_credit.js`'s `bumpGroupTop3Streak` to detect whether a new
// `weekly_group_top3` win is CONSECUTIVE with the last one it counted, or a
// gap that resets the streak.
function previousWeekKey(weekKey) {
  const d = new Date(`${weekKey}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 7);
  return d.toISOString().slice(0, 10);
}

// ─── Weekly top-3 selection ─────────────────────────────────────────────────
// `rankedEntries` — already sorted descending by score, each
// `{uid, score, eligible}`. Skips ineligible entries (age/email/shadow-
// restriction gate already applied by the orchestration layer) and promotes
// the next-ranked eligible member instead of just taking the raw top 3 —
// an ineligible #1 shouldn't make the reward vanish for the group.
function pickTopNEligible(rankedEntries, n) {
  const picked = [];
  for (const entry of (rankedEntries || [])) {
    if (picked.length >= n) break;
    if (entry && entry.eligible) picked.push(entry);
  }
  return picked;
}

module.exports = {
  // content quality
  isPostEligibleContent,
  isCommentEligibleContent,
  isMessageEligibleContent,
  // duplicate content
  normalizeText,
  textWordSet,
  jaccardSimilarity,
  isNearDuplicateText,
  DUPLICATE_SIMILARITY_THRESHOLD,
  DUPLICATE_RECENT_WINDOW,
  // reciprocity / concentration
  reciprocityWeight,
  concentrationWeight,
  combinedEngagementWeight,
  pushCappedWindow,
  RECIPROCITY_MIN_PAIR_SAMPLE,
  RECIPROCITY_RATIO_THRESHOLD,
  RECIPROCITY_DOWNWEIGHT,
  CONCENTRATION_WINDOW,
  CONCENTRATION_DISTINCT_MAX,
  CONCENTRATION_DOWNWEIGHT,
  // account gate
  isAccountOldEnough,
  MIN_ACCOUNT_AGE_MS,
  // shadow restriction
  shouldAutoRestrict,
  AUTO_RESTRICT_FLAG_THRESHOLD,
  // credit table
  CREDIT_TABLE,
  creditAndCapForPremium,
  // time helpers
  startOfLocalDayMs,
  startOfLocalWeekMs,
  localWeekKey,
  previousWeekKey,
  LOCAL_UTC_OFFSET_HOURS,
  // weekly ranking
  pickTopNEligible,
};
