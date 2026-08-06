'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 3 §3.2 — plan-template offer creation (server-only). Extended §3.5 with
// the full send/respond flow.
//
// firestore.rules makes users/{uid}/plan_offers/{id}'s `create` server-only
// (`allow create: if false`) so a client can never forge who an offer is
// from, plant one on someone who was never offered anything, or fake the
// immutable template_snapshot. This callable is that server path.
//
// Faz 3 §3.5 additions: `sendPlanOffer` now also creates the `plan_offer`-
// typed chat message (denormalized, so both chat participants can render it
// without either needing to read the recipient-only `plan_offers` doc) and
// the recipient's `planOfferReceived` notification, in the same server write.
// The member-picker/composer UI, offer inbox, and offer-preview screen all
// live in `lib/screens/plan_offers/` and consume this callable (or the
// direct client `plan_offers` update the rules suite already verifies for
// accept/decline) rather than duplicate its authority checks.
// `onPlanOfferResponded` (below) reacts to that direct client update to fire
// the sender-facing decline notification; `expirePlanOffers` (below) is the
// 14-day auto-expiry sweep.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');
const { writeNotification, fetchActor } = require('./notifications');
const { awardXp, xpEntry } = require('./progress');
const { awardTemplateUsedCredit } = require('./engagement_credit');
const { getConfig } = require('./app_config');

// Faz A Faz 4 — FALLBACK defaults; app_config/server's `templates.*` fields
// are the live source once seeded (see templatesConfig() below).
const MAX_RECIPIENTS_PER_CALL_DEFAULT = 100;
const MAX_MESSAGE_LENGTH_DEFAULT = 500;
const OFFER_TTL_DAYS_DEFAULT = 14; // §3.5: "14 günde otomatik expired"

/** Live app_config/server `templates.*` fields, or {} if unset/unreachable. */
async function templatesConfig() {
  const cfg = await getConfig();
  return (cfg && cfg.templates) || {};
}

async function isAdminUid(db, uid) {
  const snap = await db.collection('admin_roles').doc(uid).get();
  return snap.exists && snap.data().is_admin === true;
}

// A recipient must have a REAL, pre-existing relationship to the sender —
// never an arbitrary uid ("alıcının izni sunucuda doğrulanır"). Gym
// templates can only go to that gym's own members; coach templates only to
// that coach's own ACTIVE clients (coach_profiles/{coachUid}/clients/{uid},
// status == 'active' — CoachClientStatus.active); admin templates can go to
// any registered user (site-curated broadcast).
async function isEligibleRecipient(db, { authorType, gymId, authorUid, toUid }) {
  const userSnap = await db.collection('users').doc(toUid).get();
  if (!userSnap.exists) return false;

  if (authorType === 'gym') {
    if (!gymId) return false;
    const memberSnap = await db.collection('gyms').doc(gymId).collection('members').doc(toUid).get();
    return memberSnap.exists;
  }
  if (authorType === 'coach') {
    const clientSnap = await db.collection('coach_profiles').doc(authorUid).collection('clients').doc(toUid).get();
    return clientSnap.exists && clientSnap.data().status === 'active';
  }
  // 'admin' — any registered user is a valid recipient.
  return true;
}

