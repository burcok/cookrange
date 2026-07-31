# PREMIUM.md — Monetization, Credits & Entitlements

> Tiers, what gates what, how money becomes an entitlement, and why the client can't fake it.
> Wire contracts: [`API.md`](API.md) §3. Trust model: [`SECURITY.md`](SECURITY.md).
>
> ⚠️ **Monetization is 0 % functional** (`BLK-04`). Client and server code are complete; **no store
> products exist and no store credentials are provisioned**, so no purchase has ever been validated.
> Status: [`../PROJECT_STATE.md`](../PROJECT_STATE.md).
>
> **Owns:** `billing_service.dart`, `ai_credit_service.dart`, `feature_gate_service.dart`,
> `functions/purchases.js`, `functions/entitlements.js`.

---

## 1. Tiers

`SubscriptionTier { free, premium, pro }` — `pro` is modelled but unused.

| | Free | Premium |
|---|---|---|
| **AI generations / day** | **2** | **20** |
| Meal plans, food logging, recipes, analytics | ✅ | ✅ |
| Community, chat, streaks, achievements | ✅ | ✅ |
| Advanced meal customization | — | ✅ |
| Full nutrition analytics history | — | ✅ |
| Coach-visibility perks | — | ✅ |
| Bonus AI credits (IAP top-up) | ✅ purchasable | ✅ purchasable |

Entitlements derive from the tier via `Entitlements` in `subscription_model.dart`
(`isPaid`, `isPremiumOrAbove`, `isPro`, `weeklyMealPlanGenerations`, …). Gate features through
`FeatureGateService`, which also owns `showPaywall()` — **never** branch on a raw tier string in UI.

---

## 2. Products

| Product ID | Type | Store |
|---|---|---|
| `com.cookrange.premium.monthly` | Auto-renewable subscription | Both (same subscription group) |
| `com.cookrange.premium.yearly` | Auto-renewable subscription | Both |
| `cookrange_ai_credits_10` | Consumable — 10 bonus AI credits | Both |

`BillingService` references these exact IDs. **None exist in either store yet** — purchases fail
until they're created and the paid-apps agreements are signed (`GO_LIVE.md` Phase 4).

---

## 3. AI credits

Two separate pools, both server-owned:

| Pool | Behaviour |
|---|---|
| **Daily quota** | 2/day free, 20/day premium. Auto-resets at midnight (`reset_at`) |
| **Bonus credits** | Bought as a consumable. **Never reset.** Burned **first**, before daily quota |

**The ledger `ai_credits/{uid}` is server-only** — owner-read, client-write denied. All arithmetic
happens inside `aiProxy`'s `enforceAndConsumeQuota()` transaction (fail-closed; returns HTTP 402 when
exhausted; rolls back on generation failure).

`AiCreditService` is **read-only**. It exists to render the badge and to pre-empt an obvious 402 —
it does not consume, grant, or roll back. `rollbackCredit` / `rollbackBonusCredit` are no-ops kept
for call-site compatibility; the server rolls back.

The same doc also carries per-user lifetime totals (`lifetime_requests`, `lifetime_tokens`,
`lifetime_cost_usd`, `by_type`) written by the proxy. See [`AI_SYSTEM.md`](AI_SYSTEM.md) §6.

**UI:** `AiCreditBadge` (live stream) → `AiCreditsSheet` (usage bar, reset countdown, plan chip,
upgrade CTA, restore purchases).

---

## 4. The purchase flow

```
Paywall / credits sheet
   → BillingService (in_app_purchase)  → store purchase UI
   → purchase completes on device
   → validatePurchase callable  ────────────────► SERVER
        ├─ verify receipt: Apple App Store Server API / Google Play Developer API
        ├─ dedupe purchase token via processed_purchases   (replay guard)
        ├─ entitlements.js → entitlements/{uid}   { tier, expires_at, product_id, source }
        ├─ entitlements.js → ai_credits/{uid}     (consumables only)
        └─ mirror subscription_tier onto users/{uid}  (UI convenience only)
   → client re-reads entitlement; paywall closes
```

