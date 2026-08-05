# COACH_ECOSYSTEM.md — Coaches, Clients & the Program Marketplace

> The coach side of the marketplace: profiles, discovery, client management, reviews, programs, and
> revenue sharing.
>
> **Built and live in the shipped client — this is not deferred or kill-switched off today.**
> ADR-012 (2026-07-31) planned to gate gym/coach/programs behind `AppConfigService.isFeatureEnabled`
> kill-switches and hold public launch for M6. In the code as it stands: the switch
> (`FeatureFlags.coach`, `lib/core/utils/feature_flags.dart`) defaults to **enabled** —
> `AppConfig.isFeatureEnabled` (`app_config_model.dart`) returns `true` for any key with no explicit
> admin override — and it gates the same real entry points a user would actually reach this from
> (side menu, Discover hub, quick-actions sheet, the home role card) as the gym flag. Nothing in this
> codebase indicates an admin has ever set `app_config/global.features.coach = false`. The
> member-consent system behind AI client reports (§4) was designed and shipped well *after* ADR-012's
> cut date — the build never actually paused. Read "M6" below as the remaining **go-to-market**
> milestone (close `BLK-09`/`S13`, pilot with 5–10 real coaches) rather than a technical
> unavailability. Status: [`../PROJECT_STATE.md`](../PROJECT_STATE.md).
>
> **Owns:** `lib/screens/coach/`, `lib/screens/programs/`, `coach_service.dart`,
> `coach_application_service.dart`, `coach_review_service.dart`, `coach_review_model.dart`,
> `program_service.dart`, `commission_service.dart`, `progress_sharing_service.dart`,
> `progress_sharing_model.dart`, and `functions/summaries.js` (shared with `GYM_ECOSYSTEM.md` — the
> same tiered-consent mechanism serves both scope types).

---

## 1. Data model

| Path | Holds |
|---|---|
| `coach_profiles/{uid}` | bio, specializations, certifications, `is_accepting_clients`, `vanity_code`, `client_count`, `hourly_rate`, city/district, lat/lng, `avg_rating`, `rating_count`, `is_verified` |
| `coach_profiles/{uid}/clients/{clientUid}` | Coach↔client link + status |
| `coach_profiles/{uid}/reviews/{reviewerUid}` | **Immutable** reviews — create only, no update, no delete |
| `coach_applications/{id}` | Applications awaiting admin review |
| `users/{uid}/coaching_requests/{clientUid}` | Inbound link requests |
| `programs/{id}` (+ `/weeks/{id}/sessions`) | Marketplace programs |
| `users/{uid}/program_enrollments/{programId}` | Enrollment + progress |
| `users/{uid}/commissions/{id}` | Commission ledger — **server-write only** |
| `users/{uid}/payout_requests/{id}` | Payout requests |
| `users/{uid}/progress_sharing/{scopeId}` | Faz 4 §4.1 — the **member's own** tiered consent decision for scope `coach_{coachUid}` (or `gym_{gymId}`, shared shape with `GYM_ECOSYSTEM.md`) — owner-only, 0-3 `level`, versioned + timestamped |
| `coach_profiles/{uid}/member_summaries/{memberUid}` | Cached AI/template progress summary from `generateMemberProgressSummary`, 7-day TTL, invalidated immediately on any tier change |
| `coach_profiles/{uid}/progress_share_invites/{memberUid}` | One-time "share your progress" invite dedup receipt (§4) |
| `users/{uid}/access_log/{id}` | Transparency: which scope viewed this member's summary, and when (member-readable) |

Coach collections denormalize `display_name` / `photo_url` in snake_case — consistent within the
domain, deliberately unlike the user doc (`CLAUDE.md` §9).

---

## 2. Becoming a coach

```
Consumer → "Become Coach" → coach_application_screen (~1135 LOC, multi-step:
             specializations, certifications, references, documents → Storage)
   → coach_applications/{id}  status: pending
   → admin reviews in ApplicationReviewScreen.forCoach
   → approve → adds coach to user_roles
             → creates coach_profiles/{uid}
             → audit entry + notification
   → coach_profile_setup_screen completes the public profile (2 steps)
```

Status surfaces in `coach_application_pending_screen` (pending / approved / rejected / needsMoreInfo).

> `BLK-05` (admin unreachable) and `BLK-03` (approval notification fan-out) are both closed and
> deployed; see `PROJECT_STATE.md` for current status. No real coach application has been approved
> end to end against the live callables yet.

---

## 3. Discovery

`coach_discovery_screen.dart` (~1270 LOC), shared `AppFilterBar`:

- **Curation** — Top Coaches (`getTopCoachesStream`: verified + accepting, `avg_rating` DESC) and
  Rising Stars, with rank badges