exports.sendPlanOffer = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const tCfg = await templatesConfig();
  const maxMessageLength = typeof tCfg.max_message_length === 'number'
    ? tCfg.max_message_length : MAX_MESSAGE_LENGTH_DEFAULT;
  const maxRecipientsPerCall = typeof tCfg.max_recipients_per_call === 'number'
    ? tCfg.max_recipients_per_call : MAX_RECIPIENTS_PER_CALL_DEFAULT;
  const offerTtlDays = typeof tCfg.offer_ttl_days === 'number'
    ? tCfg.offer_ttl_days : OFFER_TTL_DAYS_DEFAULT;

  const templateId = data && typeof data.templateId === 'string' ? data.templateId : '';
  const rawToUids = data && Array.isArray(data.toUids)
    ? data.toUids
    : (data && typeof data.toUid === 'string' ? [data.toUid] : []);
  // De-dupe and drop self — sending a template to yourself isn't a real
  // offer (mirrors applyReferral's no-self-referral guard).
  const toUids = [...new Set(rawToUids.filter((u) => typeof u === 'string' && u.length > 0))]
    .filter((u) => u !== uid);
  const message = data && typeof data.message === 'string'
    ? data.message.slice(0, maxMessageLength)
    : '';

  if (!templateId || toUids.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'templateId and at least one recipient are required');
  }
  if (toUids.length > maxRecipientsPerCall) {
    throw new functions.https.HttpsError('invalid-argument', 'too_many_recipients');
  }

  const db = admin.firestore();
  const templateRef = db.collection('meal_plan_templates').doc(templateId);
  const [templateSnap, callerSnap, callerIsAdmin] = await Promise.all([
    templateRef.get(),
    db.collection('users').doc(uid).get(),
    isAdminUid(db, uid),
  ]);

  if (!templateSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'template_not_found');
  }
  const template = templateSnap.data();

  // Sender authority: only the template's own author (or a site admin) may
  // send it. A gym/coach's template is authored BY that gym owner's/coach's
  // own uid — there is no separate "gym staff" role modeled yet — so this
  // already covers the common case; extending it to a colleague sending
  // another staff member's template is a future §3.5 decision, not made
  // here.
  if (template.author_uid !== uid && !callerIsAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'not_template_author');
  }

  const eligibility = await Promise.all(toUids.map((toUid) => isEligibleRecipient(db, {
    authorType: template.author_type,
    gymId: template.gym_id,
    authorUid: template.author_uid,
    toUid,
  })));
  const ineligibleIdx = eligibility.findIndex((ok) => !ok);
  if (ineligibleIdx !== -1) {
    throw new functions.https.HttpsError('permission-denied', `recipient_not_eligible:${toUids[ineligibleIdx]}`);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const expiresAt = new Date(Date.now() + offerTtlDays * 86400000);
  const fromName = (callerSnap.exists && callerSnap.data().displayName) || template.name || 'Cookrange';

  // Faz 3 §3.5: resolve (or create) each recipient's private 1:1 chat with
  // the sender ONCE up front — one query for ALL of the sender's existing
  // private chats, rather than one "does a chat already exist" query per
  // recipient (R1 — this callable accepts up to MAX_RECIPIENTS_PER_CALL=100
  // recipients in a single call). Mirrors ChatService.createOrGetPrivateChat's
  // find-or-create shape; a real single-collection query for "my chats with
  // exactly this other uid" doesn't exist in Firestore (no exact-array-match
  // query), so filtering a bounded scan in memory is the same approach the
  // client-side version already takes, just amortized across every
  // recipient in this call instead of repeated per-recipient.
  const MAX_SENDER_CHATS_SCAN = 1000;
  const senderChatsSnap = await db.collection('chats')
    .where('participants', 'array-contains', uid)
    .limit(MAX_SENDER_CHATS_SCAN)
    .get();
  const chatIdByRecipient = new Map();
  senderChatsSnap.docs.forEach((doc) => {
    const participants = doc.data().participants || [];
    if (participants.length === 2) {
      const other = participants.find((p) => p !== uid);
      if (other) chatIdByRecipient.set(other, doc.id);
    }
  });

  const batch = db.batch();
  const notifyContexts = [];
  for (const toUid of toUids) {
    const offerRef = db.collection('users').doc(toUid).collection('plan_offers').doc();
    batch.set(offerRef, {
      template_id: templateId,
      // Immutable copy taken NOW — if the template is edited or deleted
      // later, this offer is unaffected (§3.2).
      template_snapshot: template,
      from_uid: uid,
      from_type: template.author_type,
      from_name: fromName,
      message,
      status: 'pending',
      created_at: now,
      expires_at: expiresAt,
      responded_at: null,
    });

    // Faz 3 §3.5: pair the offer with a `plan_offer`-typed chat message, in
    // the SAME server-authoritative write — not a second client round-trip
    // (which could fail/race after the offer already exists), and not a raw
    // ad hoc shape: every field below matches what ChatService.sendMessage/
    // MessageModel.toJson already produce, so onChatMessageCreated
    // (functions/index.js) fires exactly as it would for any client-sent
    // message (unread count + push). Fields the sender AND recipient both
    // need to render the card are denormalized directly onto the message
    // (`plan_offer` map) — `plan_offers` read is recipient-only, so the
    // sender's own copy of this chat could never re-fetch the offer live.
    const existingChatId = chatIdByRecipient.get(toUid);
    const chatRef = existingChatId
      ? db.collection('chats').doc(existingChatId)
      : db.collection('chats').doc();
    const messageRef = chatRef.collection('messages').doc();
    const messageData = {
      id: messageRef.id,
      senderId: uid,
      type: 'plan_offer',
      body: message,
      attachments: [],
      reactions: {},
      is_deleted: false,
      delivered_to: [],
      read_by: [],
      mentions: [],
      server_timestamp: now,
      timestamp: now, // compat mirror — matches ChatService.sendMessage's own dual-write
      client_id: messageRef.id,
      plan_offer: {
        offer_id: offerRef.id,
        template_id: templateId,
        template_name: template.name || '',
        target_calories: template.target_calories || 0,
        from_name: fromName,
      },
    };
    batch.set(messageRef, messageData);
    if (existingChatId) {
      batch.update(chatRef, { lastMessage: messageData, updatedAt: now });
    } else {
      batch.set(chatRef, {
        participants: [uid, toUid],
        unreadCounts: { [uid]: 0, [toUid]: 0 },
        type: 'private',
        updatedAt: now,
        createdBy: uid,
        lastMessage: messageData,
      });
    }

    notifyContexts.push({ toUid, offerId: offerRef.id });
  }
  // usage_count is server-only (touchesProtectedTemplateFields,
  // firestore.rules) — bumped here by exactly the number of new offers.
  batch.update(templateRef, {
    usage_count: admin.firestore.FieldValue.increment(toUids.length),
  });
  await batch.commit();

  // Faz 3 §3.5: recipient notification — after the durable write above has
  // already succeeded (the offer + chat message are what matters; a
  // notification is a courtesy, same ordering sendAdminNotification's
  // siblings in this codebase already use).
  await Promise.all(notifyContexts.map(({ toUid, offerId }) => writeNotification(db, {
    targetUid: toUid,
    type: 'planOfferReceived',
    actorUid: uid,
    actorName: fromName,
    relatedId: offerId,
    metadata: { templateName: template.name || '' },
  })));

  functions.logger.info('sendPlanOffer: ok', { uid, templateId, count: toUids.length });
  return { ok: true, sent: toUids.length };
});

