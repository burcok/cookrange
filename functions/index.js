'use strict';

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const fetch = require('node-fetch');

admin.initializeApp();

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'openrouter/free';

/**
 * AI proxy endpoint — keeps OPENROUTER_API_KEY server-side.
 *
 * Set the secret before deploying:
 *   firebase functions:secrets:set OPENROUTER_API_KEY
 *
 * Request body (JSON):
 *   { messages: [...], model?: string, temperature?: number }
 *
 * Authorization:
 *   Bearer <Firebase ID token>
 */
exports.aiProxy = functions
  .runWith({ secrets: ['OPENROUTER_API_KEY'] })
  .https.onRequest(async (req, res) => {
    // CORS headers (Flutter app uses HTTPS, not a browser, so this is minimal)
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    // Verify Firebase ID token
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization header' });
      return;
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired ID token' });
      return;
    }

    // Verify App Check token (if present — clients without App Check still work
    // during rollout; enforce strictly once all clients are updated).
    const appCheckToken = req.headers['x-firebase-appcheck'];
    if (appCheckToken) {
      try {
        await admin.appCheck().verifyToken(appCheckToken);
      } catch (e) {
        functions.logger.warn('App Check token verification failed', e);
        res.status(401).json({ error: 'Invalid App Check token' });
        return;
      }
    }

    const { messages, model, temperature } = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'messages array is required' });
      return;
    }

    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      functions.logger.error('OPENROUTER_API_KEY secret not set');
      res.status(500).json({ error: 'AI proxy not configured' });
      return;
    }

    try {
      const upstream = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': 'https://cookrangeapp.com',
          'X-Title': 'Cookrange',
        },
        body: JSON.stringify({
          model: model || DEFAULT_MODEL,
          messages,
          temperature: temperature ?? 0.7,
        }),
      });

      const data = await upstream.json();

      if (!upstream.ok) {
        functions.logger.warn('OpenRouter error', { status: upstream.status, data });
        res.status(upstream.status).json(data);
        return;
      }

      res.status(200).json(data);
    } catch (e) {
      functions.logger.error('aiProxy fetch error', e);
      res.status(502).json({ error: 'Upstream AI request failed' });
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// Push Notification Fan-out
// ─────────────────────────────────────────────────────────────────────────────

/** Maps in-app notification type strings to mute-group keys. */
const TYPE_TO_MUTE_GROUP = {
  likePost: 'likes',
  likeComment: 'likes',
  reaction: 'likes',
  like: 'likes',
  comment: 'comments',
  friendRequest: 'friends',
  friendAccepted: 'friends',
  follow: 'friends',
  system: 'system',
  streakMilestone: 'system',
  mealPlan: 'system',
  coachApplicationApproved: 'system',
  coachApplicationRejected: 'system',
  gymApplicationApproved: 'system',
  gymApplicationRejected: 'system',
  referral: 'referral',
};

/** Returns the English push title + body for a given notification type. */
function getPushText(type, actorName, metadata) {
  const name = actorName || 'Someone';
  switch (type) {
    case 'likePost':
    case 'like':
      return { title: `${name} liked your post`, body: '' };
    case 'likeComment':
      return { title: `${name} liked your comment`, body: '' };
    case 'reaction': {
      const emoji = (metadata && metadata.emoji) || '❤️';
      return { title: `${name} reacted ${emoji}`, body: '' };
    }
    case 'comment':
      return { title: `${name} commented`, body: '' };
    case 'friendRequest':
      return { title: 'Friend Request', body: `${name} wants to connect` };
    case 'friendAccepted':
      return { title: 'New Friend!', body: `${name} accepted your request` };
    case 'follow':
      return { title: `${name} is following you`, body: '' };
    case 'streakMilestone': {
      const days = (metadata && metadata.streakDays) || '';
      return { title: '🔥 Streak Milestone!', body: days ? `${days} day streak — keep going!` : 'New streak milestone!' };
    }
    case 'mealPlan':
      return { title: 'Meal Plan Ready', body: 'Your weekly plan has been updated' };
    case 'referral':
      return { title: 'Referral Reward!', body: `${name} used your referral code` };
    case 'coachApplicationApproved':
      return { title: 'Application Approved ✅', body: 'Your coach profile is now live' };
    case 'coachApplicationRejected':
      return { title: 'Application Update', body: 'Check your coach application status' };
    case 'gymApplicationApproved':
      return { title: 'Application Approved ✅', body: 'Your gym is now live on Cookrange' };
    case 'gymApplicationRejected':
      return { title: 'Application Update', body: 'Check your gym application status' };
    default:
      return { title: 'Cookrange', body: 'You have a new notification' };
  }
}

/**
 * Sends a single FCM message. On stale-token errors the token is removed from
 * the user doc so future calls don't waste quota.
 */
async function sendFcm(uid, token, title, body, data) {
  const db = admin.firestore();
  try {
    const message = {
      token,
      notification: { title },
      data: Object.fromEntries(
        Object.entries(data)
          .filter(([, v]) => v !== null && v !== undefined && v !== '')
          .map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: { channelId: 'cookrange_default', sound: 'default' },
      },
      apns: { payload: { aps: { badge: 1, sound: 'default' } } },
    };
    if (body) message.notification.body = body;

    await admin.messaging().send(message);
    return true;
  } catch (e) {
    if (
      e.code === 'messaging/registration-token-not-registered' ||
      e.code === 'messaging/invalid-registration-token'
    ) {
      functions.logger.info('Removing stale FCM token', { uid });
      await db.collection('users').doc(uid).update({
        fcm_token: admin.firestore.FieldValue.delete(),
      });
    } else {
      functions.logger.warn('FCM send failed', { uid, code: e.code, error: e.message });
    }
    return false;
  }
}

/**
 * Firestore trigger: fans out a push notification whenever an in-app
 * notification doc is created at notifications/{uid}/items/{docId}.
 *
 * Respects the recipient's notification_muted preferences.
 */
exports.onInAppNotificationCreated = functions
  .firestore
  .document('notifications/{uid}/items/{docId}')
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;
    const doc = snap.data();
    const type = doc.type || '';
    const actorName = doc.actorName || '';
    const relatedId = doc.relatedId || '';
    const actorUid = doc.actorUid || '';
    const metadata = doc.metadata || {};

    // Fetch recipient — need their FCM token and mute prefs
    const userSnap = await admin.firestore().collection('users').doc(uid).get();
    if (!userSnap.exists) return;
    const userData = userSnap.data();

    const token = userData.fcm_token;
    if (!token) {
      functions.logger.info('No FCM token for user', { uid, type });
      return;
    }

    // Honour mute-group preference
    const muteGroup = TYPE_TO_MUTE_GROUP[type];
    if (muteGroup) {
      const mutedMap = userData.notification_muted || {};
      if (mutedMap[muteGroup] === true) {
        functions.logger.info('Notification muted', { uid, type, muteGroup });
        return;
      }
    }

    const { title, body } = getPushText(type, actorName, metadata);
    const sent = await sendFcm(uid, token, title, body, {
      type,
      relatedId,
      actorUid,
    });

    functions.logger.info('onInAppNotificationCreated', { uid, type, sent });
  });