- **Sorts** — Highest Rated (`avg_rating`) · **Popular (`client_count`, default)** · Newest
  (`created_at`) · Nearest (`near_me`, consent-gated, in-memory Haversine — same KVKK pattern as gym
  discovery, see [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md) §5)
- **Location** — city, then optional district

`searchCoaches(query, city:, district:, sortBy:)`. Each filter+sort combination needs a composite
index ([`DATABASE.md`](DATABASE.md) §5).

---

## 4. Client management

| Screen | Purpose |
|---|---|
| `coach_dashboard_screen` | Setup CTA, or client stats / at-risk / active counts |
| `coach_clients_screen` | Roster: active · pending · completed |
| `coach_client_detail_screen` | Client workspace: progress, logs, **AI report**, rating |

**Linking** is request-based: a client sends a coaching request, the coach accepts, and the link is
written to both `coach_profiles/{uid}/clients/{clientUid}` and the client's side.

**At-risk detection** flags clients whose logging consistency has dropped — client-side heuristics,
no AI call.

### AI client reports — tiered consent, server-authoritative (Faz 4 §4.1–§4.4)

The old path here — `_generateAiReport()`, client-side, building its prompt from whatever
`CoachClientModel` the screen already held in memory and calling `AIService().generateJson()`
directly, with **zero consent check and zero re-verification that the coaching relationship was
still active** — is **deleted**. `coach_client_detail_screen.dart` now drives a state machine off
`ProgressSharingService` / the `generateMemberProgressSummary` callable (`functions/summaries.js`),
which is the full server-authoritative replacement:

1. **Member-controlled, tiered consent**, not a blanket "coach can see everything while the
   relationship is active." `users/{uid}/progress_sharing/{scopeId}` — 4 tiers: **0** none, the
   default and the only one the server ever assumes (`generateMemberProgressSummary` rejects
   outright, `permission-denied`/`not_shared`, at tier 0); **1** check-in frequency, streak, last
   visit; **2** + logging regularity; **3** + weight-change **direction only** — raw weight history
   is never exposed through this path, by design, not by omission. A member grants/revokes each
   scope (per gym, per coach) independently, at any time.
2. **Authority is re-derived server-side, never trusted from the client.** The caller must really be
   the scope's gym owner (or an admin) with the target a real `gyms/{id}/members/{uid}`, or really
   the scope's own coach with an `active` `clients/{memberUid}` link — the identical
   "real, pre-existing relationship" bar `templates.js`'s plan-offer eligibility check already uses.
3. **Rate-limited to 1 generation per (caller, member) per rolling 24h**
   (`checkAndBumpSlidingWindow`), independent of — and far tighter than — the coach's own general
   daily AI quota.
4. **The MEMBER's own AI/cross-border-transfer consent gates the LLM call itself**, not the coach's.
   If the member hasn't granted `ai_processing` + `cross_border_transfer`, the coach still gets a
   report — built from a **template narrative** over the same permitted fields, no LLM call at all —
   clearly labeled in the UI as template vs. AI-generated (never a silent, unexplained downgrade).
5. Credit/quota is charged to the **caller** (coach or gym owner), never the member — matches this
   section's older note, now enforced server-side rather than by convention.
6. Cached 7 days (`member_summaries/{memberUid}`); revoking a tier deletes that cache
   **immediately** via a real Firestore trigger (`onProgressSharingWrite`), not on the next TTL
   sweep — this is what makes revocation actually take effect at the moment it happens.
7. **Honest, documented data gap**: `plan_adherence_pct` (tier 2) and `weight_trend` (tier 3) always
   resolve to the literal string `'insufficient_data'` — there is no plan-adherence calculator or
   weight-history datasource anywhere in this codebase yet (a single onboarding weight snapshot is
   not a history). The full tier/consent/response-shape contract is wired for both regardless, so a
   real data source can slot in later without a contract change; nothing is fabricated meanwhile.
8. A tier-0 member gets a **one-time, server-deduplicated invite** to start sharing
   (`sendProgressShareInvite`, backed by an idempotent `.create()`) instead of a repeatable nudge.
9. A separate `getConsentingMemberUids` callable scopes the coach's at-risk list to tier≥1
   consenters only, and backs a k-anonymity-gated aggregate (hidden below 5 included members) —
   closing the audit finding where the at-risk list previously read every client unfiltered.

See [`COMPLIANCE.md`](COMPLIANCE.md) §9 for the legal framing and the site's progress-analytics page
for the member-facing description of the same tiers.

## 5. Reviews & rating