/**
 * Faz 3 §3.5 — reacts to the recipient's own direct Firestore update. No
 * callable exists for accept/decline: firestore.rules' plan_offers update
 * rule already lets the recipient flip pending -> accepted/declined
 * directly (the rules suite verifies exactly that), so this trigger is the
 * ONLY place the sender-facing notification can be written (`notifications/*`
 * create is server-only). Mirrors onChatMessageCreated/onGymPresenceCreated's
 * "client writes the allowed primary mutation, a trigger reacts with the
 * server-only side effect" pattern already used elsewhere in this codebase.
 *
 * Deliberately notifies the SENDER only on decline, never on accept — §3.5's
 * own text asks for a notification on decline ("gönderene sessiz bildirim")
 * and says nothing about one on accept; inventing an unrequested
 * `planOfferAccepted` type here would be scope creep, not scope completion.
 *
 * Faz 5 §5.1 addition: on accept, the MEMBER (not the sender) is awarded
 * `template_accepted` XP — NEVER client-reported (see progress.js's header
 * comment): this trigger firing on a real `pending -> accepted` transition,
 * already gated by firestore.rules to the recipient and to exactly once, IS
 * the server-side proof: no additional verification is needed.
 *
 * Faz 5 §5.2 addition: on the SAME accept, the template's AUTHOR (`from_uid`
 * — the gym/coach/admin who sent it, NOT the member accepting it) gets a
 * shot at "şablonun/tarifin başkası tarafından kullanıldı" received-
 * engagement credit — see `engagement_credit.js`'s `awardTemplateUsedCredit`
 * for the anti-abuse gating (account eligibility, reciprocity/concentration
 * weight). `sendPlanOffer` already forbids sending a template to yourself,
 * so author == acceptor is structurally impossible here, but
 * `awardTemplateUsedCredit` checks it anyway, defensively.
 */
