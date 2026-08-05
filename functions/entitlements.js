'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-only entitlement & credit writers (Admin SDK; bypass security rules).
//
// Premium is authoritative in `entitlements/{uid}` (read by aiProxy.isPremium).
// We ALSO mirror `subscription_tier`/`subscription_expires_at` onto
// `users/{uid}` so existing client UI keeps reading `user.subscriptionTier`
// unchanged — but those fields are SERVER-WRITTEN ONLY (the field-locked
// users/{uid} rule denies client writes to them). The client can therefore
// display premium but never grant it.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const crypto = require('crypto');

async function grantPremium(uid, { productId, expiresAt, source, txId }) {
  const expTs = admin.firestore.Timestamp.fromDate(expiresAt);
  const batch = admin.firestore().batch();
  batch.set(
    admin.firestore().collection('entitlements').doc(uid),
    {
      tier: 'premium',
      product_id: productId || null,
      source,
      latest_transaction_id: txId || null,
      expires_at: expTs,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  batch.set(
    admin.firestore().collection('users').doc(uid),
    { subscription_tier: 'premium', subscription_expires_at: expTs },
    { merge: true }
  );
  await batch.commit();
  functions.logger.info('grantPremium', { uid, source });
}

async function revokePremium(uid, reason) {
  const batch = admin.firestore().batch();
  batch.set(
    admin.firestore().collection('entitlements').doc(uid),
    {
      tier: 'free',
      revoked_reason: reason,
      revoked_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  batch.set(
    admin.firestore().collection('users').doc(uid),
    { subscription_tier: 'free' },
    { merge: true }
  );
  await batch.commit();
  functions.logger.info('revokePremium', { uid, reason });
}

/**
 * One-way correlation key for a specific store purchase (platform + raw
 * purchase token / transaction id), written onto a commission ledger entry
 * at grant time (economy.js's maybeAwardGymCommission) and recomputed here
 * at revocation time so reverseCommissionsForPurchase (below) can find the
 * entry again via a plain equality match.
 *
 * Deliberately a SHA-256 hash, NOT the reversible base64url id
 * claimPurchaseToken uses for `processed_purchases/{id}` above — that
 * collection is fully server-only/unreadable by any client, but
 * `commissions` is owner-readable (firestore.rules: `allow read: if
 * request.auth.uid == uid`), so reusing a reversible encoding there would
 * hand the commission OWNER (e.g. a gym owner) a decodable copy of the
 * purchasing member's actual Apple/Google transaction identifier — a
 * needless leak for a field that only ever needs an equality match, never
 * a decode back to the original token.
 */
function purchaseCorrelationKey(platform, token) {
  return crypto.createHash('sha256').update(`${platform}:${String(token)}`).digest('hex');
}

/**
 * Reverses any commission ledger entries tied to a specific store purchase.
 * Called alongside revokePremium from all three revocation paths in
 * purchases.js (validatePurchase's own `revoked` branch,
 * appStoreNotifications, playRtdn) — never on its own; this function does
 * not touch `entitlements/{uid}` itself, only the `commissions` ledger.
 *
 * Correlates via `purchase_key` (see purchaseCorrelationKey above), which
 * today only `maybeAwardGymCommission`'s `gymPremiumShare` entries carry.
 * The pre-existing `referral` commission (economy.js's applyReferral) is
 * granted at CODE-REDEMPTION time via a free trial grant with no store
 * transaction behind it at all, so it never has a purchase_key and this
 * query will never match one — that is by design, not a remaining gap; see
 * the comment at applyReferral's own commission-write site. The query is
 * otherwise type-agnostic, so any FUTURE purchase-linked commission type is
 * covered automatically without touching this function again.
 *
 * One purchase can, in this codebase's current design, match AT MOST ONE
 * commission entry — claimPurchaseToken's replay-dedupe guarantees
 * maybeAwardGymCommission only ever runs once per unique (platform, token)
 * — but this loops over every match rather than assuming exactly one, in
 * case that ever changes.
 *
 * Per-entry status semantics (mirrors how commission_service.dart's
 * getEarningsSummary already treats status — pending/approved are "not yet
 * paid"; paid money has already actually moved):
 *  - pending / approved → flipped to `rejected` (an existing
 *    CommissionStatus value — getEarningsSummary already excludes rejected
 *    from totalEarned, so no Dart-side change was needed for this branch)
 *    plus `reversed_at`/`reversed_reason`. The entry is kept, never
 *    deleted — every other ledger in this codebase (xp_events,
 *    engagement_credit_events, gym_attributions, ...) is append-only, and
 *    `commissions` already denies client delete for the same reason.
 *  - paid → left factually intact (it WAS earned and WAS paid on that
 *    date; rewriting that would falsify history) and only annotated with
 *    `reversed_at`/`reversed_reason`. A NEW, negative-amount sibling entry
 *    is appended instead (status `pending`, `adjustment_of` pointing back
 *    at the original), so it nets against this owner's NEXT MANUAL payout
 *    via the exact same pendingAmount/totalEarned arithmetic
 *    getEarningsSummary already does — again zero Dart-side change
 *    needed. This mirrors marketplace_terms_{en,tr}.md §10's own "amounts
 *    Cookrange owes you may be offset against amounts you owe Cookrange"
 *    language. Deliberate choice over the task's other two options:
 *    clawing back cash that has already left the business isn't something
 *    a webhook should do unilaterally (payouts here are manual per §4/§10
 *    — there is no payment rail to even issue a reversal on), and doing
 *    nothing at all would leave the ledger permanently overstated after a
 *    real refund, which is exactly what §6/§10 promise won't happen.
 *  - already rejected / already reversed / itself an adjustment entry →
 *    no-op (idempotent — guards against Apple/Google's at-least-once
 *    webhook redelivery, and stops an adjustment entry from ever being
 *    "reversed" a second time, which would silently undo the clawback).
 *
 * Best-effort: every failure is caught and logged, never thrown — mirrors
 * maybeAwardGymCommission's own `.catch()` posture at its purchases.js
 * call site. A bookkeeping failure here must never block or fail the
 * entitlement revocation it's paired with.
 */
async function reverseCommissionsForPurchase(platform, token, reason) {
  if (!token) return;
  const db = admin.firestore();
  const key = purchaseCorrelationKey(platform, token);
  let snap;
  try {
    snap = await db
      .collectionGroup('commissions')
      .where('purchase_key', '==', key)
      .limit(10)
      .get();
  } catch (e) {
    functions.logger.error('reverseCommissionsForPurchase: query failed', {
      platform, reason, error: e.message,
    });
    return;
  }
  if (snap.empty) return;

  for (const commissionDoc of snap.docs) {
    try {
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(commissionDoc.ref);
        if (!fresh.exists) return;
        const d = fresh.data();
        if (d.adjustment_of || d.reversed_at || d.status === 'rejected') {
          return; // already reversed, or is itself an offsetting entry — idempotent no-op
        }

        if (d.status === 'paid') {
          tx.update(commissionDoc.ref, {
            reversed_at: admin.firestore.FieldValue.serverTimestamp(),
            reversed_reason: reason,
          });
          tx.set(commissionDoc.ref.parent.doc(), {
            type: d.type || null,
            amount: -Math.abs(Number(d.amount) || 0),
            currency: d.currency || 'TRY',
            ...(d.referee_uid ? { referee_uid: d.referee_uid } : {}),
            ...(d.gym_id ? { gym_id: d.gym_id } : {}),
            ...(d.purchase_key ? { purchase_key: d.purchase_key } : {}),
            ...(d.purchase_platform ? { purchase_platform: d.purchase_platform } : {}),
            ...(d.purchase_product_id ? { purchase_product_id: d.purchase_product_id } : {}),
            status: 'pending',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            adjustment_of: commissionDoc.id,
            adjustment_reason: reason,
          });
        } else {
          // pending / approved (or any other non-terminal status)
          tx.update(commissionDoc.ref, {
            status: 'rejected',
            reversed_at: admin.firestore.FieldValue.serverTimestamp(),
            reversed_reason: reason,
          });
        }
      });
    } catch (e) {
      functions.logger.error('reverseCommissionsForPurchase: entry reversal failed', {
        commissionId: commissionDoc.id, reason, error: e.message,
      });
    }
  }

  functions.logger.info('reverseCommissionsForPurchase: done', {
    platform, reason, matched: snap.size,
  });
}

async function grantBonusCredits(uid, count) {
  await admin.firestore().collection('ai_credits').doc(uid).set(
    { bonus: admin.firestore.FieldValue.increment(count) },
    { merge: true }
  );
  functions.logger.info('grantBonusCredits', { uid, count });
}

/**
 * Server-authoritative premium check — reads `entitlements/{uid}` (written
 * only by the purchase-validation functions). Fails CLOSED to free on any
 * error. Faz 5 §5.2 addition: a second, independent copy of `index.js`'s
 * identical local `isPremium` existed only inside that file (not exported)
 * before this change; rather than duplicate it a THIRD time in
 * `engagement_credit.js` or introduce a require() cycle with `index.js`
 * (which requires nearly every other function module to re-export it),
 * it's exported from here instead — `entitlements.js` is already the
 * natural home for "what is this user entitled to" reads, has no
 * dependents of its own, and `index.js`'s local copy is deliberately left
 * untouched (smallest correct change; no behavior there should shift as a
 * side effect of this task).
 */
async function isPremium(uid) {
  try {
    const snap = await admin.firestore().collection('entitlements').doc(uid).get();
    if (!snap.exists) return false;
    const d = snap.data() || {};
    if (d.tier !== 'premium') return false;
    const exp = d.expires_at && d.expires_at.toDate ? d.expires_at.toDate() : null;
    return !exp || exp > new Date();
  } catch (e) {
    functions.logger.error('isPremium read failed — failing closed', { uid, error: e.message });
    return false;
  }
}

/**
 * Atomically records a processed purchase token to prevent replay / sharing.
 * Returns false if the token was already consumed (by anyone).
 */
async function claimPurchaseToken(platform, token, uid, productId) {
  const id = `${platform}_${Buffer.from(String(token)).toString('base64url').slice(0, 256)}`;
  const ref = admin.firestore().collection('processed_purchases').doc(id);
  try {
    await ref.create({
      uid,
      platform,
      product_id: productId,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    functions.logger.warn('claimPurchaseToken: replay blocked', { id, uid });
    return false;
  }
}

module.exports = {
  grantPremium,
  revokePremium,
  grantBonusCredits,
  claimPurchaseToken,
  isPremium,
  purchaseCorrelationKey,
  reverseCommissionsForPurchase,
};
