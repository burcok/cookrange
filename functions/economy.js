'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authoritative referral + commission economy.
//
// Replaces the client-side referral batch (which wrote premium to both users
// and a commission record directly — all forgeable). Here the server validates
// the code, enforces one-per-account + no-self-referral + max-uses atomically,
// grants premium via the server-only entitlements writer, and records the
// commission in a server-written ledger. The client only calls applyReferral.
//
// Faz 6 §6.5/§6.6: a `type: 'gym'` code (Faz 6 §6.1) is NOT a personal
// referral — it's a gym's own acquisition channel (a poster scanned by
// strangers, not a 1:1 friend share). Redeeming one no longer runs the
// generic trial+commission grant below (that would mean every one of up to
// 5,000 poster scans nets both a free trial AND a ₺5 payout — a real cost/
// abuse vector, and simply the wrong reward for a marketing channel). It
// instead writes an immutable `gym_attributions/{uid}` record and bumps the
// gym's own counter; real revenue (`maybeAwardGymCommission`, called from
// purchases.js) only follows a REAL premium purchase later, never the code
// redemption itself. See the `type === 'gym'` branch below.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { grantPremium, purchaseCorrelationKey } = require('./entitlements');
const { APP_CHECK_ENFORCE } = require('./config');
const { writeNotification } = require('./notifications');

const REFERRAL_REWARD_DAYS = 7;
const REFERRAL_MAX_USES = 10;
const REFERRAL_COMMISSION_TRY = 5;

// Faz 6 §6.6 — flat TRY commission per validated PREMIUM purchase (never the
// AI-credits consumable) made by a user previously attributed to a gym.
// Flat, like REFERRAL_COMMISSION_TRY above, rather than a true percentage:
// purchases.js's store verification (verifyApple/verifyGoogle) never
// surfaces the actual price the user paid today — only productId/expiry/
// revocation — so there is no real price server-side to take a cut of. This
// is a placeholder rate pending the gym contract's business/legal sign-off
// (assets/legal/marketplace_terms_{en,tr}.md's gym commission section
// deliberately describes the mechanism, not a hardcoded number, and points
// back here as the one place the actual rate lives — change it here only).
const GYM_COMMISSION_TRY = {
  'com.cookrange.premium.monthly': 15,
  'com.cookrange.premium.yearly': 120,
};