/**
 * Firestore trigger: sends a push notification to every chat participant
 * (excluding the sender) whenever a new message is created.
 */
exports.onChatMessageCreated = functions
  .firestore
  .document('chats/{chatId}/messages/{msgId}')
  .onCreate(async (snap, context) => {
    const chatId = context.params.chatId;
    const msg = snap.data();
    const senderId = msg.senderId;
    const text = (msg.text || '').slice(0, 100);
    if (!senderId) return;

    // Fetch chat doc to get participants list
    const chatSnap = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    const participants = chatSnap.data().participants || [];

    // Fetch sender display name (one extra read; cached inside Promises below)
    const senderSnap = await admin.firestore().collection('users').doc(senderId).get();
    const senderName = senderSnap.exists
      ? (senderSnap.data().displayName || 'Someone')
      : 'Someone';

    const recipients = participants.filter((p) => p !== senderId);
    if (!recipients.length) return;

    await Promise.all(recipients.map(async (uid) => {
      const userSnap = await admin.firestore().collection('users').doc(uid).get();
      if (!userSnap.exists) return;
      const token = userSnap.data().fcm_token;
      if (!token) return;

      await sendFcm(uid, token, senderName, text || '📷 Image', {
        type: 'chat',
        chatId,
        actorUid: senderId,
      });
    }));

    functions.logger.info('onChatMessageCreated', { chatId, recipients: recipients.length });
  });

// ─────────────────────────────────────────────────────────────────────────────
// Admin Broadcasts
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Resolves the list of user UIDs that match a broadcast audience selector.
 * audience: 'all' | 'coaches' | 'gymOwners' | 'user:{uid}'
 *
 * Capped at 500 recipients for MVP to stay within FCM batch limits.
 */
async function resolveBroadcastAudience(audience) {
  const db = admin.firestore();
  const MAX = 500;

  if (audience.startsWith('user:')) {
    const uid = audience.slice(5);
    return uid ? [uid] : [];
  }

  let query = db.collection('users').limit(MAX);
  if (audience === 'coaches') {
    query = query.where('role', '==', 'coach');
  } else if (audience === 'gymOwners') {
    query = query.where('role', '==', 'gymOwner');
  }
  // 'all' — no filter, just limit

  const snap = await query.get();
  return snap.docs.map((d) => d.id);
}

