# API.md — Backend Contracts

> Every boundary the client crosses: Cloud Functions, triggers, scheduled jobs, and external
> services. **This document owns the contract**; implementation detail lives in
> [`SERVICES.md`](SERVICES.md), and the security posture in [`SECURITY.md`](SECURITY.md).
>
> **Owns:** `functions/**` public surface. Change a signature here and in the calling Dart service in
> the same task.

---

## 1. Surface overview

**22 deployed functions** (`BLK-03`/`SEC-06`'s 8 new callables in `notifications.js`/`social.js`
deployed 2026-08-01, confirmed via `firebase functions:list`). Project `cookrange-app`, region
`us-central1` (Firestore is in `europe-west10` — see §7).

| Function | Kind | Auth | File |
|---|---|---|---|
| `aiProxy` | HTTPS `onRequest` | ID token + App Check, **in-code** | `index.js` |
| `validatePurchase` | Callable | ID token | `purchases.js` |
| `applyReferral` | Callable | ID token | `economy.js` |
| `previewReferralCode` | Callable | **none** (pre-auth) + App Check | `economy.js` |
| `deleteUserAccount` | Callable | ID token + reauth | `account.js` |
| `appStoreNotifications` | HTTPS webhook | Apple JWS signature | `purchases.js` |
| `playRtdn` | Pub/Sub webhook | Google-signed | `purchases.js` |
| `scanImage` | Storage `onObjectFinalized` | — | `media.js` |
| `onInAppNotificationCreated` | Firestore trigger | — | `index.js` |
| `onChatMessageCreated` | Firestore trigger | — | `index.js` |
| `onBroadcastCreated` | Firestore trigger | — | `index.js` |
| `syncAdminClaim` | Firestore trigger | — (Admin SDK, not client-invocable) | `admin.js` |
| `drainScheduledBroadcasts` | Scheduled | — | `index.js` |
| `streakAtRiskNotifier` | Scheduled, daily 17:00 UTC | — | `index.js` |
| `weeklyPlanReadyNotifier` | Scheduled, Mon 07:00 UTC | — | `index.js` |
| `createNotification` | Callable | ID token | `notifications.js` |
| `retractNotification` | Callable | ID token | `notifications.js` |
| `sendAdminNotification` | Callable | ID token + `admin` claim | `notifications.js` |
| `followUser` | Callable | ID token | `social.js` |
| `unfollowUser` | Callable | ID token | `social.js` |
| `sendFriendRequest` | Callable | ID token | `social.js` |
| `respondToFriendRequest` | Callable | ID token | `social.js` |
| `cancelFriendRequest` | Callable | ID token | `social.js` |
| `redeemGroupInvite` | Callable | ID token | `groups.js` |

> This table predates `gym.js`/`presence.js` (Faz 1) and is missing those rows — not reconciled here
> (out of scope for the Faz 2 §2.3 change that added `redeemGroupInvite`; `functions/index.js`
> currently exports 31 functions total, `grep -c '^exports\.' functions/index.js`). Also now missing
> `sendPlanOffer` (`templates.js`, Faz 3 §3.2, full contract in §3 below) — same reasoning, not
> reconciled in this pass either. Also now missing `generateMemberProgressSummary` (`summaries.js`,
> Faz 4 §4.2, callable, ID token, full contract in §3 below), `onProgressSharingWrite` and
> `expireMemberProgressSummaries` (same file, trigger + scheduled — §5 below) — same reasoning. Also
> now missing `sendProgressShareInvite` and `getConsentingMemberUids` (same file, Faz 4 §4.3,
> callable, ID token, full contracts in §3 below) — same reasoning again. Also missing
> `syncProgress`/`backfillProgress` (`progress.js`, Faz 0 §0.4, extended Faz 5 §5.1 — callable, ID
> token, full contract in §3 below) — this one predates the table too (Faz 0), the gap just hadn't
> been noticed until this change substantially extended the callable's contract. Also now missing
> `revokeDevice` (`devices.js`, Chat Upgrade Faz 1 — callable, ID token, full contract in §3 below) and
> `getChatMediaUrl` (`chat_media.js`, Faz 5 — callable, ID token, full contract in §3 below); and, as
> triggers/scheduled jobs rather than callables (§5), `mirrorPresence`/`reconcileStalePresence`
> (`chat_presence.js`, Faz 2 — RTDB trigger + scheduled) and `onGroupMemberWritten`/
> `onGroupDocUpdated` (`group_system_messages.js`, Faz 5 — Firestore triggers).

