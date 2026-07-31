# SECURITY.md — Threat Model & Security Architecture

> The security **design** and its **current gaps**. Legal/privacy obligations live in
> [`COMPLIANCE.md`](COMPLIANCE.md); collection-by-collection rules live in [`DATABASE.md`](DATABASE.md).
>
> ⚠️ **Design ≠ deployed.** The model below is coherent and largely code-complete. Almost none of it
> is *active*: all 18 gates `S0`–`S17` are open and App Check is unenforced. Status:
> [`../PROJECT_STATE.md`](../PROJECT_STATE.md).

---

## 1. The core principle

**The client renders state. It is never the authority for anything of value or safety.** (ADR-008)

Premium, AI credits, the referral/commission economy, purchase validation, roles, ban state, and
account erasure are **server-only** — Cloud Functions with Admin SDK writes, behind Firestore rules
that make those fields client-unwritable.

This principle exists because an audit found the opposite: any user could self-grant premium and
admin, mint AI credits, self-refer, forge commissions at arbitrary amounts, and self-unban — all by
writing their own user document.

---

## 2. Threat model

### Assets, ranked by what losing them costs

| Asset | Threat | Consequence |
|---|---|---|
| **Health PII** (body metrics, allergies, dietary restrictions) | Unauthorized read | Special-category breach — reportable under KVKK Art. 12 / GDPR Art. 33 |
| **OpenRouter API key** | Extraction from the binary | Denial-of-wallet; unbounded third-party spend |
| **Entitlements & credits** | Client-side forgery | Zero revenue; the product is free for anyone who reads the rules |
| **Admin capability** | Privilege escalation | Full moderation bypass, user data access, broadcast abuse |
| **Firebase Admin SA key** | Leaked credential | **Total** backend compromise — bypasses all rules and Auth |
| **User-generated content** | Spam, abuse, CSAM | Store removal, legal exposure, user harm |
| **Referral / commission economy** | Fabricated ledger entries | Direct financial fraud once payouts exist |

### Adversaries

1. **The curious user** — reads the rules, tries to write `subscription_tier: premium`.
   *Mitigation:* field-locked user doc, server-only entitlements.
2. **The scripted client** — bypasses the app, calls Firestore and `aiProxy` directly with a valid
   token. *Mitigation:* App Check (**currently unenforced — `BLK-14`**), rate limits, quota.
3. **The abusive user** — spam, harassment, illegal imagery.
   *Mitigation:* keyword pre-screen, reports queue, Vision SafeSearch, content caps.
   *Gap:* no per-uid UGC rate limiter; the queue is unreachable (`BLK-05`).
4. **The prompt attacker** — injects instructions through profile text or food descriptions to
   redirect the model. *Mitigation:* fencing + data-treatment guard in `PromptService`.
5. **The opportunist** — finds the leaked SA key in a repo or on a machine.
   *Mitigation:* **none until `S0` is done.** This is the highest-severity open item.

### Explicitly out of scope
Physical device compromise · a malicious Firebase project owner · nation-state adversaries ·
a compromised OpenRouter.

---

## 3. Authentication & session security

Flows are documented in [`AUTHENTICATION.md`](AUTHENTICATION.md); this is the security posture.

| Control | State |
|---|---|
| Password policy, live validation | ✅ |
| Email verification as a hard route gate | ✅ `RouteGuard` §C |
| Apple + Google OAuth (Apple mandatory where Google is offered) | ✅ |
| Concurrent-login / session monitoring | ✅ |
| Real-time ban check on every route | ✅ but reads a doc nothing creates (`BLK-05`) |
| `failed_login_attempts` locked to server-only | ✅ (was unauthenticated-writable) |
| **Login throttling / lockout** | ❌ `AUTH-04` |
| **MFA** | ❌ `AUTH-05` |
| **Enumeration-safe error messages** | ❌ distinct errors leak account existence |
| **Server-side email-verification enforcement in rules** | ❌ UI-gated only |

---

## 4. Authorization

Two independent layers; **both** must hold.

1. **Firestore/Storage rules** — the real boundary. Default deny; every path explicit.
2. **Cloud Function in-code checks** — ID token + App Check + role, for anything the rules can't
   express (receipt validity, referral graph, quota arithmetic).

**UI gating is not authorization.** A hidden button is a hint, not a control.

### The role model
`UserRole { consumer, gymOwner, coach, admin }`, multi-valued on `user_roles`. Roles are added by
admin review, not self-assignment.