`coach_profiles/{uid}/reviews/{reviewerUid}` — one review per reviewer, rating 1–5, **immutable**
(no update, no delete at the rules layer). `CoachReviewService` updates `avg_rating` and
`rating_count` in a **transaction**, so concurrent reviews can't corrupt the average.

> ⚠️ `S13` — **partially mitigated, not closed.** `CoachReviewService.canReview` now checks for a
> real, linked client relationship (`coach_profiles/{uid}/clients/{reviewerUid}` must exist) plus a
> food-log anti-fraud signal before the app's own "rate" button ever appears — so the shipped app no
> longer lets a stranger review a coach. But `firestore.rules`' `create` rule for
> `coach_profiles/{uid}/reviews/{reviewerUid}` still only checks `reviewerUid` and the rating range —
> no server-side relationship check. A write that bypasses the app (a direct API call) can still post
> an ungated review. Add the same `exists()`/`clients` check to the rule before this ships.

---

## 6. Program marketplace

`programs/{id}` with weeks → sessions. Lifecycle:

```
coach drafts → publish → status: pending → admin review → approved → visible in marketplace
```

| Screen | Role |
|---|---|
| `program_marketplace_screen` | Browse approved programs, category filter | all |
| `my_programs_screen` | Coach library: draft / published / archived | coach |
| `program_detail_screen` | Weeks, sessions, reviews, enroll | all |

**Free programs enroll and track progress.** Paid programs are gated behind an honest
"coming soon" banner rather than a broken checkout — keep it that way until payouts exist.

> ⚠️ `BLK-09` — **`coach_uid == 'demo'` lets any user publish into the public marketplace.** The
> exception was added for the demo seeder and never scoped to it. This is content injection into a
> live, reachable storefront (see this doc's header — the marketplace isn't behind a working
> kill-switch) and must close before any real coach pilots. Restrict it to a server-side seeder.

---

## 7. Revenue sharing

`CommissionService` writes to `users/{uid}/commissions/{id}`:

| Type | Trigger |
|---|---|
| `referral` | A coach's vanity code is **redeemed** by a new signup — flat ₺5, granted the instant the code is applied, alongside the mutual 7-day Premium trial. **Not** tied to a real purchase — it fires from a free-trial grant, same as any other personal referral code (`economy.js`'s `applyReferral`) |
| `coachSession` | A coaching session is completed |
| `programSale` | A paid program sells (not yet possible) |

A fourth type, `gymPremiumShare`, exists in the same `CommissionType` enum and ledger shape but is a
**gym-only** mechanism (a real, store-verified Premium purchase by a gym-attributed user) — see
[`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md) §9. It's a materially different trigger from `referral` above
(a real purchase vs. a free-trial grant), which is why only `gymPremiumShare` entries carry a
`purchase_key` and are reachable by refund/chargeback reversal (`entitlements.js`'s
`reverseCommissionsForPurchase`) — `referral` is structurally exempt, never having a real purchase to
reverse against.

Statuses: pending → approved → paid (or rejected). `EarningsSummaryModel` aggregates them for
`affiliate_earnings_screen`, which also files payout requests.

**Commissions are server-write only.** A client-writable ledger is direct fraud the moment payouts
exist, so `applyReferral` writes the entry server-side after validating the referral graph
([`PREMIUM.md`](PREMIUM.md) §6).

> ⚠️ **There is no payout rail** (`REF-04`). The earnings screen computes a balance nobody can pay.
> Stripe Connect or iyzico integration is required before any payout UI becomes real, along with
> marketplace payout terms in the legal documents.

### Coach vanity codes
Coaches get a `vanity_code` on their profile that doubles as a referral code — the attribution link
between discovery and commission.

---

## 8. Blockers & roadmap

| ID | Issue |
|---|---|
| `BLK-09` 🔥 | `coach_uid == 'demo'` allows public marketplace publishing by anyone |
| `BLK-03` | Approval and client notifications — fan-out fix deployed; no real approval exercised end to end yet |
| `S13` | Reviews are gated client-side (`canReview`) but not yet in `firestore.rules` — a direct write still bypasses the relationship check |
| `REF-04` | No payout rail; earnings are computed but unpayable |
| — | Paid programs deliberately stubbed |

`BLK-05` (admin unreachable) is closed and deployed — see `PROJECT_STATE.md`.

**M6 roadmap** ([`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §A, §E): paid programs
with real checkout, coach subscription tiers, in-app session booking, gym↔coach association,
richer AI client analytics, and the payout provider.

**Before reopening:** close `BLK-09` (a security defect, not a feature gap) and `S13`; verify `BLK-03`
end to end against a real application (deployed, but not yet exercised live); integrate a payout
rail; add marketplace terms to the legal documents. Then pilot with 5–10 real coaches.
