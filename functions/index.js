'use strict';

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const fetch = require('node-fetch');
const { APP_CHECK_ENFORCE } = require('./config');
const { getFcmToken, writeNotification } = require('./notifications');

admin.initializeApp();

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
// Default text model. Prefer the env-configured model (matches the client's
// default) so proxy calls don't get coerced back to the slow free meta-router.
const DEFAULT_MODEL = process.env.OPENROUTER_MODEL || 'openrouter/free';

// ─────────────────────────────────────────────────────────────────────────────
// Server-Side AI Quota Enforcement, Cost Control & Abuse Limits
// ─────────────────────────────────────────────────────────────────────────────
//
// SECURITY MODEL (do not regress):
//  - Credits live in the SERVER-ONLY ledger `ai_credits/{uid}` (owner-read,
//    deny client-write in rules; mutated here via the Admin SDK). They are NOT
//    read from the client-writable user doc — that was self-grantable.
//  - Premium is read from the SERVER-ONLY `entitlements/{uid}` doc, written only
//    by the purchase-validation functions — never from `users/{uid}`.
//  - The model is coerced to an allowlist so a caller cannot bill an expensive
//    model. Output/input are capped. Quota FAILS CLOSED on infra errors.
//  - App Check is mandatory (toggle APP_CHECK_ENFORCE=false only as a temporary
//    rollout escape hatch while clients update).

const FREE_DAILY_LIMIT = 2;
const PREMIUM_DAILY_LIMIT = 20;

// Allowlisted models. Anything else the client sends is coerced to DEFAULT_MODEL.
const ALLOWED_MODELS = new Set(
  [
    'openrouter/free',
    'meta-llama/llama-3.2-11b-vision-instruct:free',
    process.env.OPENROUTER_VISION_MODEL,
    process.env.OPENROUTER_MODEL,
  ].filter(Boolean)
);

// Hard caps bounding per-request cost and resource use.
const MAX_MESSAGES = 30;
const MAX_TOTAL_CHARS = 24000; // serialized messages payload
// Weekly meal-plan / recipe JSON needs real headroom; 1024 truncated them.
const MAX_OUTPUT_TOKENS = 8192;

// Per-uid sliding-window rate limit (independent of the daily quota).
const RATE_WINDOW_MS = 60 * 1000;
const RATE_MAX_IN_WINDOW = 12;

// Query-type allowlist for usage logging (client-supplied `type`, defaulted).
const ALLOWED_TYPES = new Set([
  'meal_plan', 'recipe', 'insight', 'weekly_recap', 'food_photo', 'chat', 'other',
]);

// Per-model price in USD per 1,000,000 tokens (input / output). Approximate
// published OpenRouter rates — verify against openrouter.ai/models. Any model
// ending in ':free' is $0. Unknown paid models record tokens with unpriced=true
// (cost 0) so the admin dashboard can flag "add pricing".
const MODEL_PRICING = {
  'google/gemini-2.0-flash-001': { in: 0.10, out: 0.40 },
  'openai/gpt-4o-mini': { in: 0.15, out: 0.60 },
  'openai/gpt-4o': { in: 2.50, out: 10.0 },
};

function pricingFor(model) {
  if (!model) return { in: 0, out: 0, known: false };
  if (model.endsWith(':free')) return { in: 0, out: 0, known: true };
  const p = MODEL_PRICING[model];
  return p ? { in: p.in, out: p.out, known: true } : { in: 0, out: 0, known: false };
}

// Firestore map keys can't safely contain '.', '/', '*', '[', ']', '~'.
function fieldSafe(s) {
  return String(s || 'unknown').replace(/[^a-zA-Z0-9]/g, '_');
}

/**
 * Records ONE AI request's real token usage + computed cost. Writes a queryable
 * per-request log, bumps the global aggregate, and the per-user lifetime totals
 * on the server-only ledger. Best-effort: never throws into the request path.
 */