> ⚠️ `user_roles` is deliberately **not** field-locked, because true admin power is gated separately
> by `admin/status/{uid}`. That indirection only works if the admin doc exists — and **nothing
> currently creates `admin_roles/{uid}`**, which makes the entire admin surface unreachable
> (`BLK-05`). Fixing this must not become "just trust `user_roles`."

### Known authorization holes
- `BLK-08` — any user can mutate any post's non-content fields (like counts, announcement flag, group id)
- `BLK-09` — `coach_uid == 'demo'` lets any user publish into the public marketplace
- `BLK-10` — the user doc is world-readable and carries `email`, `last_login_ip`, device fingerprints
- 7 path/rule mismatches and 8 open-write holes remain (`TODO.md` §7.1–7.2)

---

## 5. API & abuse resistance

### `aiProxy` — the most exposed surface

Public HTTPS (`allUsers` invoker required), so **all** authentication is in-code:

Firebase ID token → App Check → per-uid rate limit → model allowlist → payload/`max_tokens` caps →
**fail-closed** quota in a Firestore transaction → OpenRouter → usage metered to `ai_usage_logs`.

The proxy **ignores the client-sent model** and reads model/tokens/quota from `app_config/global`
server-side. A client cannot make the server spend more per call than an admin configured.
Details: [`AI_SYSTEM.md`](AI_SYSTEM.md).

### Rate limiting

| Surface | Control |
|---|---|
| AI requests | ✅ per-uid rate window + daily quota, both server-side |
| Auth attempts | ❌ none (`AUTH-04`) |
| UGC — posts, comments, friend requests, signals | ❌ none. Interim barriers: App Check (once enforced), content-length caps, reports queue. A real sliding-window limiter needs UGC creates routed through a callable — scope before community GA |
| Check-ins | ❌ no geofence + rate limit combination |

### Content safety
Blocked-keyword pre-screen from **public-read** `settings/content_filter` (it previously read an
admin-only doc, so the filter failed open for every normal user) · content-length caps in rules ·
`scanImage` Cloud Function running Vision SafeSearch on upload — **currently scanning the wrong
prefix** (`BLK-07`) and requiring the Vision API to be enabled.

---

## 6. Secrets management

| Secret | Correct home | Actual state |
|---|---|---|
| `OPENROUTER_API_KEY` | `functions/.env`, server-side only | 🔥 **also bundled as a Flutter asset and shipped in CI artifacts** — `BLK-15` |
| Firebase Admin SA key | Nowhere — Functions use Application Default Credentials | 🔥 **a live key was committed under `secret/`** — `S0`, rotate first |
| Apple `.p8` / Play service account | Function secrets | Not yet provisioned (`BLK-04`) |
| Signing keystore / certs | GitHub Actions secrets, never git | Not yet created (`BLK-16`) |

**Rules.** Never a secret in client code, a bundled `.env`, a doc, or a log. `app_config/global` is
**public-read** — nothing secret may ever go in it. Deleting a leaked key is not rotation; **rotate**.
A secret-scanning pre-commit + CI gate (gitleaks/trufflehog) is still to be added.

---

## 7. Data protection

| Control | State |
|---|---|
| Health PII isolated in owner-only `users/{uid}/private/nutrition` | ✅ (ADR-009) |
| Hive local boxes AES-256, key in `flutter_secure_storage` | ✅ |
| Firestore + Storage encrypted at rest, TLS in transit | ✅ platform default |
| Image uploads: resize, compress, **EXIF/GPS strip**, off-thread | ✅ |
| Analytics/Crashlytics collection **privacy-by-default OFF**, consent-gated | ✅ |
| Email removed from analytics events | ✅ |
| Recursive server-side account erasure | ✅ code-complete, `BLK-12` incomplete in coverage |
| Complete GDPR export incl. PII + Storage manifest | ✅ code-complete, `BLK-12` |
| **Android cleartext traffic disabled** | ❌ `usesCleartextTraffic` is still `true` |
| **Certificate pinning** | ❌ |
| **Root/jailbreak/emulator detection** | ❌ |
| **`FLAG_SECURE` / iOS screenshot protection** on PII screens | ❌ |
| **Release obfuscation** (`--obfuscate --split-debug-info`) | ❌ `CI-05` |
| **PII-redacting logger** | ❌ `debugPrint` may carry PII in dev |

