# COACH_ECOSYSTEM.md — Coaches, Clients & the Program Marketplace

> The coach side of the marketplace: profiles, discovery, client management, reviews, programs, and
> revenue sharing.
>
> ⚠️ **Deferred to M6** (ADR-012). ~8 coach screens + 3 program screens exist and stay in the
> codebase behind kill-switches — **not deleted**. This document describes how it is built, not that
> it runs. Status: [`../PROJECT_STATE.md`](../PROJECT_STATE.md).
>
> **Owns:** `lib/screens/coach/`, `lib/screens/programs/`, `coach_service.dart`,
> `coach_application_service.dart`, `coach_review_service.dart`, `program_service.dart`,
> `commission_service.dart`.

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

> `BLK-05` (admin unreachable) is closed and deployed. `BLK-03` (approval notification fan-out) has
> code + rules written — deploy pending; see `PROJECT_STATE.md` for current status.

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

### AI client reports
The coach can generate an AI summary of a client's progress. Two obligations:

1. **This is a third party reading another person's health data.** The client's consent must cover
   coach access; if they revoke it, the report path must stop working. See
   [`COMPLIANCE.md`](COMPLIANCE.md) §9.
2. It consumes the **coach's** AI credits and is metered under the coach's uid
   ([`AI_SYSTEM.md`](AI_SYSTEM.md) §6).

## 5. Reviews & rating

`coach_profiles/{uid}/reviews/{reviewerUid}` — one review per reviewer, rating 1–5, **immutable**
(no update, no delete at the rules layer). `CoachReviewService` updates `avg_rating` and
`rating_count` in a **transaction**, so concurrent reviews can't corrupt the average.

> ⚠️ `S13` — a review does not require a real coach↔client relationship, so ratings are gameable.
> Gate review creation on an existing client link before this ships.

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
> live storefront and is one of the reasons the domain is deferred. Restrict it to a server-side
> seeder.

---

## 7. Revenue sharing

`CommissionService` writes to `users/{uid}/commissions/{id}`:

| Type | Trigger |
|---|---|
| `referral` | Someone subscribes via the coach's code — ₺5 per premium referral |
| `coachSession` | A coaching session is completed |
| `programSale` | A paid program sells (not yet possible) |

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
| `BLK-03` | Approval and client notifications — fan-out fix code+rules written, deploy pending |
| `S13` | Reviews don't require a real client relationship |
| `REF-04` | No payout rail; earnings are computed but unpayable |
| — | Paid programs deliberately stubbed |

`BLK-05` (admin unreachable) is closed and deployed — see `PROJECT_STATE.md`.

**M6 roadmap** ([`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §A, §E): paid programs
with real checkout, coach subscription tiers, in-app session booking, gym↔coach association,
richer AI client analytics, and the payout provider.

**Before reopening:** close `BLK-09` (a security defect, not a feature gap) and `S13`; confirm `BLK-03`
is deployed and verified; integrate a payout rail; add marketplace terms to the legal documents. Then
pilot with 5–10 real coaches.