exports.applyReferral = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const code = (data && data.code ? String(data.code) : '').trim().toUpperCase();
  if (code.length < 4) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_code');
  }
  // Faz 6 §6.5 — how the code reached this redemption, for the attribution
  // record's own `source` field (gym branch only; ignored for a personal/
  // coach-vanity code). Client-reported and only loosely trusted (it's a
  // diagnostic/analytics classification, not a value-bearing field) —
  // defaults to 'in_app' when absent/invalid rather than guessing. Today
  // only `ReferralService.applyCode`'s Settings call site can state this
  // unambiguously ('manual_entry'); the onboarding call site can't yet
  // distinguish a deep-link-prefilled code from one typed during onboarding
  // itself, so it also sends 'in_app' — 'deep_link' is a real, valid value
  // this schema supports, just not reachable from today's client until that
  // distinction is threaded through OnboardingProvider (not this task's
  // scope; see PROJECT_STATE.md/TODO.md for the follow-up).
  const source = ['deep_link', 'manual_entry', 'in_app'].includes(data && data.source)
    ? data.source
    : 'in_app';

  const db = admin.firestore();
  const refRef = db.collection('referrals').doc(code);
  const userRef = db.collection('users').doc(uid);

  // Validate + claim atomically (append-only used_by_uids, server-set marker).
  const result = await db.runTransaction(async (tx) => {
    const refSnap = await tx.get(refRef);
    if (!refSnap.exists) return { error: 'code_not_found' };
    const ref = refSnap.data();
    const ownerUid = ref.owner_uid;
    const usedBy = Array.isArray(ref.used_by_uids) ? ref.used_by_uids : [];
    const maxUses = typeof ref.max_uses === 'number' ? ref.max_uses : REFERRAL_MAX_USES;

    if (ownerUid === uid) return { error: 'own_code' };
    if (usedBy.includes(uid)) return { error: 'already_used_this' };
    if (usedBy.length >= maxUses) return { error: 'limit_reached' };

    const userSnap = await tx.get(userRef);
    if (userSnap.exists && userSnap.data().referral_used) {
      return { error: 'already_used_any' };
    }

    const type = ref.type || 'user';

    // Faz 6 §6.5 — a gym code writes an attribution record INSTEAD of the
    // generic trial+commission grant below (see this file's header comment
    // for why a gym code is not treated as a personal referral).
    if (type === 'gym') {
      const gymId = typeof ref.gym_id === 'string' ? ref.gym_id : '';
      if (!gymId) return { error: 'code_not_found' }; // malformed gym code
      const gymRef = db.collection('gyms').doc(gymId);
      const gymSnap = await tx.get(gymRef);
      if (!gymSnap.exists) return { error: 'code_not_found' };

      tx.update(refRef, { used_by_uids: admin.firestore.FieldValue.arrayUnion(uid) });
      tx.set(userRef, { referral_used: code }, { merge: true });
      tx.set(db.collection('gym_attributions').doc(uid), {
        gym_id: gymId,
        code,
        ...(ref.coach_uid ? { coach_uid: ref.coach_uid } : {}),
        ...(ref.campaign ? { campaign: ref.campaign } : {}),
        attributed_at: admin.firestore.FieldValue.serverTimestamp(),
        source,
        lifetime_commission_try: 0,
      });
      // Bumps the gym's OWN attributed-signup counter — deliberately NOT
      // member_count. Redeeming an invite code attributes a signup to this
      // gym's marketing; it does not make the person a gym MEMBER (that's a
      // separate, explicit joinGym action, Faz 0/1). touchesProtectedGymFields()
      // (firestore.rules) denies the owner's blanket update rule from
      // touching this directly, same as live_occupancy/attributed_premium_count.
      tx.update(gymRef, {
        attributed_member_count: admin.firestore.FieldValue.increment(1),
      });
      return {
        type: 'gym',
        gymId,
        gymOwnerUid: gymSnap.data().owner_uid || null,
        gymName: gymSnap.data().name || null,
      };
    }

    tx.update(refRef, { used_by_uids: admin.firestore.FieldValue.arrayUnion(uid) });
    tx.set(userRef, { referral_used: code }, { merge: true });
    return { type, ownerUid };
  });

  if (result.error) {
    throw new functions.https.HttpsError('failed-precondition', result.error);
  }

  if (result.type === 'gym') {
    // Best-effort — the redemption itself already committed above; a
    // notification failure must not turn a successful redemption into a
    // client-visible error (same fire-after-commit ordering as the
    // personal-referral notification below).
    if (result.gymOwnerUid) {
      await writeNotification(db, {
        targetUid: result.gymOwnerUid,
        type: 'gymAttribution',
        // Deliberately NO actorName/actorPhotoUrl — Faz 6 §6.5: "bireysel
        // kullanıcı kimliği salona gitmez" (individual identity never
        // reaches the gym). actorUid is kept only for admin/audit lookups,
        // exactly like the personal-referral notification below already
        // does; NotificationPresenter renders this type from static,
        // actor-free copy.
        actorUid: uid,
        relatedId: code,
      }).catch((e) => {
        functions.logger.error('applyReferral: gym owner notification failed', {
          uid, gymId: result.gymId, error: e.message,
        });
      });
    }
    functions.logger.info('applyReferral: gym attribution ok', {
      uid, gymId: result.gymId, code,
    });
    return { ok: true, type: 'gym', gymName: result.gymName };
  }

  const ownerUid = result.ownerUid;
  const expiresAt = new Date(Date.now() + REFERRAL_REWARD_DAYS * 86400000);

  // Reward both parties via the server-only entitlements writer.
  await grantPremium(uid, { source: 'referral', expiresAt });
  await grantPremium(ownerUid, { source: 'referral', expiresAt });

  // Record the owner's commission in a SERVER-written ledger entry.
  //
  // Deliberately NO purchase_key here (contrast maybeAwardGymCommission
  // below) — this commission is granted the instant the code is redeemed,
  // from a FREE trial grantPremium(source:'referral', no txId), never a
  // real store purchase. entitlements.js's reverseCommissionsForPurchase
  // (called from purchases.js's three revocation paths) only ever fires in
  // response to a real Apple/Google store signal about a real transaction
  // — a referral-sourced trial is never one of those, so there is no
  // purchase for this entry to ever be correlated against. Structurally
  // exempt from the reversal feature, not a remaining gap in it.
  await db.collection('users').doc(ownerUid).collection('commissions').add({
    type: 'referral',
    amount: REFERRAL_COMMISSION_TRY,
    currency: 'TRY',
    referee_uid: uid,
    status: 'pending',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Structured notification to the referrer (rendered in their language).
  await writeNotification(db, {
    targetUid: ownerUid,
    type: 'referral',
    actorUid: uid,
    relatedId: code,
    metadata: { rewardDays: REFERRAL_REWARD_DAYS },
  });

  functions.logger.info('applyReferral: ok', { uid, ownerUid, code });
  return { ok: true, type: result.type, rewardDays: REFERRAL_REWARD_DAYS };
});

