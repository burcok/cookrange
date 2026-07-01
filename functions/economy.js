'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-authoritative referral + commission economy.
//
// Replaces the client-side referral batch (which wrote premium to both users
// and a commission record directly — all forgeable). Here the server validates
// the code, enforces one-per-account + no-self-referral + max-uses atomically,
// grants premium via the server-only entitlements writer, and records the
// commission in a server-written ledger. The client only calls applyReferral.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { grantPremium } = require('./entitlements');
const { APP_CHECK_ENFORCE } = require('./config');

const REFERRAL_REWARD_DAYS = 7;
const REFERRAL_MAX_USES = 10;
const REFERRAL_COMMISSION_TRY = 5;

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

    tx.update(refRef, { used_by_uids: admin.firestore.FieldValue.arrayUnion(uid) });
    tx.set(userRef, { referral_used: code }, { merge: true });
    return { ownerUid };
  });

  if (result.error) {
    throw new functions.https.HttpsError('failed-precondition', result.error);
  }

  const ownerUid = result.ownerUid;
  const expiresAt = new Date(Date.now() + REFERRAL_REWARD_DAYS * 86400000);

  // Reward both parties via the server-only entitlements writer.
  await grantPremium(uid, { source: 'referral', expiresAt });
  await grantPremium(ownerUid, { source: 'referral', expiresAt });

  // Record the owner's commission in a SERVER-written ledger entry.
  await db.collection('users').doc(ownerUid).collection('commissions').add({
    type: 'referral',
    amount: REFERRAL_COMMISSION_TRY,
    currency: 'TRY',
    referee_uid: uid,
    status: 'pending',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Structured notification to the referrer (rendered in their language).
  await db.collection('notifications').doc(ownerUid).collection('items').add({
    type: 'referral',
    actorUid: uid,
    relatedId: code,
    metadata: { rewardDays: REFERRAL_REWARD_DAYS },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info('applyReferral: ok', { uid, ownerUid, code });
  return { ok: true, rewardDays: REFERRAL_REWARD_DAYS };
});