async function recordUsage(uid, { type, model, usage, premium, consumed }) {
  try {
    const db = admin.firestore();
    const pt = Number(usage && usage.prompt_tokens) || 0;
    const ct = Number(usage && usage.completion_tokens) || 0;
    const tt = Number(usage && usage.total_tokens) || pt + ct;
    const pr = pricingFor(model);
    const cost = (pt / 1e6) * pr.in + (ct / 1e6) * pr.out;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const inc = admin.firestore.FieldValue.increment;
    const mKey = fieldSafe(model);
    const tKey = fieldSafe(type);

    // Day bucket (UTC) for cheap trend charts.
    const dayKey = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

    await Promise.all([
      // Per-request log (queryable by uid + created_at). Raw model/type kept.
      db.collection('ai_usage_logs').add({
        uid, type, model, premium: !!premium, consumed: consumed || null,
        prompt_tokens: pt, completion_tokens: ct, total_tokens: tt,
        cost_usd: cost, unpriced: !pr.known, created_at: now,
      }),
      // Global running total + by-model / by-type breakdown.
      db.collection('ai_usage_stats').doc('global').set({
        total_requests: inc(1),
        total_tokens: inc(tt),
        total_cost_usd: inc(cost),
        by_model: { [mKey]: { requests: inc(1), tokens: inc(tt), cost_usd: inc(cost) } },
        by_type: { [tKey]: { requests: inc(1), cost_usd: inc(cost) } },
        updated_at: now,
      }, { merge: true }),
      // Daily bucket for the trend line.
      db.collection('ai_usage_stats').doc(`day_${dayKey}`).set({
        day: dayKey,
        requests: inc(1),
        tokens: inc(tt),
        cost_usd: inc(cost),
        updated_at: now,
      }, { merge: true }),
      // Per-user lifetime totals on the server-only ledger.
      db.collection('ai_credits').doc(uid).set({
        lifetime_requests: inc(1),
        lifetime_tokens: inc(tt),
        lifetime_cost_usd: inc(cost),
        last_request_at: now,
        by_type: { [tKey]: inc(1) },
      }, { merge: true }),
    ]);
  } catch (e) {
    functions.logger.error('recordUsage failed', { uid, error: e.message });
  }
}

// App Check enforcement is decided by ./config (enforced in production, relaxed
// in development) — see APP_CHECK_ENFORCE import above.

// In-memory cache of the admin-editable app config (app_config/global). Lets
// admins retune model / max_tokens / quotas WITHOUT redeploying the function.
// Refetched at most every APP_CONFIG_TTL_MS; fails safe to {} (env defaults).
let _appConfigCache = null;
let _appConfigAt = 0;
const APP_CONFIG_TTL_MS = 5 * 60 * 1000;

async function getAppConfig() {
  const now = Date.now();
  if (_appConfigCache && now - _appConfigAt < APP_CONFIG_TTL_MS) {
    return _appConfigCache;
  }
  try {
    const snap = await admin.firestore().collection('app_config').doc('global').get();
    _appConfigCache = snap.exists ? (snap.data() || {}) : {};
  } catch (e) {
    functions.logger.warn('getAppConfig failed — using env defaults', { error: e.message });
    _appConfigCache = _appConfigCache || {};
  }
  _appConfigAt = now;
  return _appConfigCache;
}

function nextMidnightUtc(now) {
  const d = new Date(now);
  d.setUTCHours(24, 0, 0, 0);
  return d;
}

/**
 * Server-authoritative premium check. Reads `entitlements/{uid}` (written only
 * by the purchase-validation functions). Fails CLOSED to free on any error.
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
 * Atomically enforces the per-uid rate limit AND the daily/bonus quota against
 * the server-only ledger `ai_credits/{uid}`, consuming one unit on success.
 *
 * Returns { ok: true, consumed: 'daily'|'bonus' } or
 *         { ok: false, reason: 'rate_limited'|'exceeded' }.
 * THROWS on a transaction/infra failure — the caller MUST fail closed.
 */