// ─────────────────────────────────────────────────────────────────────────────
// Faz 6 §6.3/§6.4 — pre-signup code preview (read-only, no auth required).
//
// Onboarding has NO Firebase Auth session (account creation happens at the
// END of the flow), so applyReferral (which requires context.auth.uid and
// mutates used_by_uids) can't be called yet — but the referral step still
// needs to show "verified, {gym name}" the moment a code arrives via deep
// link or clipboard paste. This mirrors the site's api/invite.ts validation
// (same Firestore project, same referrals/{code} doc) for the in-app path,
// where a Universal Link hands the URI straight to the app and the site page
// is never rendered. Never mutates anything (no used_by_uids write, no
// premium grant) — real redemption still only ever happens through
// applyReferral, post-signup. "Not found" and "inactive/exhausted" return the
// identical `{valid: false}` shape so this can't be used to enumerate which
// codes exist, matching the site endpoint's anti-enumeration posture.
// ─────────────────────────────────────────────────────────────────────────────
exports.previewReferralCode = functions.https.onCall(async (data, context) => {
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const code = (data && data.code ? String(data.code) : '').trim().toUpperCase();
  if (code.length < 4) {
    return { valid: false };
  }

  const db = admin.firestore();
  const snap = await db.collection('referrals').doc(code).get();
  if (!snap.exists) return { valid: false };

  const ref = snap.data();
  const usedBy = Array.isArray(ref.used_by_uids) ? ref.used_by_uids : [];
  const maxUses = typeof ref.max_uses === 'number' ? ref.max_uses : REFERRAL_MAX_USES;
  if (usedBy.length >= maxUses) return { valid: false }; // exhausted, or voided (max_uses:0)

  const type = ref.type || 'user';
  let gymName = null;
  if (type === 'gym' && typeof ref.gym_id === 'string') {
    const gymSnap = await db.collection('gyms').doc(ref.gym_id).get();
    if (gymSnap.exists) gymName = gymSnap.data().name || null;
  }

  return { valid: true, type, gymName };
});

