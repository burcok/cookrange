'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-side purchase validation (native store APIs) + entitlement granting.
//
// SECURITY MODEL (do not regress):
//  - Entitlements (premium tier) live in the SERVER-ONLY `entitlements/{uid}`
//    doc and AI bonus credits in `ai_credits/{uid}` — both deny-client-write in
//    rules; written ONLY here via the Admin SDK after the store confirms the
//    purchase. The client NEVER grants its own premium/credits.
//  - Every purchase token is validated against Apple/Google and DEDUPED so a
//    receipt cannot be replayed or shared across accounts.
//  - Verification FAILS CLOSED: if credentials are missing or the store can't
//    confirm the purchase, nothing is granted.
//
// Required Function secrets/env (set before go-live — see GO_LIVE.md §5S/S3):
//   Apple : APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8 contents),
//           APPLE_BUNDLE_ID
//   Google: GOOGLE_PLAY_PACKAGE, GOOGLE_PLAY_SA_JSON (service-account JSON)
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const fetch = require('node-fetch');
const jwt = require('jsonwebtoken');
const { GoogleAuth } = require('google-auth-library');
const { APP_CHECK_ENFORCE } = require('./config');
const {
  grantPremium,
  revokePremium,
  grantBonusCredits,
  claimPurchaseToken,
  reverseCommissionsForPurchase,
} = require('./entitlements');
const { maybeAwardGymCommission } = require('./economy');

const PURCHASE_SECRETS = [
  'APPLE_ISSUER_ID',
  'APPLE_KEY_ID',
  'APPLE_PRIVATE_KEY',
  'APPLE_BUNDLE_ID',
  'GOOGLE_PLAY_PACKAGE',
  'GOOGLE_PLAY_SA_JSON',
];

// Product catalog → entitlement effect. Mirrors BillingProducts on the client.
const PRODUCTS = {
  'com.cookrange.premium.monthly': { kind: 'subscription', tier: 'premium', days: 31 },
  'com.cookrange.premium.yearly': { kind: 'subscription', tier: 'premium', days: 365 },
  'cookrange_ai_credits_10': { kind: 'consumable', bonusCredits: 10 },
};

const APPLE_PROD = 'https://api.storekit.itunes.apple.com';
const APPLE_SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com';

// Entitlement/credit writers + replay dedupe live in ./entitlements.js.

// ─── Apple App Store Server API ──────────────────────────────────────────────

function appleConfigured() {
  return (
    process.env.APPLE_ISSUER_ID &&
    process.env.APPLE_KEY_ID &&
    process.env.APPLE_PRIVATE_KEY &&
    process.env.APPLE_BUNDLE_ID
  );
}

function appleApiToken() {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: process.env.APPLE_ISSUER_ID,
      iat: now,
      exp: now + 600,
      aud: 'appstoreconnect-v1',
      bid: process.env.APPLE_BUNDLE_ID,
    },
    process.env.APPLE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    { algorithm: 'ES256', header: { kid: process.env.APPLE_KEY_ID, typ: 'JWT' } }
  );
}