async function enforceRateLimitAndQuota(uid, premium, limits) {
  const db = admin.firestore();
  const ref = db.collection('ai_credits').doc(uid);
  const freeLimit = (limits && limits.free) || FREE_DAILY_LIMIT;
  const premiumLimit = (limits && limits.premium) || PREMIUM_DAILY_LIMIT;
  const dailyLimit = premium ? premiumLimit : freeLimit;
  const now = new Date();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? (snap.data() || {}) : {};

    // ── Sliding-window rate limit ──
    const winStart = data.rate_window_start && data.rate_window_start.toDate
      ? data.rate_window_start.toDate() : null;
    const windowExpired = !winStart || (now - winStart) > RATE_WINDOW_MS;
    const reqCount = windowExpired ? 0 : (data.rate_count || 0);
    if (reqCount >= RATE_MAX_IN_WINDOW) {
      return { ok: false, reason: 'rate_limited' };
    }

    // ── Daily reset ──
    const resetAt = data.reset_at && data.reset_at.toDate ? data.reset_at.toDate() : null;
    const dayRolled = !resetAt || now > resetAt;
    const used = dayRolled ? 0 : (data.used_today || 0);
    const bonus = data.bonus || 0;

    // ── Quota check (bonus pool, then daily) ──
    if (bonus <= 0 && used >= dailyLimit) {
      return { ok: false, reason: 'exceeded' };
    }

    const update = {
      rate_window_start: windowExpired
        ? admin.firestore.Timestamp.fromDate(now)
        : data.rate_window_start,
      rate_count: reqCount + 1,
    };
    if (dayRolled) {
      update.reset_at = admin.firestore.Timestamp.fromDate(nextMidnightUtc(now));
    }

    let consumed;
    if (bonus > 0) {
      update.bonus = admin.firestore.FieldValue.increment(-1);
      if (dayRolled) update.used_today = 0;
      consumed = 'bonus';
    } else {
      update.used_today = used + 1;
      consumed = 'daily';
    }

    tx.set(ref, update, { merge: true });
    return { ok: true, consumed };
  });
}

/**
 * Rolls back a previously consumed unit when the upstream AI request fails.
 */
async function rollbackConsume(uid, consumed) {
  if (consumed !== 'daily' && consumed !== 'bonus') return;
  const ref = admin.firestore().collection('ai_credits').doc(uid);
  try {
    const field = consumed === 'bonus' ? 'bonus' : 'used_today';
    const delta = consumed === 'bonus' ? 1 : -1;
    await ref.set(
      { [field]: admin.firestore.FieldValue.increment(delta) },
      { merge: true }
    );
    functions.logger.info('rollbackConsume', { uid, consumed });
  } catch (e) {
    functions.logger.error('rollbackConsume failed', { uid, error: e.message });
  }
}

/**
 * AI proxy endpoint — keeps OPENROUTER_API_KEY server-side and enforces
 * attestation, auth, rate limits, quotas, model allowlist, and payload caps.
 *
 * Set the secret before deploying:
 *   firebase functions:secrets:set OPENROUTER_API_KEY
 *
 * Request body (JSON):
 *   { messages: [...], model?: string, temperature?: number }
 *
 * Headers: Authorization: Bearer <Firebase ID token>, X-Firebase-AppCheck: <token>
 */