`entitlements.js` exposes **internal** server-only helpers (`grantPremium`, `revokePremium`,
`grantBonusCredits`, `claimPurchaseToken`, `purchaseCorrelationKey`, `reverseCommissionsForPurchase`)
— module functions, not callables. `grantPremium`/`revokePremium`/`grantBonusCredits`/
`claimPurchaseToken` are the **only** writers of `entitlements/{uid}` and `ai_credits/{uid}`;
`reverseCommissionsForPurchase` (Faz 6 §6.6 follow-up) is the only writer of a commission-reversal
onto `users/{uid}/commissions/{id}` — see `SERVICES.md` for the full design. Nothing client-facing
may bypass any of them.

`config.js` gates behaviour on `APP_ENV` (`development` | `production`): development relaxes App
Check enforcement and store-credential requirements so Functions deploy and run without Apple/Google
setup. **Production enforces both.**

---

## 2. `aiProxy` — the AI gateway

`POST https://<region>-<project>.cloudfunctions.net/aiProxy`

The single AI path in release. Full behaviour: [`AI_SYSTEM.md`](AI_SYSTEM.md).

**Headers**
```
Authorization: Bearer <Firebase ID token>     required
X-Firebase-AppCheck: <App Check token>        required when APP_ENV=production
Content-Type: application/json
```

**Request**
```jsonc
{
  "messages": [ { "role": "system|user|assistant", "content": "…" } ],
  "type": "meal_plan|recipe|insight|weekly_recap|food_photo|chat|other",
  "max_tokens": 4096,        // advisory — server caps it
  "temperature": 0.7,        // advisory — server may override
  "model": "…"               // IGNORED. Server reads app_config/global (cost safety)
}
```

**Responses**

| Code | Meaning | Client handling |
|---|---|---|
| `200` | OpenRouter completion, passed through | Parse per the feature's contract |
| `401` | Missing/invalid ID token **or** the platform's own invoker gate (see below) | Re-auth; if HTML, it's the IAM gate |
| `403` | App Check failed | Attestation problem, not user error |
| `402` | **Quota exceeded** | `AIQuotaExceededException` → credits sheet |
| `429` | Per-uid rate limit | Retryable with backoff |
| `400` | Payload too large, bad shape, or disallowed model | Fatal — fix the caller |
| `5xx` | Upstream/OpenRouter failure | `AIRetryableException` — retry up to 3× |

The server-side pipeline behind these responses — attestation, allowlisting, quota transaction, cost
metering — is owned by [`AI_SYSTEM.md`](AI_SYSTEM.md) §2. **This section owns the wire contract only.**

> ⚠️ **Deploy requirement.** `aiProxy` is `https.onRequest`, which the platform deploys **private** —
> it returns a 401 HTML page *before your code runs* unless `allUsers` holds the invoker role. All
> real auth is in-code (the standard Firebase-callable pattern):
> ```bash
> gcloud functions add-iam-policy-binding aiProxy \
>   --region=us-central1 --member=allUsers --role=roles/cloudfunctions.invoker
> ```

---

## 3. Callables

Invoked via `FirebaseFunctions.instance.httpsCallable(...)`; the ID token is attached automatically.

### `validatePurchase` — the only path to premium
```jsonc
// request
{ "platform": "ios|android", "productId": "…", "purchaseToken": "…", "transactionId": "…" }
// response
{ "ok": true, "tier": "premium", "expiresAt": "<ISO>", "creditsGranted": 0 }
```
Verifies against the **Apple App Store Server API** / **Google Play Developer API**, dedupes the
token via `processed_purchases`, then writes `entitlements/{uid}` and `ai_credits/{uid}` through
`entitlements.js`. **Fails closed** — no store confirmation, no grant. Idempotent: replaying a token
returns the existing entitlement rather than granting twice.

Errors: `unauthenticated` · `invalid-argument` · `failed-precondition` (store rejected) ·
`already-exists` (token replay). See [`PREMIUM.md`](PREMIUM.md).

### `applyReferral`
```jsonc
// Personal / coach-vanity code (type != 'gym') — unchanged:
{ "code": "ABC123", "source": "manual_entry" }  →  { "ok": true, "type": "user", "rewardDays": 7 }

// Gym code (type == 'gym', Faz 6 §6.5) — a DIFFERENT outcome shape, no rewardDays:
{ "code": "GYMCODE1", "source": "deep_link" }  →  { "ok": true, "type": "gym", "gymName": "Kadıköy Fit" }
```
Server-validates: no self-referral, one per account, `max_uses` not exceeded, code exists.
`source` (optional, `'deep_link'|'manual_entry'|'in_app'`, defaults `'in_app'`) is a loosely-trusted
diagnostic classification, not a security input — see `ReferralApplyResult`'s doc comment for which
client call sites can state it precisely today.

