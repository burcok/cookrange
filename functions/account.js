'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Server-side account erasure (GDPR Art.17 / KVKK Art.7 — right to be forgotten).
//
// The client-side delete only removed 6 subcollections and no Storage, leaving
// health PII, meal photos, achievements, AI history, commissions, and ID
// documents behind. This callable performs a COMPLETE, recursive erasure with
// the Admin SDK: the entire users/{uid} subtree, all server-only docs, authored
// top-level content, every Storage prefix, and finally the Auth user.
//
// Flow: the client re-authenticates (proves identity), calls this, then signs
// out. context.auth gives us the verified uid — a user can only erase THEMSELVES.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');

async function deleteByQuery(db, query) {
  const snap = await query.get();
  // recursiveDelete each matched doc so nested subcollections (e.g. post
  // comments/likes) are removed too.
  await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
  return snap.size;
}

async function deleteStoragePrefixes(uid) {
  const bucket = admin.storage().bucket();
  const prefixes = [
    `profile_photos/${uid}`,
    `post_images/${uid}`,
    `chat_images/${uid}`,
    `gym_applications/${uid}`,
    `coach_applications/${uid}`,
  ];
  await Promise.all(
    prefixes.map((prefix) =>
      bucket
        .deleteFiles({ prefix })
        .catch((e) =>
          functions.logger.warn('deleteFiles failed', { prefix, error: e.message })
        )
    )
  );
}

exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const db = admin.firestore();
  functions.logger.info('deleteUserAccount: start', { uid });

  try {
    // 1. The entire owner subtree (profile + every subcollection: private
    //    nutrition PII, food_logs, food_analyses, meal_plans, achievements,
    //    consents, ai_*, favorites, recent_foods, recipe_notes, commissions,
    //    payout_requests, following/followers, program_enrollments,
    //    plan_offers (Faz 3 §3.2), …).
    await db.recursiveDelete(db.collection('users').doc(uid));

    // 2. Server-only docs keyed by uid.
    //    Faz 6 §6.5: gym_attributions/{uid} is a NEW top-level, uid-keyed doc
    //    (like entitlements/ai_credits above) that predates account deletion
    //    coverage without this line — added here, not left as a fresh gap.
    //    Safe even for a never-attributed user: delete() on a missing doc is
    //    a no-op, not an error. This does NOT touch the gym owner's own
    //    already-recorded `commissions` ledger entry (a separate doc under
    //    THEIR subtree, referencing this uid only by value) — the gym's
    //    accounting record survives exactly as it should; only the
    //    attribution FACT tied to the now-deleted account is erased.
    await Promise.all([
      db.collection('entitlements').doc(uid).delete(),
      db.collection('ai_credits').doc(uid).delete(),
      db.collection('logs').doc(uid).delete(),
      db.collection('gym_attributions').doc(uid).delete(),
      db.recursiveDelete(db.collection('notifications').doc(uid)),
    ]);

    // 3. Authored top-level content (recursiveDelete clears nested comments/likes).
    await deleteByQuery(db, db.collection('posts').where('authorId', '==', uid));
    await deleteByQuery(db, db.collection('signals').where('userId', '==', uid));
    await deleteByQuery(db, db.collection('coach_profiles').where(admin.firestore.FieldPath.documentId(), '==', uid));
    await deleteByQuery(db, db.collection('referrals').where('owner_uid', '==', uid));
    // Faz 3 §3.2: meal_plan_templates authored by this uid. Safe to delete
    // outright — any plan_offers already sent from them hold an immutable
    // template_snapshot copy (§3.2), not a live reference, so this can never
    // leave a dangling pointer in someone else's offer inbox.
    await deleteByQuery(db, db.collection('meal_plan_templates').where('author_uid', '==', uid));

    // 4. Storage objects.
    await deleteStoragePrefixes(uid);

    // 5. Finally remove the Firebase Auth identity.
    await admin.auth().deleteUser(uid);

    // M5.1 (admin_stats rollup) — nothing else records that an account
    // deletion happened; this recursive erasure + the Auth delete above
    // are the only trace otherwise. A day-bucket increment, mirroring
    // index.js's recordUsage/ai_usage_stats pattern. Best-effort: a
    // stats-write hiccup must never fail a GDPR/KVKK erasure that has
    // already succeeded.
    const dayKey = new Date().toISOString().slice(0, 10);
    await db
      .collection('admin_stats')
      .doc(`day_${dayKey}`)
      .set(
        {
          day: dayKey,
          users: { account_deletions: admin.firestore.FieldValue.increment(1) },
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      )
      .catch((e) => functions.logger.error('deleteUserAccount: admin_stats increment failed', { uid, error: e.message }));

    functions.logger.info('deleteUserAccount: done', { uid });
    return { ok: true };
  } catch (e) {
    functions.logger.error('deleteUserAccount failed', { uid, error: e.message });
    throw new functions.https.HttpsError('internal', 'erasure_failed');
  }
});