exports.aiProxy = functions
  .runWith({
    // OPENROUTER_API_KEY is read from process.env (functions/.env). For extra
    // hardening in production you can instead bind it via Secret Manager:
    //   secrets: ['OPENROUTER_API_KEY'],
    maxInstances: 20,
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest(async (req, res) => {
    // No wildcard CORS — this is a mobile client, not a browser app.
    res.set('Vary', 'Origin');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Firebase-AppCheck');
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    // ── App Check (mandatory unless explicitly disabled for rollout) ──────────
    const appCheckToken = req.headers['x-firebase-appcheck'];
    if (APP_CHECK_ENFORCE && !appCheckToken) {
      res.status(401).json({ error: 'App Check required' });
      return;
    }
    if (appCheckToken) {
      try {
        await admin.appCheck().verifyToken(appCheckToken);
      } catch (e) {
        functions.logger.warn('App Check token verification failed', { error: e.message });
        res.status(401).json({ error: 'Invalid App Check token' });
        return;
      }
    }

    // ── Auth: verify Firebase ID token ────────────────────────────────────────
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization header' });
      return;
    }
    let uid;
    try {
      uid = (await admin.auth().verifyIdToken(idToken)).uid;
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired ID token' });
      return;
    }

    // ── Input validation & caps ───────────────────────────────────────────────
    const body = req.body || {};
    const messages = body.messages;
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'messages array is required' });
      return;
    }
    if (messages.length > MAX_MESSAGES) {
      res.status(413).json({ error: 'too_many_messages' });
      return;
    }
    if (JSON.stringify(messages).length > MAX_TOTAL_CHARS) {
      res.status(413).json({ error: 'payload_too_large' });
      return;
    }
    const type = ALLOWED_TYPES.has(body.type) ? body.type : 'other';

    // Admin-editable config (app_config/global) decides model / tokens / quota
    // SERVER-SIDE — the client's requested model is ignored for cost safety, and
    // admins can retune all of this live without redeploying.
    const cfg = await getAppConfig();
    const aiCfg = (cfg && cfg.ai) || {};
    const modelByType = aiCfg.model_by_type || {};
    let model;
    if (type === 'food_photo') {
      model = aiCfg.vision_model ||
        process.env.OPENROUTER_VISION_MODEL ||
        'meta-llama/llama-3.2-11b-vision-instruct:free';
    } else {
      model = modelByType[type] || aiCfg.text_model || DEFAULT_MODEL;
    }
    const maxTokensByType = aiCfg.max_tokens_by_type || {};
    const maxOut = Math.min(
      Number(maxTokensByType[type] || aiCfg.max_tokens || MAX_OUTPUT_TOKENS) ||
      MAX_OUTPUT_TOKENS,
      32000,
    );
    const temperature = Math.min(
      Math.max(Number(body.temperature) || Number(aiCfg.temperature) || 0.7, 0),
      1,
    );
    const quotaLimits = {
      free: Number(aiCfg.free_daily_limit) || undefined,
      premium: Number(aiCfg.premium_daily_limit) || undefined,
    };

    // ── Premium (server-authoritative) + rate limit + quota ──────────────────
    const premium = await isPremium(uid);
    let gate;
    try {
      gate = await enforceRateLimitAndQuota(uid, premium, quotaLimits);
    } catch (e) {
      // FAIL CLOSED — never grant free AI because the quota store hiccuped.
      functions.logger.error('quota tx failed — failing closed', { uid, error: e.message });
      res.status(503).json({ error: 'quota_unavailable' });
      return;
    }
    if (!gate.ok) {
      if (gate.reason === 'rate_limited') {
        res.status(429).json({ error: 'rate_limited' });
        return;
      }
      res.status(402).json({ error: 'quota_exceeded' });
      return;
    }

    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      functions.logger.error('OPENROUTER_API_KEY secret not set');
      await rollbackConsume(uid, gate.consumed);
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
          model,
          messages,
          temperature,
          max_tokens: maxOut,
        }),
      });

      if (!upstream.ok) {
        // Log the upstream status + body SERVER-SIDE for diagnosis (never sent
        // to the client). Truncated to keep logs bounded.
        let errBody = '';
        try {
          errBody = (await upstream.text()).slice(0, 800);
        } catch (_) { }
        functions.logger.warn('OpenRouter error', {
          uid,
          status: upstream.status,
          model,
          body: errBody,
        });
        await rollbackConsume(uid, gate.consumed);
        res.status(502).json({ error: 'ai_upstream_error' });
        return;
      }

      const data = await upstream.json();
      functions.logger.info('aiProxy: success', { uid, consumed: gate.consumed, model, type });
      // Record real token usage + cost (best-effort, off the response path).
      recordUsage(uid, {
        type, model, usage: data && data.usage, premium, consumed: gate.consumed,
      }).catch(() => { });
      res.status(200).json(data);
    } catch (e) {
      functions.logger.error('aiProxy fetch error', { uid, error: e.message });
      await rollbackConsume(uid, gate.consumed);
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
  mealReminder: 'reminders',
  streakAtRisk: 'reminders',
  weeklyPlanReady: 'reminders',
  gymWarEnded: 'system',
};