For a **personal/coach-vanity** code: grants the 7-day trial to **both** parties and writes the
`referral`-type commission ledger entry. Replaces the old client-side batch write, which was forgeable.

For a **gym** code (Faz 6 §6.5/§6.6): takes a completely different branch — no trial, no commission at
redemption time. Instead writes an immutable `gym_attributions/{uid}` doc, bumps
`gyms/{gym_id}.attributed_member_count`, and notifies the gym owner (actor-free — no redeemer identity
in the notification). Real gym revenue only follows a LATER validated premium purchase by that user,
via `purchases.js`'s `validatePurchase` calling `maybeAwardGymCommission` — never client-triggered, and
not part of this callable's own response.

### `previewReferralCode` (Faz 6 §6.3/§6.4)
```jsonc
{ "code": "ABC123" }  →  { "valid": true, "type": "gym", "gymName": "Kadıköy Fit" }
// or, uniformly for both not-found AND inactive/exhausted (no enumeration signal):
{ "code": "ZZZZ99" }  →  { "valid": false }
```
Read-only — no auth required (`context.auth` is unused; App Check still enforced, same gate as
`applyReferral`). Exists because onboarding has NO Firebase Auth session yet, so `applyReferral` can't
be called pre-signup, but the onboarding referral step still needs to show "verified, {gym}" for a
code that arrived via deep link or clipboard paste. Never mutates `used_by_uids` or grants anything —
real redemption is still exclusively `applyReferral`, called post-signup from
`OnboardingCompletion.finalizeAndRoute`. `gymName` is only populated for `type=='gym'` codes (resolved
from `gyms/{gym_id}.name`); absent/null otherwise.

### `syncProgress` / `backfillProgress` (`progress.js`, Faz 0 §0.4, extended Faz 5 §5.1)
```jsonc
// request — every field optional; targetUid defaults to the caller (self)
{
  "targetUid": "u2",                 // omit to sync yourself
  "justLoggedMeal": true, "justLoggedPhoto": false, "justPosted": false, "justCookedAndLogged": false,
  "xpEvents": [                      // Faz 5 §5.1 — isSelf-gated, same as the flags above
    { "kind": "meal_logged", "refId": "foodLogDocId" },
    { "kind": "reaction_given", "postId": "p1", "commentId": null, "emoji": "🔥" }
  ]
}
// response
{
  "score": 340, "tier": "active", "granted": ["streak7"],
  "xp": 340, "level": 3, "leveledUp": true,
  "xpAwarded": [{ "kind": "meal_logged", "refId": "foodLogDocId", "awarded": 5, "capped": false }, "…"]
}
```
The single server-authoritative entry gate for achievements, reputation, AND (Faz 5 §5.1) XP — the
client only ever reports WHICH momentary event happened; every point value and daily cap is decided
server-side from a fixed table (`XP_TABLE`), never taken from the request. `xpEvents` accepts only
`meal_logged`/`recipe_cooked`/`post_created`/`comment_created`/`reaction_given` — each is
independently re-verified against its referenced Firestore doc (existence + ownership) before
anything is awarded; a failed verification is silently skipped, not an error. `streak_day` and
`achievement_earned` XP are NEVER accepted from a request — both are derived and awarded entirely
inside this callable from the target's own already-stored truth (streak count / newly-granted
achievement keys), regardless of `isSelf`. `check_in` and `template_accepted` XP never flow through
this callable at all — see `progress.js`'s header comment; they're awarded in-process by
`presence.js`/`gym.js` and `templates.js` respectively via the same underlying (non-callable)
`awardXp` primitive. A level-up fires the `levelUp` notification as a side effect (no separate
polling needed — the response's own `leveledUp`/`level` are also immediately usable for a client-side
celebration if desired). `backfillProgress` (`{}` → same response shape) takes no request fields —
one-time catch-up for users who predate this system, evaluating flags from existing data.

Errors: `unauthenticated` · `not-found` (`user doc missing`). Malformed/disallowed `xpEvents` entries
are dropped silently rather than erroring the whole call (one bad entry shouldn't block an
achievement/reputation sync that would otherwise succeed).