/** Decodes the payload of a JWS (Apple signedTransactionInfo). */
function decodeJwsPayload(jws) {
  const parts = String(jws).split('.');
  if (parts.length !== 3) throw new Error('malformed JWS');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

/**
 * Looks up a transaction in Apple's App Store Server API and returns the
 * decoded transaction info. Tries production then sandbox.
 * NOTE: before go-live, harden by verifying the JWS x5c chain against Apple's
 * root CA (use @apple/app-store-server-library). This decode trusts the API
 * response over TLS from Apple's host, which is acceptable for MVP.
 */
async function verifyApple(transactionId) {
  if (!appleConfigured()) throw new Error('apple_not_configured');
  const token = appleApiToken();
  for (const host of [APPLE_PROD, APPLE_SANDBOX]) {
    const resp = await fetch(`${host}/inApps/v1/transactions/${transactionId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (resp.status === 404) continue; // try sandbox
    if (!resp.ok) throw new Error(`apple_api_${resp.status}`);
    const body = await resp.json();
    const info = decodeJwsPayload(body.signedTransactionInfo);
    if (info.bundleId && info.bundleId !== process.env.APPLE_BUNDLE_ID) {
      throw new Error('apple_bundle_mismatch');
    }
    return info; // { productId, expiresDate, revocationDate, ... }
  }
  throw new Error('apple_txn_not_found');
}

// ─── Google Play Developer API ───────────────────────────────────────────────

function googleConfigured() {
  return process.env.GOOGLE_PLAY_PACKAGE && process.env.GOOGLE_PLAY_SA_JSON;
}

let _googleAuth;
async function googleAccessToken() {
  if (!_googleAuth) {
    _googleAuth = new GoogleAuth({
      credentials: JSON.parse(process.env.GOOGLE_PLAY_SA_JSON),
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
  }
  const client = await _googleAuth.getClient();
  const { token } = await client.getAccessToken();
  return token;
}

async function verifyGoogle(productId, purchaseToken, isSubscription) {
  if (!googleConfigured()) throw new Error('google_not_configured');
  const pkg = process.env.GOOGLE_PLAY_PACKAGE;
  const token = await googleAccessToken();
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases`;
  const url = isSubscription
    ? `${base}/subscriptions/${productId}/tokens/${purchaseToken}`
    : `${base}/products/${productId}/tokens/${purchaseToken}`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!resp.ok) throw new Error(`google_api_${resp.status}`);
  return resp.json();
}

// ─── validatePurchase (callable) ─────────────────────────────────────────────

exports.validatePurchase = functions.https.onCall(async (data, context) => {
    const uid = context.auth && context.auth.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }
    if (context.app === undefined && APP_CHECK_ENFORCE) {
      throw new functions.https.HttpsError('failed-precondition', 'App Check required');
    }

    const platform = data && data.platform; // 'ios' | 'android'
    const productId = data && data.productId;
    const token = data && (data.purchaseToken || data.transactionId); // android token | apple txId
    const product = PRODUCTS[productId];
    if (!product || !platform || !token) {
      throw new functions.https.HttpsError('invalid-argument', 'platform, productId, token required');
    }

    // ── Verify with the store (fails closed) ──
    let expiresAt = null;
    let revoked = false;
    try {
      if (platform === 'ios') {
        const info = await verifyApple(token);
        if (info.productId !== productId) {
          throw new functions.https.HttpsError('failed-precondition', 'product_mismatch');
        }
        revoked = !!info.revocationDate;
        if (info.expiresDate) expiresAt = new Date(Number(info.expiresDate));
      } else if (platform === 'android') {
        const info = await verifyGoogle(productId, token, product.kind === 'subscription');
        if (product.kind === 'subscription') {
          // subscriptionsv2/v1: expiryTimeMillis (v1) or lineItems[].expiryTime (v2)
          const expiryMs = info.expiryTimeMillis
            ? Number(info.expiryTimeMillis)
            : (info.lineItems && info.lineItems[0] && info.lineItems[0].expiryTime
                ? Date.parse(info.lineItems[0].expiryTime) : null);
          if (expiryMs) expiresAt = new Date(expiryMs);
          // 1 = cancelled but may still be active until expiry; treat purchaseState 0/paid as valid
        } else {
          // products: purchaseState 0 = purchased
          if (info.purchaseState !== undefined && info.purchaseState !== 0) {
            throw new functions.https.HttpsError('failed-precondition', 'not_purchased');
          }
        }
      } else {
        throw new functions.https.HttpsError('invalid-argument', 'unknown platform');
      }
    } catch (e) {
      if (e instanceof functions.https.HttpsError) throw e;
      functions.logger.error('validatePurchase verification failed', { uid, productId, error: e.message });
      // Fail CLOSED — never grant on a verification error.
      throw new functions.https.HttpsError('failed-precondition', 'verification_failed');
    }

    if (revoked) {
      await revokePremium(uid, 'apple_revoked');
      // Best-effort, same posture as maybeAwardGymCommission's own .catch()
      // below — a bookkeeping failure here must not turn an already-correct
      // revocation into a 500 for the client.
      await reverseCommissionsForPurchase(platform, token, 'apple_revoked').catch((e) => {
        functions.logger.error('validatePurchase: reverseCommissionsForPurchase failed', {
          uid, error: e.message,
        });
      });
      throw new functions.https.HttpsError('failed-precondition', 'purchase_revoked');
    }

    // ── Dedupe (replay / cross-account sharing) ──
    const fresh = await claimPurchaseToken(platform, token, uid, productId);
    if (!fresh) {
      throw new functions.https.HttpsError('already-exists', 'purchase_already_processed');
    }

    // ── Grant ──
    if (product.kind === 'consumable') {
      await grantBonusCredits(uid, product.bonusCredits);
      return { ok: true, granted: 'credits', count: product.bonusCredits };
    }
    const exp = expiresAt || new Date(Date.now() + product.days * 86400000);
    await grantPremium(uid, { productId, expiresAt: exp, source: platform, txId: String(token) });

    // Faz 6 §6.6 — gym revenue share. Strictly AFTER the premium grant above
    // has already committed; entirely server-side, never client-triggered.
    // Best-effort: a bookkeeping failure here must not turn an already-valid,
    // already-granted purchase into an error response for the paying user.
    // platform/token passed through so the commission entry (if any) can
    // carry a purchase_key for later reversal — see economy.js.
    await maybeAwardGymCommission(uid, productId, platform, token).catch((e) => {
      functions.logger.error('validatePurchase: maybeAwardGymCommission failed', {
        uid, productId, error: e.message,
      });
    });

    return { ok: true, granted: 'premium', expiresAt: exp.toISOString() };
  });

// ─── Store notifications → revoke on refund/chargeback/expiry ────────────────
// Wire these in the stores before go-live (App Store Server Notifications V2;
// Google RTDN Pub/Sub topic 'play-rtdn'). Both look up the affected user via
// entitlements.latest_transaction_id and revoke. Left as explicit handlers so
// refund abuse (audit H30) is closed when monetization launches.

exports.appStoreNotifications = functions.https.onRequest(async (req, res) => {
    try {
      const payload = req.body && req.body.signedPayload;
      if (!payload) {
        res.status(400).send('missing signedPayload');
        return;
      }
      const notification = decodeJwsPayload(payload);
      const type = notification.notificationType; // REFUND, REVOKE, EXPIRED, ...
      const txInfo = notification.data && notification.data.signedTransactionInfo
        ? decodeJwsPayload(notification.data.signedTransactionInfo) : null;
      const txId = txInfo && txInfo.originalTransactionId;
      if (['REFUND', 'REVOKE', 'EXPIRED'].includes(type) && txId) {
        const snap = await admin.firestore().collection('entitlements')
          .where('latest_transaction_id', '==', String(txId)).limit(1).get();
        if (!snap.empty) await revokePremium(snap.docs[0].id, `apple_${type}`);
        // Commission reversal is keyed off platform+txId directly (see
        // purchaseCorrelationKey), not off the uid resolved above — so this
        // runs regardless of whether the entitlements lookup found a match.
        //
        // Deliberately only REFUND/REVOKE, NOT EXPIRED — EXPIRED means the
        // subscription's paid period simply ended without renewing, which
        // does not retroactively invalidate the purchase(s) that already
        // happened and were already correctly commissioned. Reversing on
        // EXPIRED would silently claw back a gym's commission the instant
        // every non-renewing member's subscription lapses, which is not
        // what marketplace_terms_{en,tr}.md §6/§10 promise ("refunded or
        // charged-back transactions") — unlike entitlement revocation just
        // above, which correctly treats EXPIRED the same as REFUND/REVOKE
        // (losing premium ACCESS is correct either way; losing an ALREADY
        // -EARNED commission for a non-refunded purchase is not).
        if (['REFUND', 'REVOKE'].includes(type)) {
          await reverseCommissionsForPurchase('ios', txId, `apple_${type}`).catch((e) => {
            functions.logger.error('appStoreNotifications: reverseCommissionsForPurchase failed', {
              txId, type, error: e.message,
            });
          });
        }
      }
      res.status(200).send('ok');
    } catch (e) {
      functions.logger.error('appStoreNotifications error', { error: e.message });
      res.status(200).send('ok'); // ack to avoid retries storms; logged for review
    }
  });

exports.playRtdn = functions.pubsub
  .topic('play-rtdn')
  .onPublish(async (message) => {
    try {
      const data = message.json || {};
      const sub = data.subscriptionNotification;
      const voided = data.voidedPurchaseNotification;
      // notificationType 13 = EXPIRED, 12 = REVOKED for subscriptions.
      // `voidedPurchaseNotification` (one-time purchases) carries its OWN
      // `purchaseToken` under a completely different object than
      // `subscriptionNotification` — reading only `sub.purchaseToken` (as
      // this used to) left `token` permanently undefined for every voided
      // one-time purchase, so neither the `processed_purchases` lookup below
      // nor commission reversal ever matched a real doc for that entire
      // notification type. Fixed: read whichever of the two objects is
      // actually present.
      const token = (sub && sub.purchaseToken) || (voided && voided.purchaseToken);
      if (voided || (sub && [12, 13].includes(sub.notificationType))) {
        const id = `android_${Buffer.from(String(token || '')).toString('base64url').slice(0, 256)}`;
        const proc = await admin.firestore().collection('processed_purchases').doc(id).get();
        if (proc.exists) await revokePremium(proc.data().uid, 'google_revoked_or_expired');
        //
        // Commission reversal only for a genuine refund/void-style event —
        // `voided` (Google's voidedPurchaseNotification) and
        // notificationType 12 (REVOKED) both represent money actually being
        // given back. notificationType 13 (EXPIRED) deliberately does NOT
        // reverse a commission, same reasoning as appStoreNotifications
        // above: a lapsed, non-renewed subscription doesn't retroactively
        // invalidate a past, non-refunded, already-commissioned purchase —
        // only entitlement access (revoked unconditionally above) should
        // react to a plain expiry.
        if (token && (voided || (sub && sub.notificationType === 12))) {
          const reason = voided ? 'google_voided' : 'google_revoked';
          await reverseCommissionsForPurchase('android', token, reason).catch((e) => {
            functions.logger.error('playRtdn: reverseCommissionsForPurchase failed', { error: e.message });
          });
        }
      }
    } catch (e) {
      functions.logger.error('playRtdn error', { error: e.message });
    }
  });

module.exports.PURCHASE_SECRETS = PURCHASE_SECRETS;