/**
 * Returns the push title + body for a given notification type, localized to
 * the recipient's `locale` ('tr' or default 'en'). Wording mirrors the
 * in-app copy in assets/localization/{en,tr}.json under `notifications.feed.*`
 * (NotificationPresenter) so push and in-app text never diverge.
 */
function getPushText(type, actorName, metadata, locale, customTitle, customBody) {
  const tr = locale === 'tr';
  const name = actorName || (tr ? 'Biri' : 'Someone');
  const emoji = (metadata && metadata.emoji) || '❤️';
  const hasCommentId = !!(metadata && metadata.commentId);
  const days = (metadata && (metadata.streakDays || metadata.rewardDays)) || '';
  const system = tr
    ? { title: 'Bildirim', body: 'Yeni bir güncellemen var.' }
    : { title: 'Notification', body: 'You have a new update.' };

  switch (type) {
    case 'likePost':
    case 'like':
      return tr
        ? { title: `${name} gönderini beğendi`, body: '' }
        : { title: `${name} liked your post`, body: '' };
    case 'likeComment':
      return tr
        ? { title: `${name} yorumunu beğendi`, body: '' }
        : { title: `${name} liked your comment`, body: '' };
    case 'reaction':
      if (hasCommentId) {
        return tr
          ? { title: `${name} yorumuna ${emoji} tepkisi verdi`, body: '' }
          : { title: `${name} reacted ${emoji} to your comment`, body: '' };
      }
      return tr
        ? { title: `${name} gönderine ${emoji} tepkisi verdi`, body: '' }
        : { title: `${name} reacted ${emoji} to your post`, body: '' };
    case 'comment':
      return tr
        ? { title: `${name} gönderine yorum yaptı`, body: '' }
        : { title: `${name} commented on your post`, body: '' };
    case 'friendRequest':
      return tr
        ? { title: `${name} sana arkadaşlık isteği gönderdi`, body: '' }
        : { title: `${name} sent you a friend request`, body: '' };
    case 'friendAccepted':
      return tr
        ? { title: `${name} arkadaşlık isteğini kabul etti`, body: '' }
        : { title: `${name} accepted your friend request`, body: '' };
    case 'follow':
      return tr
        ? { title: `${name} seni takip etmeye başladı`, body: '' }
        : { title: `${name} started following you`, body: '' };
    case 'streakMilestone':
      return tr
        ? { title: `${days} günlük seri! 🔥`, body: `${days} gündür üst üste giriş yaptın. Böyle devam et!` }
        : { title: `${days}-day streak! 🔥`, body: `You've logged in ${days} days in a row. Keep it up!` };
    case 'mealPlan':
      return tr
        ? { title: 'Yemek planın hazır', body: 'Hedeflerine uygun yeni bir haftalık beslenme planı hazırlandı.' }
        : { title: 'Your meal plan is ready', body: 'A fresh weekly nutrition plan has been prepared for your goals.' };
    case 'referral':
      return tr
        ? { title: 'Davet ödülü 🎉', body: `Biri kodunu kullandı — ikiniz de ${days} günlük Premium kazandınız!` }
        : { title: 'Referral reward 🎉', body: `Someone used your code — you both earned ${days} days of Premium!` };
    case 'coachApplicationApproved':
      return tr
        ? { title: 'Antrenör başvurun onaylandı! 🎉', body: '' }
        : { title: 'Your coach application was approved! 🎉', body: '' };
    case 'coachApplicationRejected':
      return tr
        ? { title: 'Antrenör başvurun incelendi', body: '' }
        : { title: 'Your coach application was reviewed', body: '' };
    case 'gymApplicationApproved':
      return tr
        ? { title: 'Salon başvurun onaylandı! 🎉', body: '' }
        : { title: 'Your gym application was approved! 🎉', body: '' };
    case 'gymApplicationRejected':
      return tr
        ? { title: 'Salon başvurun incelendi', body: '' }
        : { title: 'Your gym application was reviewed', body: '' };
    case 'streakFreezeUsed':
      return tr
        ? { title: 'Seriniz bir dondurmayla kurtarıldı ❄️', body: `Bir dondurma jetonu ${days} günlük serini korudu.` }
        : { title: 'Your streak was saved by a freeze ❄️', body: `A freeze token protected your ${days}-day streak.` };
    case 'achievementEarned': {
      const achName = (metadata && metadata.achievementName) || '';
      const desc = (metadata && metadata.achievementDesc) || '';
      return tr
        ? { title: `Yeni başarım: ${achName} 🏅`, body: desc }
        : { title: `New achievement: ${achName} 🏅`, body: desc };
    }
    case 'mealReminder':
      return tr
        ? { title: '🍽 Öğününü kaydetme zamanı!', body: 'Beslenme hedeflerinde kalmak için yediklerini takip et' }
        : { title: '🍽 Time to log your meal!', body: "Don't forget to track what you ate" };
    case 'streakAtRisk':
      return tr
        ? { title: '🔥 Seriniz tehlikede!', body: 'Serinizi korumak için bugün bir öğün kaydedin' }
        : { title: '🔥 Streak at risk!', body: 'Log a meal today to keep your streak alive' };
    case 'weeklyPlanReady':
      return tr
        ? { title: '📅 Yeni hafta, yeni plan!', body: 'Haftalık yemek planın hazır — hadi başlayalım' }
        : { title: '📅 New week, new plan!', body: "Your weekly meal plan is ready — let's make it count" };
    case 'gymWarEnded': {
      const myScore = (metadata && metadata.myScore) || 0;
      const otherScore = (metadata && metadata.otherScore) || 0;
      const won = !!(metadata && metadata.won);
      const wonTitle = tr ? '🏆 Salon savaşını kazandın!' : '🏆 You won the gym war!';
      const lostTitle = tr ? 'Salon savaşı bitti' : 'Gym war ended';
      const body = tr
        ? `${myScore} - ${otherScore} check-in ile bitti.`
        : `Ended ${myScore}-${otherScore} in check-ins.`;
      return { title: won ? wonTitle : lostTitle, body };
    }
    case 'system':
      // Admin free-text message (sendAdminNotification's 'system' branch)
      // carries its own title/body — always shown verbatim, no locale switch,
      // since the admin authored it in whatever language they typed.
      if (customTitle && customBody) return { title: customTitle, body: customBody };
      return system;
    default:
      return system;
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
      // Lives on private/account, not the main doc (audit N1).
      await db.collection('users').doc(uid).collection('private').doc('account').update({
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

    // executeBroadcast() writes this same doc shape for the in-app feed but
    // already sends its own per-locale push directly — fall through here
    // would double-send with generic (non-localized) text.
    if (type === 'broadcast') return;

    const actorName = doc.actorName || '';
    const relatedId = doc.relatedId || '';
    const actorUid = doc.actorUid || '';
    const metadata = doc.metadata || {};

    // Fetch recipient — need their locale and mute prefs; FCM token lives
    // separately on private/account (audit N1).
    const userSnap = await admin.firestore().collection('users').doc(uid).get();
    if (!userSnap.exists) return;
    const userData = userSnap.data();

    const token = await getFcmToken(admin.firestore(), uid);
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

    const locale = userData.locale || 'en';
    const { title, body } = getPushText(type, actorName, metadata, locale, doc.title, doc.body);
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
      const token = await getFcmToken(admin.firestore(), uid);
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

  // Faz 0 §0.5 fix: the user doc has no top-level `role` field — roles live
  // in the `user_roles` array (values 'coach'/'gym_owner', snake_case; see
  // UserRoleX.firestoreValue). This previously matched zero documents, so
  // every 'coaches'/'gymOwners' broadcast silently reached nobody.
  let query = db.collection('users').limit(MAX);
  if (audience === 'coaches') {
    query = query.where('user_roles', 'array-contains', 'coach');
  } else if (audience === 'gymOwners') {
    query = query.where('user_roles', 'array-contains', 'gym_owner');
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
      // Fetch user for locale; FCM token lives separately on private/account
      // (audit N1) — read in parallel, not sequentially, to avoid doubling
      // this fan-out's latency per recipient.
      const [userSnap, token] = await Promise.all([
        db.collection('users').doc(uid).get(),
        getFcmToken(db, uid),
      ]);
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
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // FCM push (best-effort; don't block batch on this)
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

// ─────────────────────────────────────────────────────────────────────────────
// Re-engagement Cron Producers (Phase 15)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Returns today's date as a YYYY-MM-DD string in UTC.
 * Matches the format written by FoodLogService._todayKey() on the client.
 */
function todayKey() {
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Daily cron: 17:00 UTC (≈20:00 Turkey / 19:00 CET).
 *
 * Finds users whose streak > 0 but who haven't logged any food today, and
 * sends them a "streak at risk" push notification. Respects the `reminders`
 * mute preference.
 *
 * Capped at 500 users to stay within Cloud Function timeout for MVP.
 */
exports.streakAtRiskNotifier = functions
  .pubsub
  .schedule('0 17 * * *')
  .timeZone('UTC')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const today = todayKey();

    const usersSnap = await db.collection('users')
      .where('streak', '>', 0)
      .limit(500)
      .get();

    if (usersSnap.empty) {
      functions.logger.info('streakAtRiskNotifier: no users with active streak');
      return;
    }

    let sentCount = 0;

    await Promise.all(usersSnap.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      // FCM token lives on private/account, not this already-fetched query
      // result (audit N1).
      const token = await getFcmToken(db, uid);
      if (!token) return;

      // Respect reminders mute preference
      const mutedMap = userData.notification_muted || {};
      if (mutedMap['reminders'] === true) return;

      // Check if user already logged food today
      const logsSnap = await db.collection('users').doc(uid)
        .collection('food_logs')
        .where('date', '==', today)
        .limit(1)
        .get();

      if (!logsSnap.empty) return; // Already logged today — streak is safe

      const { title, body } = getPushText('streakAtRisk', '', {}, userData.locale || 'en');
      const sent = await sendFcm(uid, token, title, body, { type: 'streakAtRisk' });
      if (sent) sentCount++;
    }));

    functions.logger.info('streakAtRiskNotifier: done', {
      processed: usersSnap.size, sent: sentCount,
    });
  });

/**
 * Weekly cron: every Monday at 07:00 UTC.
 *
 * Notifies all users (up to 500 for MVP) that a new week has started and their
 * weekly meal plan is ready to regenerate. Respects the `reminders` mute
 * preference.
 */
exports.weeklyPlanReadyNotifier = functions
  .pubsub
  .schedule('0 7 * * 1')
  .timeZone('UTC')
  .onRun(async (_context) => {
    const db = admin.firestore();

    const usersSnap = await db.collection('users')
      .where('onboarding_completed', '==', true)
      .limit(500)
      .get();

    if (usersSnap.empty) {
      functions.logger.info('weeklyPlanReadyNotifier: no users');
      return;
    }

    let sentCount = 0;

    await Promise.all(usersSnap.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      // FCM token lives on private/account, not this already-fetched query
      // result (audit N1).
      const token = await getFcmToken(db, uid);
      if (!token) return;

      // Respect reminders mute preference
      const mutedMap = userData.notification_muted || {};
      if (mutedMap['reminders'] === true) return;

      const { title, body } = getPushText('weeklyPlanReady', '', {}, userData.locale || 'en');
      const sent = await sendFcm(uid, token, title, body, { type: 'weeklyPlanReady' });
      if (sent) sentCount++;
    }));

    functions.logger.info('weeklyPlanReadyNotifier: done', {
      processed: usersSnap.size, sent: sentCount,
    });
  });