### `redeemGroupInvite` (`groups.js`, Faz 2 §2.3)
```jsonc
{ "code": "AB3D9XQK" }  →  { "ok": true, "groupId": "gr1", "groupName": "İstanbul Koşucuları" }
```
Validates the code against `group_invites/{code}` (fully closed to client reads — this callable is
the only way to resolve one) and, if `is_active` + the referenced group's `invite_enabled` + the
caller isn't already a member or banned, atomically creates their `community_groups/{id}/members/
{uid}` doc, increments `member_count`, and mirrors `group_memberships` onto their user doc. Mirrors
`applyReferral`'s shape (transaction returns a domain error string, thrown as `HttpsError` after).

Errors: `unauthenticated` · `invalid-argument` (code too short) · `failed-precondition` with
`code_not_found` / `code_inactive` / `group_not_found` / `invite_disabled` / `banned` /
`already_member`.

### `revokeDevice` (`devices.js`, Chat Upgrade Faz 1)
```jsonc
// sign out one device (may or may not be the caller's own)
{ "deviceId": "d1", "allOthers": false }  →  { "ok": true, "revokedCount": 1 }
// sign out every device EXCEPT the caller's own (client passes its own current deviceId to spare it)
{ "deviceId": "d1", "allOthers": true }   →  { "ok": true, "revokedCount": 3 }
```
Scoped automatically to `users/{context.auth.uid}/devices` — a caller can only ever name a device
under their own uid, so no separate ownership check exists beyond the auth check. Batch-sets
`revoked: true, revoked_at: serverTimestamp()` on the target doc(s) (client-unwritable by
`firestore.rules`), then calls `admin.auth().revokeRefreshTokens(uid)` once. **Important, honest
limitation**: that revocation is per-USER, not per-device — Firebase Auth has no API to invalidate a
single refresh token in isolation. "Sign out this device" is exactly right (the targeted device IS
the one whose token should die). "Sign out all other devices" is subtly less clean: the CALLER's own
token is also invalidated once it next needs to refresh (can happen within the hour), even though the
Firestore-flag-driven local sign-out only fires on the targeted devices. See the function's own header
comment before changing any UX copy that promises the caller's session survives indefinitely — it
doesn't. If `revokedCount` would be 0 (e.g. "all others" with no other devices registered), the
function skips both the batch commit and the token revocation entirely, so it never pointlessly signs
the caller out.

Errors: `unauthenticated` · `invalid-argument` (missing `deviceId`) · `not-found`
(`device_not_found`, single-device path only).

### `getChatMediaUrl` (`chat_media.js`, Faz 5)
```jsonc
{ "chatId": "c1", "storagePath": "chat_media/c1/u2/170...jpg" }  →  { "url": "https://...&Expires=..." }
```
The read-side of the group-chat image storage-scoping fix (`storage.rules`'
`chat_media/{chatId}/{uid}/{fileName}` is `allow read: if false` unconditionally — this callable is
the ONLY way to ever resolve one). Re-verifies the caller is a real participant of `chatId` (plain
`participants` array) or an active, non-banned member of its backing `community_groups` doc if
group-backed — the same access model `firestore.rules`' `isParticipant()`/`canAccessGroupChat()`
encode, reimplemented here against Firestore via the Admin SDK since Storage rules can't call
Firestore themselves. Also rejects a `storagePath` that doesn't start with `chat_media/{chatId}/` —
without that check, a caller who legitimately belongs to one chat could name an unrelated chat's
media path and have it resolved anyway. On success, mints a 24h V4 signed URL via
`admin.storage().bucket()`. Client-side, `ChatMediaUrlCache` caches the result until just before
expiry so a re-render doesn't re-call this on every build.

Errors: `unauthenticated` · `invalid-argument` (missing `chatId`/`storagePath`, or `storagePath` not
scoped to `chatId`) · `permission-denied` (`not_a_participant`) · `internal` (`sign_failed` — the
signed-URL mint itself failed).

### `deleteUserAccount`
```jsonc
{}  →  { "ok": true, "deleted": { "docs": n, "storageObjects": n } }
```
Requires a recent re-authentication. Recursively erases the `users/{uid}` subtree, server-side docs,
authored content, all Storage prefixes, and the Auth user. See [`AUTHENTICATION.md`](AUTHENTICATION.md) §9.

### `sendPlanOffer` (`templates.js`, Faz 3 §3.2, extended §3.5)
```jsonc
// request — toUid (single) or toUids (array, deduped, self-send dropped, max 100) both accepted
{ "templateId": "t1", "toUids": ["u2", "u3"], "message": "Bu haftaki planın!" }
// response
{ "ok": true, "sent": 2 }
```
Server-validates the caller is the template's own `author_uid` (or a site admin) — you can only send
what you authored — and that **every** recipient has a real, pre-existing relationship to the
sender: a `gym`-authored template only to that gym's own members (`gyms/{gym_id}/members/{uid}`),
a `coach`-authored one only to that coach's ACTIVE clients (`coach_profiles/{authorUid}/clients/
{uid}`, `status == 'active'`), an `admin`-authored one to any registered user. On success, batch-
writes one `users/{toUid}/plan_offers/{autoId}` per recipient — each carrying an immutable
`template_snapshot` copy taken at that instant, `status: 'pending'`, `expires_at` = now + 14 days —
and increments `meal_plan_templates/{id}.usage_count` by the recipient count in the same batch (the
only way that field ever moves — `firestore.rules`' `plan_offers.create` is `if false`, so this
callable is the sole writer).

**Faz 3 §3.5** — the same batch also creates a `plan_offer`-typed message in the recipient's private
1:1 chat with the sender (found-or-created, one query up front for all recipients — not one query
each), and, after the batch commits, a best-effort `planOfferReceived` notification per recipient.
Response shape is unchanged (`{ ok, sent }`).

Errors: `unauthenticated` · `invalid-argument` (missing `templateId`/recipients, or >100 recipients)
· `not-found` (`template_not_found`) · `permission-denied` (`not_template_author` /
`recipient_not_eligible:<uid>`).

**Still not built as a client callable** (by design, not a gap): "accept" and "decline" are plain
client `.update()` calls under the already-tested `plan_offers` rule, not a second callable — see
`onPlanOfferResponded` (Firestore trigger, `SERVICES.md`) for how the sender-facing decline
notification gets written despite that. The 14-day auto-expiry sweep is `expirePlanOffers`
(scheduled, `SERVICES.md`) — `PlanOffer.isExpired` still computes the same thing client-side for
immediacy between sweep runs, same as before.

### `generateMemberProgressSummary` (`summaries.js`, Faz 4 §4.2)
```jsonc
// request
{ "memberUid": "u2", "scopeId": "gym_g1", "locale": "tr" }  // scopeId = 'gym_{gymId}' | 'coach_{uid}'
// response
{ "ok": true, "tier": 1, "method": "ai", "narrative": "…", "fields": { "check_in_frequency_per_week": 3.5, "current_streak_weeks": 2, "last_visit_at": "…" } }
```
Closes audit C2 in full as of Faz 4 §4.4: `coach_client_detail_screen.dart`'s old client-side
`_generateAiReport()` (direct `AIService().generateJson()`, zero consent check, zero relationship
re-verification) has been DELETED, not merely superseded — the screen now calls this callable (or
reads its own cache via `getCachedSummary`) exclusively. See `SERVICES.md`'s header note and
`summaries.js`'s own file comment for the full before/after.

Server-validates, in order: (1) the caller is genuinely `gyms/{gymId}.owner_uid` (or admin) AND the
member is a real `gyms/{gymId}/members/{memberUid}` — or, for a coach scope, the caller IS the
scopeId's own coach uid (or admin) AND `coach_profiles/{coachUid}/clients/{memberUid}.status ==
'active'`; (2) `users/{memberUid}/progress_sharing/{scopeId}.level > 0` — tier 0 (or no doc at all)
is `permission-denied`/`not_shared`, a deliberately DIFFERENT signal from a successful-but-empty
response; (3) a sliding-window rate limit, ONE generation per (caller, member) pair per rolling 24h
(`rate_limit.js`, keyed by a composite `${callerUid}_${memberUid}` bucket — the module's other three
callers are plain per-uid, this is the first per-pair use). Then aggregates ONLY the tier-permitted
fields server-side (client never sees more, at any point in the response) and checks the **member's**
`aiProcessing`+`crossBorderTransfer` consent (not the caller's) before calling the LLM — missing
either falls back to a template-only narrative built from the same structured fields, no LLM call at
all. An AI call (when made) fences the member's display name through a Node port of
`PromptService.injectionGuard`/`fence`/`localeInstruction` (different runtime, same text/behavior)
and is tagged `type: 'coach_report'` for cost attribution (`ALLOWED_TYPES` in `index.js` was missing
this entry before this change). Writes `gyms/{gymId}/member_summaries/{memberUid}` (or the
coach-scope equivalent), 7-day `expires_at`, plus a `users/{memberUid}/access_log/{autoId}` entry —
both in the same batch.

Errors: `unauthenticated` · `invalid-argument` (`memberUid`/`scopeId` missing or malformed,
`cannot_summarize_self`) · `permission-denied` (`not_authorized_for_scope`, `not_shared`) ·
`resource-exhausted` (`generation_rate_limited`, or `ai_rate_limited`/`ai_quota_exceeded` if the AI
call itself is gated — the caller's OWN `ai_credits/{callerUid}` quota, never the member's) ·
`failed-precondition` (`ai_not_configured`) · `unavailable` (`ai_upstream_error`) · `internal`
(`summary_generation_failed`).

**Known gap, documented rather than silent** (see `summaries.js`'s aggregation comment): tier 2's
`plan_adherence_pct` and tier 3's `weight_trend` currently always resolve to the literal string
`'insufficient_data'` — this app has no plan-vs-actual adherence calculator or weight-HISTORY
datasource anywhere yet (only a single onboarding `weight` snapshot + `target_weight` goal, never a
logged series), so a genuine trend/adherence number cannot be honestly computed today. The
non-negotiable constraint ("raw weight history never exposed") holds trivially as a result — there
is never anything to expose. `coach_client_detail_screen.dart` (§4.3/§4.4) renders both as an
explicit "not enough data yet" state per field — never hidden, never a fabricated number.

### `sendProgressShareInvite` (`summaries.js`, Faz 4 §4.3)
```jsonc
// request
{ "memberUid": "u2", "scopeId": "gym_g1" }
// response (one of)
{ "sent": true }
{ "sent": false, "reason": "already_invited" }   // .create() found the receipt doc already present
{ "sent": false, "reason": "already_shared" }    // tier changed to >0 between page load and tap
```
The tier-0 empty state's "send an invite" button. Re-derives the SAME caller authority
`generateMemberProgressSummary` requires (real gym ownership / active coaching relationship), then
creates `gyms/{gymId}\|coach_profiles/{coachUid}/progress_share_invites/{memberUid}` with `.create()`
— fails with Firestore error code 6 (`ALREADY_EXISTS`) if the doc is already there, which this
callable treats as `{sent:false, reason:'already_invited'}` rather than an error. That `.create()`
semantics IS the one-time-ever guarantee (§4.3: "tek seferlik" — never repeated automatically,
mirroring the per-day dedup `presence_notify_log` already applies to "friend at gym," just
per-scope-EVER here instead of per-day). No AI call, no credit/quota consumption. On success, sends
a `progressShareInviteRequested` notification (`notifications.js`'s `writeNotification`) — actor is
the caller; for a gym scope, `metadata.gymName` carries the gym's business name (not the owner's
personal `displayName` — mirrors `onGymPresenceCreated`'s same preference for `friendAtGym`).

Errors: `unauthenticated` · `invalid-argument` (`memberUid`/`scopeId` missing or malformed,
`cannot_invite_self`) · `permission-denied` (`not_authorized_for_scope`) · `internal`
(`invite_failed`).

### `getConsentingMemberUids` (`summaries.js`, Faz 4 §4.3)
```jsonc
// request
{ "scopeId": "gym_g1" }
// response
{ "uids": ["u2", "u5", "u9"] }   // members/clients with progress_sharing level >= 1 for this scope
```
Closes the at-risk-list leak (audit finding: `gym_analytics_service.dart`'s 14-day-inactive list
showed every member's NAME with zero permission check) and backs the k-anonymity-gated aggregate
card — both need "which members consented," and a client can never read another user's
`progress_sharing` doc directly (owner-only rule). Verifies the caller owns the WHOLE scope (gym
`owner_uid` / the coachUid itself, or admin — a lighter check than `generateMemberProgressSummary`'s
per-member authority, correct because this never exposes anything about a member the caller
couldn't already learn one-by-one via that callable's own per-member check). Gathers candidate uids
(gym `members` subcollection / coach `clients` where `status=='active'`, capped at 500 — same cap
discipline as `gym_analytics_service.dart`'s `memberCap`), then one direct `progress_sharing/{scopeId}`
GET per candidate (not a collectionGroup query — that doc has no `scope_id` FIELD to filter by, only
the scopeId baked into its doc ID; adding one would mean touching the already-shipped, already-tested
§4.1 write shape, out of this task's scope). Returns only uids, never a tier value or field data.

Errors: `unauthenticated` · `invalid-argument` (`invalid_scope_id`) · `permission-denied`
(`not_authorized_for_scope`).

### Notifications (`notifications.js`) — `BLK-03`/`SEC-06`
All write to the canonical `notifications/{uid}/items/{docId}` path; `actorName`/`actorPhotoUrl` are
always re-fetched server-side from the caller's own `users/{uid}` doc, never trusted from the request.

```jsonc
// createNotification — social interactions + self-reported milestones
{ "targetUid": "…", "type": "likePost|likeComment|reaction|comment|system|streakMilestone",
  "relatedId": "…", "metadata": {} }  →  { "ok": true }

