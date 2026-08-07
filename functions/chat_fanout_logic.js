'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 3+4 — pure decision logic for the chat fan-out rewrite
// (`onChatMessageCreated`, functions/index.js). Extracted so the actual
// DECISIONS (tiering threshold, chunk sizes, staleness bail, preview text)
// are unit-testable even though the Firestore/FCM-touching trigger itself
// has no functional test harness in this repo (CLAUDE.md §8) — mirrors
// `engagement_credit_logic.js`'s precedent for the same split.
// ─────────────────────────────────────────────────────────────────────────────

// A group above this size stops getting an exact per-recipient `unread`
// increment on every message (see `fanoutTier`'s doc comment) — matches
// WhatsApp's own ~1024-member group cap order of magnitude; configurable via
// `app_config/server.chat.max_group_members` at the call site, this is just
// the tiering threshold, not a hard cap.
const PER_USER_TIER_MAX_RECIPIENTS = 200;

// A retried/duplicate-delivered event older than this is dropped rather than
// processed — protects against a poison event retrying for the platform's
// full 7-day window once `failurePolicy` is ever enabled.
const STALE_EVENT_MAX_AGE_MS = 10 * 60 * 1000; // 10 minutes

const MEMBER_PAGE_SIZE = 300;
const MULTICAST_CHUNK_SIZE = 500; // FCM's own sendEachForMulticast cap
const PREVIEW_MAX_CHARS = 120;

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

/**
 * `'per_user'` (recipientCount <= PER_USER_TIER_MAX_RECIPIENTS): every
 * recipient's `chat_inbox` row gets an exact `unread: increment(1)` —
 * cheap and precise; this covers every DM and the overwhelming majority of
 * real groups. `'cursor'` (above the threshold): the inbox row still gets
 * touched (so the chat keeps sorting to the top of a large-group member's
 * list — see the write site's own comment for the honest simplification
 * this is, vs. the zero-per-recipient-write ideal a truly unbounded-scale
 * design would need), but `unread` is NOT incremented per message — instead
 * `unread_dirty: true` is set once, and the client resolves the real count
 * via a `count()` aggregation the next time that chat is opened/listed.
 * This trades "exact live badge count on a 500-member group" for "no
 * thousand-document unread-increment storm per message" — the write COUNT
 * doesn't drop in this simplified version, but the per-write COST does
 * (two small fields vs. a full lastMessage embed + a counter mutation).
 */
function fanoutTier(recipientCount, threshold = PER_USER_TIER_MAX_RECIPIENTS) {
  return recipientCount <= threshold ? 'per_user' : 'cursor';
}

/** Parses a Cloud Functions v1 `context.timestamp` (ISO 8601) defensively. */
function isEventStale(contextTimestampIso, nowMs, maxAgeMs = STALE_EVENT_MAX_AGE_MS) {
  const eventMs = Date.parse(contextTimestampIso);
  if (Number.isNaN(eventMs)) return false; // can't parse -> don't drop it on that basis
  return (nowMs - eventMs) > maxAgeMs;
}

/**
 * Kind-aware preview text — mirrors the client's own `chat.preview.*`
 * localization keys' English fallback (push notifications are not
 * locale-aware per-recipient today; see functions/index.js's existing
 * `getPushText`'s own precedent of a fixed-language push body elsewhere in
 * this file).
 */
function previewTextFor(msg) {
  const type = msg.type || 'text';
  if (type === 'image') return '📷 Photo';
  if (type === 'voice') return '🎤 Voice message';
  if (type === 'plan_offer') return '📋 Plan offer';
  if (type === 'system') return (msg.body || '').slice(0, PREVIEW_MAX_CHARS);
  return (msg.body || msg.text || '').slice(0, PREVIEW_MAX_CHARS);
}

/**
 * The denormalized preview object stored on `chats/{id}/state/live` and
 * every recipient's `chat_inbox/{chatId}` row — deliberately small (no
 * attachments array, unlike the legacy `lastMessage` full-message embed)
 * since this is re-delivered to every listener on every message.
 */
function buildLastMessagePreview({ senderId, senderName, msg }) {
  return {
    sender_id: senderId,
    sender_name: senderName,
    kind: msg.type || 'text',
    text: previewTextFor(msg),
  };
}

module.exports = {
  PER_USER_TIER_MAX_RECIPIENTS,
  STALE_EVENT_MAX_AGE_MS,
  MEMBER_PAGE_SIZE,
  MULTICAST_CHUNK_SIZE,
  PREVIEW_MAX_CHARS,
  chunk,
  fanoutTier,
  isEventStale,
  previewTextFor,
  buildLastMessagePreview,
};