**The client never grants anything.** It reports a purchase; the server decides whether it happened.

**Revocation** is webhook-driven: `appStoreNotifications` / `playRtdn` revoke on refund, chargeback,
or expiry. Both are pending go-live — until then, **a refunded subscription keeps its entitlement**.

**Restore purchases** is available in `AiCreditsSheet` — an App Store review requirement.

---

## 5. Where the truth lives

| State | Source of truth | Client access |
|---|---|---|
| Premium tier + expiry | `entitlements/{uid}` | **read-only** |
| AI credits + bonus | `ai_credits/{uid}` | **read-only** |
| Purchase token dedupe | `processed_purchases/{id}` | **none** — fully server-only |
| Commission ledger | `users/{uid}/commissions/{id}` | read own; **server-write only** |
| `subscription_tier` on the user doc | **mirror only** | read-only (field-locked) |

> ⚠️ Read premium from `entitlements/{uid}`, **not** the mirrored user-doc field. The mirror exists
> so list UIs don't need a second fetch; treating it as authoritative reintroduces exactly the hole
> ADR-008 closed. Until `S1` deploys the field lock, that mirror is still client-writable — which is
> why premium is currently bypassable.

---

## 6. Referral program

6-character codes in `referrals/{code}` (`owner_uid` pinned immutable; owner/admin update only).

Applying a code calls the **`applyReferral`** callable, which server-validates no-self-referral,
one-per-account, and `max_uses`, then grants a **7-day premium trial to both parties** and writes the
commission entry. Deep-linkable and shareable via `SharingService`.

**Coach commissions** (₺5 per premium referral, plus session/program commissions) are tracked by
`CommissionService` and surfaced in the affiliate earnings screen.

> ⚠️ **Tracking only — there is no payout rail** (`REF-04`). The screen computes a balance nobody can
> pay out. Commissions are server-write-only precisely because a client-writable ledger is direct
> fraud the moment payouts exist. Do not ship payouts before Stripe Connect / iyzico integration.

---

## 7. Revenue reporting

`CostAnalyticsService` + `AdminCostAnalyticsScreen` show cost, revenue, and margin.

- **AI cost is real** — measured tokens × per-model price from `ai_usage_stats`
- **Firebase cost is an estimate** — unit prices × `count()` aggregates, no GCP billing API
- **Revenue is an assumption** — premium user count × assumed price. There is no subscription
  analytics source, which is one of the costs of not using a managed provider (ADR-007)

---

## 8. What's blocking revenue

| Item | Kind |
|---|---|
| Apple Developer Program ($99/yr) + Google Play ($25) enrolment | 👤 owner |
| Create 3 products in both consoles; sign paid-apps agreements + banking/tax | 👤 owner |
| Apple `.p8` key + Play service-account JSON as Function secrets | 👤 owner |
| Sandbox / license testers configured | 👤 owner |
| **One real sandbox purchase → real entitlement**, end to end | 🤖 + 👤 gate |
| `S1` field lock deployed so the tier mirror stops being writable | 🤖 |
| Store webhooks live so refunds actually revoke | 🤖 + 👤 |

The full ordered path is `GO_LIVE.md` Phase 4 + Phase 5S. **`M3 — Commerce` does not exit until one
real sandbox purchase produces a real server-side entitlement.**

> **Worth revisiting:** ADR-007 chose `in_app_purchase` + our own validation over RevenueCat, to
> avoid revenue share and a third party holding entitlement truth. That code is written but has never
> processed a transaction, and most of the list above is work RevenueCat would have supplied. If
> monetization stays blocked, reopen that decision as a new ADR.

---

## 9. Future monetization

Documented in [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §A: paid marketplace
programs (currently gated behind an honest "coming soon" banner), coach subscription tiers, gym
white-label licensing, and the payout rail. All are **M6+** under the consumer-only scope cut
(ADR-012).