// retractNotification — undo a createNotification call (un-like, un-react)
{ "targetUid": "…", "relatedId": "…", "type": "…" }  →  { "ok": true, "deleted": n }
// Only deletes docs whose actorUid == caller — you can only retract your own fan-out.

// sendAdminNotification — requires the `admin` custom claim (BLK-05)
{ "targetUid": "…", "type": "coachApplicationApproved|coachApplicationRejected|"
  + "gymApplicationApproved|gymApplicationRejected", "relatedId": "…", "notes": "…" }  →  { "ok": true }
// or the free-text form:
{ "targetUid": "…", "type": "system", "title": "…", "body": "…" }  →  { "ok": true }
```
Errors: `unauthenticated` · `permission-denied` (`admin_required`, `target_must_be_self`) ·
`invalid-argument`.

### Social graph (`social.js`) — `SEC-06`
Replaces the old client-direct writes to `friends`/`friend_requests` (now `create`/`update` denied by
rule unconditionally). Each writes its edge(s) and notification atomically.

```jsonc
followUser / unfollowUser        { "targetUid": "…" }  →  { "ok": true }
sendFriendRequest                { "targetUid": "…" }  →  { "ok": true }
respondToFriendRequest           { "senderUid": "…", "accept": true|false }  →  { "ok": true, "accepted": bool }
cancelFriendRequest              { "targetUid": "…" }  →  { "ok": true }
```
`sendFriendRequest` re-verifies server-side that no friendship/request already exists (never trusts the
client's own status check). `respondToFriendRequest` requires the incoming request to actually exist.
Errors: `unauthenticated` · `invalid-argument` (`cannot_follow_self`, `cannot_friend_self`) ·
`failed-precondition` (`already_friends`, `request_exists`, `no_such_request`).

---

## 4. Webhooks (store-driven)

| Endpoint | Source | Purpose |
|---|---|---|
| `appStoreNotifications` | Apple App Store Server Notifications v2 (signed JWS) | Revoke premium on refund, chargeback, expiry, or downgrade |
| `playRtdn` | Google Play Real-Time Developer Notifications (Pub/Sub) | Same for Android |

Both verify the sender's signature before acting, and both are **pending go-live** — they need store
credentials that don't exist yet (`BLK-04`). Until they run, a refunded subscription keeps its
entitlement.

---

## 5. Triggers & scheduled jobs

| Function | Fires on | Does |
|---|---|---|
| `onInAppNotificationCreated` | new doc at `notifications/{uid}/items/{docId}` | FCM fan-out, localized (recipient's `locale`), respecting per-group mute prefs |
| `onChatMessageCreated` | `chats/{id}/messages/{id}` | **Rewritten, Chat Upgrade Faz 3+4**: idempotency-guarded (`chat_fanout_events/{context.eventId}.create()`), chunked group-member paging, writes the cold `chats/{id}/state/live` preview doc, a tiered `chat_inbox` fan-out per recipient (exact `unread` increment ≤200 recipients, a lighter `unread_dirty` signal above that), a dual-write of the legacy `unreadCounts` map for one release, and a multicast push across every one of each recipient's registered devices (`users/{uid}/devices`, Faz 1) — see `SERVICES.md`'s `ChatService` entry and `DECISIONS.md` ADR-027. Pure tiering/chunking/preview-text decisions live in `chat_fanout_logic.js`, unit-tested (`functions/test/chat_fanout_logic.test.js`) since the trigger itself has no functional harness |
| `mirrorPresence` (`chat_presence.js`, Faz 2) | RTDB write to `/presence/{uid}/{deviceId}` | Aggregates all of that uid's device presence nodes (online > away > offline) and writes the result onto `users/{uid}.is_online`/`.last_active_at` — the SAME fields every existing Firestore reader already used, so no downstream Dart file needed to change. Skips the write if the aggregate is unchanged. **Not yet live** — RTDB isn't provisioned for this project yet |
| `reconcileStalePresence` (`chat_presence.js`, Faz 2) | schedule, every 1 min | Backstop for a disconnect `onDisconnect()` somehow missed — flips any device stale >90s to offline in RTDB and re-runs the Firestore mirror for affected uids, batched at 400/commit |
| `onGroupMemberWritten` (`group_system_messages.js`, Faz 5) | `community_groups/{groupId}/members/{uid}` write | Server-authored system message (`senderId: '__system__'`, unforgeable by any client) into the group's paired chat: create → `member_joined`, delete → `member_left`, `banned` false→true on update → `member_banned` |
| `onGroupDocUpdated` (`group_system_messages.js`, Faz 5) | `community_groups/{groupId}` update | Same system-message mechanism for `name` changes (`group_renamed`) and `cover_image_url` changes (`group_photo_changed`) — diffs old vs. new itself so it never fires on an unrelated field write (e.g. the 15-minute `activity_score` bump) |
| `onBroadcastCreated` | new broadcast doc | Dispatch to the audience (all / coaches / gymOwners / single uid) |
| `drainScheduledBroadcasts` | schedule | Send broadcasts whose time has arrived |
| `streakAtRiskNotifier` | daily 17:00 UTC | Nudge users with no `food_logs.date == today`. Respects `notification_muted.reminders`; capped at 500 users |
| `weeklyPlanReadyNotifier` | Mon 07:00 UTC | "New week, new plan" nudge. Same mute + cap |
| `scanImage` | Storage `onObjectFinalized` | Cloud Vision SafeSearch; deletes unsafe uploads |
| `onProgressSharingWrite` (Faz 4 §4.2) | any write to `users/{uid}/progress_sharing/{scopeId}` | Deletes that scope's cached `member_summaries` doc immediately — ANY tier change (not just a full revoke to 0), since a stale summary generated under a higher tier would otherwise over-expose relative to the new one |
| `expireMemberProgressSummaries` (Faz 4 §4.2) | every 60 min | Deletes any `member_summaries` doc (collection-group — covers both `gyms/*` and `coach_profiles/*` scopes in one query) past its 7-day `expires_at` |
| `onPlanOfferResponded` (`templates.js`, Faz 3 §3.5, extended Faz 5 §5.1) | `users/{uid}/plan_offers/{id}` update, `pending` → `accepted`\|`declined` | On `accepted`: awards `template_accepted` XP to the member (`awardXp`, in-process — the state transition itself, already gated by `firestore.rules` to the recipient and to exactly once, IS the server-side proof). On `declined`: fires the sender-facing `planOfferDeclined` notification (unchanged from Faz 3 §3.5) |

`onInAppNotificationCreated` is now the single fan-out point for every notification writer
(`notifications.js`, `social.js`, `economy.js`'s `applyReferral`, `index.js`'s broadcast path) — all of
them write the canonical path, all via Admin SDK (`BLK-03`, fixed; previously this trigger listened on
a path nothing wrote, so social/admin push was silently dead — chat worked because it used a separate
trigger). It skips `type: 'broadcast'` docs to avoid double-sending, since `executeBroadcast` already
sends its own per-locale push directly.
> ⚠️ `scanImage` watches the wrong prefix for gym logos (`BLK-07`), and needs the Vision API enabled.

---

## 6. External services

| Service | Used by | Auth | Notes |
|---|---|---|---|
| **OpenRouter** | `aiProxy` only | Server-held key | Paid `gpt-4o-mini` default — **account must carry credit**. Cross-border transfer → disclose as a sub-processor |
| **Apple App Store Server API** | `validatePurchase`, `appStoreNotifications` | `.p8` key + Key/Issuer ID | Not provisioned |
| **Google Play Developer API** | `validatePurchase`, `playRtdn` | Service account, `androidpublisher` scope | Not provisioned |
| **Open Food Facts** | `BarcodeLookupService` (client) | None (public) | Barcode → product nutrition. Must degrade to manual entry |
| **Nominatim / OSM** | Gym map, reverse geocode | None (public) | Returns its own `display_name` key — unrelated to our field convention |
| **Cloud Vision** | `scanImage` | ADC | SafeSearch; best-effort until the API is enabled |
| **FCM** | notification functions | ADC | Push delivery; iOS needs an APNs key in Firebase |

---

## 7. Conventions & gotchas

**Contract rules**
- The client is hostile input. Never trust a client-supplied model, price, amount, uid, or count.
- **Idempotency is mandatory** for anything granting value — a retry must not double-grant.
- **Fail closed.** On any error in a value-granting path, deny.
- Errors return a safe message; stack traces stay in logs.
- No versioning exists on any contract yet (`BE-07`) — a breaking change breaks old installs.

**Operational**
- ⚠️ **Cross-region deploys look like failures.** Functions run in `us-central1` while Firestore is
  in `europe-west10`, so the CLI often prints `failed to update` while the deploy lands
  asynchronously. **Verify in the console; don't trust the CLI exit code.**
- ⚠️ Back-to-back deploys return `operation already in progress` (code 9) — wait between them.
- Functions are **gen1** on Node 22; the gen2 migration and region collocation are scheduled as one
  atomic change (`GO_LIVE.md` Phase 5T). Doing it piecemeal produces **duplicate triggers and double
  pushes**.
- Secrets live in `functions/.env`, never in `app_config/global` (public-read).
