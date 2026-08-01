# API.md — Backend Contracts

> Every boundary the client crosses: Cloud Functions, triggers, scheduled jobs, and external
> services. **This document owns the contract**; implementation detail lives in
> [`SERVICES.md`](SERVICES.md), and the security posture in [`SECURITY.md`](SECURITY.md).
>
> **Owns:** `functions/**` public surface. Change a signature here and in the calling Dart service in
> the same task.

---

## 1. Surface overview

**14 deployed functions, 8 written and pending deploy** (`BLK-03`/`SEC-06` — notifications.js +
social.js). Project `cookrange-app`, region `us-central1` (Firestore is in `europe-west10` — see §7).

| Function | Kind | Auth | File |
|---|---|---|---|
| `aiProxy` | HTTPS `onRequest` | ID token + App Check, **in-code** | `index.js` |
| `validatePurchase` | Callable | ID token | `purchases.js` |
| `applyReferral` | Callable | ID token | `economy.js` |
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
| `createNotification` | Callable · pending deploy | ID token | `notifications.js` |
| `retractNotification` | Callable · pending deploy | ID token | `notifications.js` |
| `sendAdminNotification` | Callable · pending deploy | ID token + `admin` claim | `notifications.js` |
| `followUser` | Callable · pending deploy | ID token | `social.js` |
| `unfollowUser` | Callable · pending deploy | ID token | `social.js` |
| `sendFriendRequest` | Callable · pending deploy | ID token | `social.js` |
| `respondToFriendRequest` | Callable · pending deploy | ID token | `social.js` |
| `cancelFriendRequest` | Callable · pending deploy | ID token | `social.js` |

`entitlements.js` exposes **internal** server-only helpers (`grantPremium`, `revokePremium`,
`grantBonusCredits`, `claimPurchaseToken`) — module functions, not callables. They are the **only**
writers of `entitlements/{uid}` and `ai_credits/{uid}`. Nothing client-facing may bypass them.

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
{ "code": "ABC123" }  →  { "ok": true, "rewardDays": 7 }
```
Server-validates: no self-referral, one per account, `max_uses` not exceeded, code exists. Grants the
7-day trial to **both** parties and writes the commission ledger entry. Replaces the old client-side
batch write, which was forgeable.

### `deleteUserAccount`
```jsonc
{}  →  { "ok": true, "deleted": { "docs": n, "storageObjects": n } }
```
Requires a recent re-authentication. Recursively erases the `users/{uid}` subtree, server-side docs,
authored content, all Storage prefixes, and the Auth user. See [`AUTHENTICATION.md`](AUTHENTICATION.md) §9.

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
| `onChatMessageCreated` | `chats/{id}/messages/{id}` | Push to the other participants |
| `onBroadcastCreated` | new broadcast doc | Dispatch to the audience (all / coaches / gymOwners / single uid) |
| `drainScheduledBroadcasts` | schedule | Send broadcasts whose time has arrived |
| `streakAtRiskNotifier` | daily 17:00 UTC | Nudge users with no `food_logs.date == today`. Respects `notification_muted.reminders`; capped at 500 users |
| `weeklyPlanReadyNotifier` | Mon 07:00 UTC | "New week, new plan" nudge. Same mute + cap |
| `scanImage` | Storage `onObjectFinalized` | Cloud Vision SafeSearch; deletes unsafe uploads |

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