Legal obligations, consent design, data inventory, DSAR, and the breach runbook are owned by
[`COMPLIANCE.md`](COMPLIANCE.md).

---

## 8. The security gate — `S0`–`S17`

**All 18 are open.** Full cards in [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md) Phase 5S.

### Order is load-bearing
Deploy **server write paths first** (`S2` ledger → `S3` purchase validation → `S4` economy), **then**
lock the rules (`S1`, `S5`). Locking rules before the server can write the now-forbidden fields
breaks live flows. Run the rules-emulator tests before `S1`.

### P0 — do not deploy to production without these
| Gate | What |
|---|---|
| `S0` | **Rotate the leaked Admin SA key.** First, and blocks nothing else — do it now |
| `S1` | Field-lock `users/{uid}`; move ban state to `admin/status` + custom claim + `revokeRefreshTokens` |
| `S2` | Server-authoritative AI credit + entitlement ledger *(code ✅, rules pending)* |
| `S3` | Server-side purchase validation, sandbox-proven end to end |
| `S4` | Server-authoritative economy — referrals, commissions, payouts |
| `S5` | Close open creates: notifications, friends, friend_requests |
| `S6` | Hardened proxy + App Check **enforced** + client key fallback removed + OpenRouter spend cap |
| `S7` | Server-side erasure + Storage cleanup |
| `S8` | Runtime consent enforcement + cross-border AI transfer disclosure + age gate |

### P1 — before public traffic
`S9` storage scoping + scanning · `S10` minimize the readable user doc · `S11` complete export ·
`S12` auth abuse controls · `S13` economy/social integrity · `S14` cleartext off + Hive encryption ·
`S15` obfuscated release, no debug APK · `S16` env isolation + lockfiles · `S17` analytics consent-gated

### P2 — post-launch hardening
`S18` FLAG_SECURE · `S19` root/jailbreak detection · `S20` PII-redacting logger · `S21` cert pinning ·
`S22` backups/PITR + budget alerts + IR runbook · `S23` remaining rule tightening + gen2 migration

---

## 9. Attack scenarios — walked through

**A. Self-grant premium.** User reads `firestore.rules`, writes `subscription_tier: 'premium'` to
their own doc. → *Blocked by* the `S1` field lock; premium is read from server-only
`entitlements/{uid}`, not the user doc. → *Residual:* until `S1` deploys, the mirror field on the
user doc is writable, and some UI still trusts it.

**B. Drain the AI budget.** Attacker extracts the bundled key (`BLK-15`) and calls OpenRouter
directly. → *Not blocked by anything in this app* — the proxy is irrelevant once the key is out.
→ *Fix:* `S6` (remove the client key) **and** an OpenRouter hard spend cap. Treat the current key as
already compromised.

**C. Script the API.** Attacker takes a valid ID token and calls Firestore/`aiProxy` outside the app.
→ *Blocked by* App Check attestation — **which is off** (`BLK-14`). Today only quota and rate limits
apply. → *Fix:* register Play Integrity + App Attest, set `APP_ENV=production`.

**D. Escalate to admin.** User adds `admin` to their `user_roles`. → *Blocked by* real admin power
being gated on `admin/status/{uid}`, which clients cannot write. → *Note:* `BLK-05` means nothing
creates that doc, so admin is currently unreachable for everyone — a denial-of-service on ourselves,
not an escalation path.

**E. Harvest user PII.** Any authenticated user reads `users/{uid}` and collects emails, last-login
IPs, and device fingerprints across the user base. → **Not blocked.** This is `BLK-10`, live today.
→ *Fix:* `S10` — move those fields to an owner-only doc.

**F. Poison the meal plan.** User writes prompt-injection text into their profile or a food
description to steer the model. → *Blocked by* the fencing guard in `PromptService` (user text is
delimited and declared as data) **and** the deterministic allergen filter that strips unsafe dishes
before the model sees candidates and refuses to generate if none remain. This is defense in depth
because the failure mode is a health harm, not a wrong answer.

---

## 10. Reviewing a change for security

Full checklist: [`../AGENTS.md`](../AGENTS.md) §3.2. The four that catch most issues:

1. **Who can read this, and who can write it?** Answer at the rules layer, not the UI layer.
2. **What happens if the client lies?** Every client-supplied value — model, price, amount, uid,
   count — is hostile input.
3. **What happens if this is called twice?** Idempotency is a security property once money or
   credits are involved.
4. **What does this leak on failure?** Error messages, logs, and analytics all count.