/**
 * Hourly cron: closes any gym war whose end_date has passed but is still
 * 'active' (Faz 0 §0.6 / S18 — GymLeaderboardService.endWar() existed with
 * zero callers, so a war's status never actually changed once its time was
 * up, and the audit-flagged "coming soon" framing around gym wars — which
 * this repo could not locate live in the current code — is moot once wars
 * visibly conclude on their own). Computes each side's final check-in count
 * within the war window via a real `.count()` aggregation (matches
 * GymLeaderboardService.getWarScore's own logic), records the result, and
 * notifies both gym owners.
 */
exports.endExpiredGymWars = functions
  .pubsub
  .schedule('every 60 minutes')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection('gym_wars')
      .where('status', '==', 'active')
      .where('end_date', '<=', now)
      .limit(100)
      .get();

    if (snap.empty) {
      functions.logger.info('endExpiredGymWars: no expired wars');
      return;
    }

    let ended = 0;
    for (const warDoc of snap.docs) {
      const war = warDoc.data();
      try {
        const [scoreASnap, scoreBSnap] = await Promise.all([
          db.collection('gyms').doc(war.gym_a_id).collection('checkins')
            .where('timestamp', '>=', war.start_date)
            .where('timestamp', '<=', war.end_date)
            .count().get(),
          db.collection('gyms').doc(war.gym_b_id).collection('checkins')
            .where('timestamp', '>=', war.start_date)
            .where('timestamp', '<=', war.end_date)
            .count().get(),
        ]);
        const scoreA = scoreASnap.data().count || 0;
        const scoreB = scoreBSnap.data().count || 0;
        const winnerGymId = scoreA === scoreB ? null : (scoreA > scoreB ? war.gym_a_id : war.gym_b_id);

        await warDoc.ref.update({
          status: 'ended',
          final_score_a: scoreA,
          final_score_b: scoreB,
          winner_gym_id: winnerGymId,
          ended_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        const [gymASnap, gymBSnap] = await Promise.all([
          db.collection('gyms').doc(war.gym_a_id).get(),
          db.collection('gyms').doc(war.gym_b_id).get(),
        ]);
        const sides = [
          { ownerUid: gymASnap.exists ? gymASnap.data().owner_uid : null, myScore: scoreA, otherScore: scoreB },
          { ownerUid: gymBSnap.exists ? gymBSnap.data().owner_uid : null, myScore: scoreB, otherScore: scoreA },
        ];
        for (const side of sides) {
          if (!side.ownerUid) continue;
          await writeNotification(db, {
            targetUid: side.ownerUid,
            type: 'gymWarEnded',
            relatedId: warDoc.id,
            metadata: {
              myScore: side.myScore,
              otherScore: side.otherScore,
              won: side.myScore > side.otherScore,
            },
          });
        }

        ended++;
      } catch (e) {
        functions.logger.error('endExpiredGymWars: failed for war', { warId: warDoc.id, error: e.message });
      }
    }

    functions.logger.info('endExpiredGymWars: done', { processed: snap.size, ended });
  });