/**
 * Fans out a broadcast doc to all matching users — FCM push + in-app notification.
 * Returns the number of recipients reached.
 */
async function executeBroadcast(broadcastId, broadcastData) {
  const db = admin.firestore();
  const uids = await resolveBroadcastAudience(broadcastData.audience || 'all');
  functions.logger.info('executeBroadcast', { broadcastId, recipients: uids.length });

  if (!uids.length) return 0;

  // Build per-locale push text
  const titleEn = broadcastData.title_en || 'Cookrange';
  const bodyEn = broadcastData.body_en || '';
  const titleTr = broadcastData.title_tr || titleEn;
  const bodyTr = broadcastData.body_tr || bodyEn;

  let sentCount = 0;

  // Process in chunks to avoid Firestore batch limits (max 500 writes)
  const CHUNK = 200;
  for (let i = 0; i < uids.length; i += CHUNK) {
    const chunk = uids.slice(i, i + CHUNK);
    const batch = db.batch();

    await Promise.all(chunk.map(async (uid) => {
      // Fetch user to get FCM token and locale
      const userSnap = await db.collection('users').doc(uid).get();
      if (!userSnap.exists) return;
      const userData = userSnap.data();

      const locale = userData.locale || 'en';
      const title = locale === 'tr' ? titleTr : titleEn;
      const body = locale === 'tr' ? bodyTr : bodyEn;

      // Write in-app notification
      const notifRef = db.collection('notifications').doc(uid).collection('items').doc();
      batch.set(notifRef, {
        type: 'broadcast',
        actorUid: broadcastData.admin_uid || '',
        actorName: 'Cookrange',
        actorPhotoUrl: '',
        relatedId: broadcastId,
        metadata: { titleEn, bodyEn },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // FCM push (best-effort; don't block batch on this)
      const token = userData.fcm_token;
      if (token) {
        sendFcm(uid, token, title, body, {
          type: 'broadcast',
          relatedId: broadcastId,
        }).then((ok) => { if (ok) sentCount++; });
      }
    }));

    await batch.commit();
  }

  return uids.length;
}

/**
 * Firestore trigger: whenever a new broadcast doc is created, check if it
 * should be sent immediately (status == 'pending'). Scheduled broadcasts
 * (status == 'scheduled') are processed by drainScheduledBroadcasts.
 */
exports.onBroadcastCreated = functions
  .firestore
  .document('broadcasts/{broadcastId}')
  .onCreate(async (snap, context) => {
    const broadcastId = context.params.broadcastId;
    const data = snap.data();

    if (data.status !== 'pending') {
      functions.logger.info('onBroadcastCreated: skipping, status=' + data.status, { broadcastId });
      return;
    }

    try {
      const count = await executeBroadcast(broadcastId, data);
      await snap.ref.update({
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        recipient_count: count,
      });
      functions.logger.info('onBroadcastCreated: sent', { broadcastId, count });
    } catch (e) {
      functions.logger.error('onBroadcastCreated: error', { broadcastId, error: e.message });
      await snap.ref.update({ status: 'failed' });
    }
  });

/**
 * Scheduled function: runs every 5 minutes to drain broadcasts whose
 * scheduled_at time has arrived (status == 'scheduled').
 *
 * Deploy with:
 *   firebase deploy --only functions:drainScheduledBroadcasts
 *
 * Cloud Scheduler is automatically created by Firebase when you deploy
 * a pubsub.schedule function.
 */
exports.drainScheduledBroadcasts = functions
  .pubsub
  .schedule('every 5 minutes')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const due = await db
      .collection('broadcasts')
      .where('status', '==', 'scheduled')
      .where('scheduled_at', '<=', now)
      .limit(10)
      .get();

    if (due.empty) {
      functions.logger.info('drainScheduledBroadcasts: nothing due');
      return;
    }

    functions.logger.info('drainScheduledBroadcasts: processing', { count: due.size });

    await Promise.all(due.docs.map(async (doc) => {
      try {
        const count = await executeBroadcast(doc.id, doc.data());
        await doc.ref.update({
          status: 'sent',
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
          recipient_count: count,
        });
        functions.logger.info('drainScheduledBroadcasts: sent', { broadcastId: doc.id, count });
      } catch (e) {
        functions.logger.error('drainScheduledBroadcasts: error', { broadcastId: doc.id, error: e.message });
        await doc.ref.update({ status: 'failed' });
      }
    }));
  });
