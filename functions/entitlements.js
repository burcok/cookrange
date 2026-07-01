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

async function grantBonusCredits(uid, count) {
  await admin.firestore().collection('ai_credits').doc(uid).set(
    { bonus: admin.firestore.FieldValue.increment(count) },
    { merge: true }
  );
  functions.logger.info('grantBonusCredits', { uid, count });
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
};