// ─────────────────────────────────────────────────────────────────────────────
// Purchase validation + server-authoritative economy (modular)
// ─────────────────────────────────────────────────────────────────────────────

const purchases = require('./purchases');
exports.validatePurchase = purchases.validatePurchase;
exports.appStoreNotifications = purchases.appStoreNotifications;
exports.playRtdn = purchases.playRtdn;

const economy = require('./economy');
exports.applyReferral = economy.applyReferral;

const account = require('./account');
exports.deleteUserAccount = account.deleteUserAccount;

const media = require('./media');
exports.scanImage = media.scanImage;

const adminRoles = require('./admin');
exports.syncAdminClaim = adminRoles.syncAdminClaim;

const progress = require('./progress');
exports.syncProgress = progress.syncProgress;
exports.backfillProgress = progress.backfillProgress;

const notifications = require('./notifications');
exports.createNotification = notifications.createNotification;
exports.retractNotification = notifications.retractNotification;
exports.sendAdminNotification = notifications.sendAdminNotification;

const social = require('./social');
exports.followUser = social.followUser;
exports.unfollowUser = social.unfollowUser;
exports.sendFriendRequest = social.sendFriendRequest;
exports.respondToFriendRequest = social.respondToFriendRequest;
exports.cancelFriendRequest = social.cancelFriendRequest;
exports.searchUsersByEmail = social.searchUsersByEmail;

const gym = require('./gym');
exports.validateGymCheckin = gym.validateGymCheckin;