exports.onPlanOfferResponded = functions.firestore
  .document('users/{uid}/plan_offers/{offerId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status !== 'pending') return;

    const db = admin.firestore();
    const memberUid = context.params.uid;

    if (after.status === 'accepted') {
      const t = await xpEntry('template_accepted');
      await awardXp(db, memberUid, 'template_accepted', context.params.offerId, t.points, t.dailyCap)
        .catch((e) => functions.logger.error('onPlanOfferResponded: awardXp(template_accepted) failed', {
          offerId: context.params.offerId, memberUid, error: e.message,
        }));
      await awardTemplateUsedCredit(db, {
        authorUid: after.from_uid,
        acceptingUid: memberUid,
        refId: context.params.offerId,
      }).catch((e) => functions.logger.error('onPlanOfferResponded: awardTemplateUsedCredit failed', {
        offerId: context.params.offerId, memberUid, error: e.message,
      }));
      return;
    }
    if (after.status !== 'declined') return;

    const actor = await fetchActor(db, memberUid);
    const reason = typeof after.decline_reason === 'string' && after.decline_reason
      ? after.decline_reason
      : undefined;

    await writeNotification(db, {
      targetUid: after.from_uid,
      type: 'planOfferDeclined',
      actorUid: memberUid,
      actorName: actor.displayName,
      actorPhotoUrl: actor.photoURL,
      relatedId: context.params.offerId,
      metadata: reason ? { reason } : undefined,
    });

    functions.logger.info('onPlanOfferResponded: notified sender', {
      offerId: context.params.offerId, fromUid: after.from_uid,
    });
  });

/**
 * Faz 3 §3.5 — "14 günde otomatik expired". Scheduled sweep, same shape as
 * endExpiredGymWars (query a status + a date bound, batch-flip, log) but
 * over a COLLECTION GROUP: plan_offers lives at users/{uid}/plan_offers/{id},
 * under every user, not one top-level collection like gym_wars — needs its
 * own composite index (queryScope COLLECTION_GROUP, status ASC + expires_at
 * ASC), separate from the COLLECTION-scoped one the offer inbox query uses
 * (firestore.indexes.json).
 *
 * No notification is sent here — a silent status flip only. The member
 * already let a 14-day window pass without responding; telling them "your
 * ignored offer expired" is exactly the pressure §3.5 says a member should
 * never feel, and nobody asked for one.
 */
exports.expirePlanOffers = functions
  .pubsub
  .schedule('every 60 minutes')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collectionGroup('plan_offers')
      .where('status', '==', 'pending')
      .where('expires_at', '<=', now)
      .limit(300)
      .get();

    if (snap.empty) {
      functions.logger.info('expirePlanOffers: no expired offers');
      return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.update(doc.ref, { status: 'expired' }));
    await batch.commit();

    functions.logger.info('expirePlanOffers: done', { expired: snap.size });
  });

// Faz A (config migration) — export names kept stable, see presence.js's
// identical comment.
Object.assign(module.exports, {
  OFFER_TTL_DAYS: OFFER_TTL_DAYS_DEFAULT,
  MAX_RECIPIENTS_PER_CALL: MAX_RECIPIENTS_PER_CALL_DEFAULT,
  MAX_MESSAGE_LENGTH: MAX_MESSAGE_LENGTH_DEFAULT,
  templatesConfig,
});