// ─────────────────────────────────────────────────────────────────────────────
// Faz 6 §6.6 — gym revenue share.
//
// Called from INSIDE purchases.js's validatePurchase, strictly AFTER the
// store has already verified the purchase and grantPremium has already run —
// never triggered by any client action. No-ops silently (but logs its own
// early-return reasons at debug-equivalent info level) whenever the
// purchasing user was never attributed to a gym, which is the common case
// for the overwhelming majority of purchases.
//
// Reversal (refund/chargeback) — CLOSED as of this change, for THIS
// commission type. Every entry written below carries a `purchase_key` (see
// the write site further down for exactly what it is and why it's a
// one-way hash rather than a reversible id), so entitlements.js's
// reverseCommissionsForPurchase — called from all three of purchases.js's
// revocation paths (validatePurchase's own `revoked` branch,
// appStoreNotifications, playRtdn), but ONLY for a genuine refund/revoke
// signal, deliberately never for a plain, non-renewed EXPIRY (see the
// comment at each of those three call sites for why) — can find this exact
// entry again and reverse it. This used to be a documented, deliberate gap
// (no wiring from revocation back to any commission entry existed at all);
// it no longer is, for `gymPremiumShare`.
//
// The pre-existing `referral` commission (applyReferral, above) remains
// structurally exempt rather than still-gapped: it's granted at CODE
// REDEMPTION time via a free trial grant with no store transaction behind
// it at all, so there is no purchase for any revocation path to ever
// correlate it against — see the comment at its own write site.
// ─────────────────────────────────────────────────────────────────────────────
async function maybeAwardGymCommission(uid, productId, platform, token) {
  const amount = GYM_COMMISSION_TRY[productId];
  if (!amount) return; // not a commission-eligible product (e.g. AI credits)

  const db = admin.firestore();
  const attributionRef = db.collection('gym_attributions').doc(uid);
  const attrSnap = await attributionRef.get();
  if (!attrSnap.exists) {
    functions.logger.info('maybeAwardGymCommission: no attribution, skipping', { uid, productId });
    return;
  }

  const gymId = attrSnap.data().gym_id;
  if (typeof gymId !== 'string' || !gymId) return;
  const gymRef = db.collection('gyms').doc(gymId);
  const gymSnap = await gymRef.get();
  if (!gymSnap.exists) return;
  const gymOwnerUid = gymSnap.data().owner_uid;
  if (!gymOwnerUid) return;

  // First-conversion detection + the lifetime running total both need a
  // FRESH read inside the transaction — the pre-check above is only used to
  // short-circuit the (common) no-attribution case cheaply.
  await db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(attributionRef);
    if (!freshSnap.exists) return;
    const fresh = freshSnap.data();
    const updates = {
      lifetime_commission_try: admin.firestore.FieldValue.increment(amount),
    };
    if (!fresh.first_premium_at) {
      updates.first_premium_at = admin.firestore.FieldValue.serverTimestamp();
      // Distinct-converts counter — bumped ONLY on this user's first-ever
      // premium purchase, never again on renewal (unlike lifetime_commission_try
      // above, which accrues every time). Protected the same way as
      // attributed_member_count (touchesProtectedGymFields()).
      tx.update(gymRef, { attributed_premium_count: admin.firestore.FieldValue.increment(1) });
    }
    tx.set(attributionRef, updates, { merge: true });
  });

  // Commission ledger entry — same collection/shape as the referral
  // commission above, new `type`. One entry PER purchase event (a renewing
  // subscriber accrues additional entries over time, unlike first_premium_at
  // which is a set-once marker).
  //
  // purchase_key/purchase_platform/purchase_product_id let a LATER refund/
  // chargeback event find this exact entry again — see
  // entitlements.js's purchaseCorrelationKey/reverseCommissionsForPurchase
  // for the full design (one-way hash, collectionGroup lookup, per-status
  // reversal semantics). platform/token are the SAME values validatePurchase
  // already verified and passed to claimPurchaseToken/grantPremium moments
  // earlier in this same call — nothing new is trusted from the client here.
  await db.collection('users').doc(gymOwnerUid).collection('commissions').add({
    type: 'gymPremiumShare',
    amount,
    currency: 'TRY',
    referee_uid: uid,
    gym_id: gymId,
    status: 'pending',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    purchase_key: purchaseCorrelationKey(platform, token),
    purchase_platform: platform,
    purchase_product_id: productId,
  });

  functions.logger.info('maybeAwardGymCommission: ok', { uid, gymId, gymOwnerUid, amount, productId });
}

module.exports.maybeAwardGymCommission = maybeAwardGymCommission;
