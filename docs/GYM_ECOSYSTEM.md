# GYM_ECOSYSTEM.md — Gyms, Attendance & Gym Communities

> The gym side of the three-sided marketplace: gym profiles, membership, check-in, branded
> communities, and analytics.
>
> ⚠️ **Deferred to M6** (ADR-012). ~11 screens exist and stay in the codebase behind
> `AppConfigService.isFeatureEnabled` kill-switches — **not deleted**. This document describes how it
> is built; it makes no claim that it runs. Status: [`../PROJECT_STATE.md`](../PROJECT_STATE.md).
>
> **Owns:** `lib/screens/gym/`, `gym_service.dart`, `gym_leaderboard_service.dart`,
> `gym_analytics_service.dart`, `gym_application_service.dart`, `gym_post_service.dart`.

---

## 1. Why this exists

A consumer nutrition tracker competes with a dozen apps. A platform that also serves **gyms** and
**coaches** is a three-sided marketplace those trackers don't attempt — the most strategically
valuable asset in this codebase. That is precisely why it launches *after* the consumer product
proves retention, not alongside an unvalidated one.

---

## 2. Data model

| Path | Holds |
|---|---|
| `gyms/{id}` | `owner_uid`, name, address, city, `district`, `is_public`, `member_count`, `subscription_tier`, tags, lat/lng, `check_in_radius`, `qr_token` + expiry, `brand_color`, `is_verified`, `opening_hours` (per-weekday map, Faz 1 §1.1), `capacity` (Faz 1 §1.1), `contact_phone` (carried over from the approved application), `geofence_enabled` (owner opt-in, default `false`, Faz 1 §1.1), `live_occupancy` (server-only counter, Faz 1 §1.4/§1.5 — see §12 below), `attributed_member_count` / `attributed_premium_count` (server-only, Faz 6 §6.5/§6.6 — see §9) |
| `gyms/{id}/members/{uid}` | Membership record — `display_name`, `photo_url`, `joined_at`, `tier`, `last_check_in` (`GymMemberModel`; **no `role` field** — every member is an equal member, ownership lives only on `gyms/{id}.owner_uid`) |
| `gyms/{id}/posts/{id}` (+ `/comments`) | Gym-scoped feed |
| `gyms/{id}/checkins/{id}` | Check-in events — `uid`, method `qr\|gps\|manual\|geofence`. **Immutable** |
| `gyms/{id}/presence/{uid}` | Faz 1 §1.4 — live, in-gym-right-now record (`entered_at`, `source`, `last_seen_at`, `expires_at`, denormalized `display_name`/`photo_url`). Exists only while the member is inside. Server-write-only |
| `gyms/{id}/presence_sessions/{autoId}` | Faz 1 §1.4 — closed, immutable session record (`uid`, `entered_at`, `exited_at`, `duration_minutes`, `source`, `ended_by`). No `latitude`/`longitude`/`accuracy` field anywhere in this subtree |
| `gym_applications/{id}` | Owner applications awaiting admin review |
| `gym_wars/{id}` | Gym-vs-gym competition |
| `gym_attributions/{uid}` | Faz 6 §6.5 — immutable, server-written record of which gym's invite code a user signed up through (see §9) |
| `users/{uid}.gym_memberships[]` | Mirror for "my gyms" |
| `community_groups/{id}` (`kind: 'gym'`) | Faz 2 §2.3 — auto-created alongside `gyms/{id}` on approval; the gym's owner is the group's owner. Full contract in [`COMMUNITY.md`](COMMUNITY.md), not duplicated here |

Member records denormalize `display_name` / `photo_url` in **snake_case** — internally consistent,
and deliberately different from the user doc's camelCase `displayName`. Source the value from the
user doc's `displayName`; don't "fix" the convention (`CLAUDE.md` §9).

---

## 3. Becoming a gym owner

```
Consumer → side menu "Register Gym" → gym_application_screen (documents to Storage)
   → gym_applications/{id}  status: pending
   → admin reviews in ApplicationReviewScreen.forGym
   → approve → adds gymOwner to user_roles
             → creates gyms/{id}
             → audit entry + notification
   → UserProvider's live listener flips the menu WITHOUT a restart
```

Rejection and needs-more-info states surface in `gym_application_pending_screen`.

> `BLK-05` (admin unreachable) and `BLK-03` (approval notification fan-out) are both closed and
> deployed; see `PROJECT_STATE.md` for current status. No real gym application has been approved
> end to end against the live callables yet.

## 4. Gym setup

`gym_setup_screen.dart` (~1880 LOC) — name, address, city/district, tags, location pin, logo, and
**brand colour**, which tints the gym's community feed and member surfaces.

> `BLK-07` — **closed.** `storage.rules`'s `gym_logos/{gymId}` prefix was renamed to match the
> upload path gym setup actually writes to (`gyms/{gymId}/logo.jpg`), so the upload and the NSFW
> scanner now watch the same prefix.

---

## 5. Membership & attendance

Three check-in methods, one immutable record each:

| Method | Flow |
|---|---|
| **QR** | Gym displays a rotating token (`gym_qr_screen`); member scans in `gym_checkin_screen`. Non-members get `GymJoinPromptSheet` — join + check in together |
| **GPS** | Device location vs. the gym's lat/lng within `check_in_radius` |
| **Manual** | Owner-recorded fallback |
| **Geofence** (Faz 1 §1.2/§1.4/§1.5) | Background enter/exit via `native_geofence`, server-validated (`recordPresenceEvent`). See "Presence & automatic check-in" below |

Check-ins are create-only: no update, no delete. They feed the leaderboard and analytics.

### Presence & automatic check-in (Faz 1 §1.2/§1.4/§1.5/§1.6)

An opt-in, consent-gated background layer on top of the four check-in methods above — a member who
turns it on gets an automatic check-in the moment they cross their gym's geofence boundary, with no
QR scan or app open required.

- **Consent**: a dedicated, non-skippable `ConsentPurpose.gymPresence` screen, default **off**,
  granted per gym (max 3 gyms tracked at once — iOS's 20-region system limit, budgeted down for
  headroom). Turning it off stops any new record immediately. See [`COMPLIANCE.md`](COMPLIANCE.md).
- **Client**: `native_geofence` (`geofence_service.dart`) with a 4-tier fallback chain
  (`gym_presence_service.dart`) down to the existing QR/GPS paths if permission drops from "Always"
  to "While Using," is denied, or the device doesn't support it — nothing breaks, it just doesn't
  automate.
- **Server** (`recordPresenceEvent`, `functions/presence.js`): validates membership, `geofence_enabled`,
  consent, a rate limit (same gym within 10 min is rejected) and clock skew (±5 min) before writing
  `gyms/{id}/presence/{uid}` (open session) → on exit, closes it into
  `gyms/{id}/presence_sessions/{autoId}` and writes the matching `checkins/{id}` doc
  (`method: 'geofence'`) — so the leaderboard and analytics see it exactly like any other check-in.
- **No raw coordinates, ever**: none of `presence`, `presence_sessions` or `checkins` carry a
  `latitude`/`longitude`/`accuracy` field — only gym name, entry time, exit time.
- **Live occupancy**: every presence open/close transactionally increments/decrements
  `gyms/{id}.live_occupancy` (`touchesProtectedGymFields()` in `firestore.rules` blocks even the
  owner from writing it directly). The owner's dashboard can show a real "X people here now" (and a
  percentage, if `capacity` is set) — genuinely provable server-side, not a forbidden claim anymore.
- **Status**: server side is deployed and rules-tested; the client geofence trigger has not been
  exercised on real iOS/Android hardware in this environment (`BLK-16`, no signing identity) — see
  `PROJECT_STATE.md` for the exact "written, not field-verified" wording used everywhere else this
  gap is mentioned. Until real arrivals start coming in from the field, `live_occupancy` reads 0 at
  every gym.

### GPS presence & privacy — the reference implementation

The **"Near Me"** gym sort is the pattern every location feature in this codebase should copy:

1. A `PermissionPrimer` states the purpose, that the location is used **on-device only**, that it is
   **not stored**, the KVKK/GDPR basis, and that declining is fine
2. Only then does the OS dialog appear
3. Haversine sorting happens **in memory**; no coordinate is ever written
4. Declining keeps city/district browsing fully functional

Location is special-category-adjacent and needs explicit consent (*açık rıza*).
See [`COMPLIANCE.md`](COMPLIANCE.md) §6.

> `S13` — **partially closed.** The QR path validates server-side (`validateGymCheckin`) and the
> newer geofence path (§Faz 1) validates membership, `geofence_enabled`, consent, rate limit and
> clock skew together server-side in `recordPresenceEvent` (`functions/presence.js`). The GPS
> ("nearby, tap to check in") path is still client-only — its 100 m radius check is not
> re-verified server-side. That gap matters once leaderboards carry value.

---

## 6. Gym community & competition

- **Gym feed** — `gym_community_screen`, brand-coloured, with owner announcements. Same post
  mechanics as the global feed ([`COMMUNITY.md`](COMMUNITY.md))
- **Leaderboard** — member rankings from check-ins and streaks
- **Member home** — announcements and gym activity for members
- **Gym Wars** — built and working: `gym_leaderboard_screen.dart` has its own "Wars" tab,
  `getWarScore()` runs a real check-in `count()` query, and `endExpiredGymWars` (scheduled function,
  `functions/index.js`) auto-resolves expired wars and notifies both gyms. No longer behind a
  "coming soon" label (Faz 0 §0.6 removed the stale `gym.feature_challenges` badge).

---

## 7. Discovery

`gym_discovery_screen.dart` (~1280 LOC), using the shared `AppFilterBar`:

- **Location filters** — city, then optional district (81 provinces + ~1,100 districts from
  `turkish_locations.dart`)
- **Sorts** — Highest Rated (`avg_rating`) · **Popular (`member_count`, default)** · Newest
  (`created_at`) · **Nearest (`near_me`** — energy-accented, consent-gated, in-memory only)
- **Map view** — `flutter_map` / OSM with a horizontal gym list panel below; tapping a card opens an
  info sheet (name, address, description, tags, member count, "View Gym")

Every filter combination needs a matching composite index — see [`DATABASE.md`](DATABASE.md) §5.

## 8. Owner analytics

`gym_analytics_screen` (self-resolves the owner's gym): active members, peak hours, retention,
weekly attendance chart. Computed from check-ins via `GymAnalyticsService`, which uses `count()`
aggregation rather than reading documents to count them.

---

## 9. Invite codes, attribution & revenue (Faz 6 §6.1/§6.5/§6.6)

A gym acquires new app users through its own printable QR/poster codes, tracks how many of them
convert to Premium, and earns a manually-paid commission on that conversion — all behind
`FeatureFlags.gymInviteCodes` (code generation) and the newer, separately-killable
`FeatureFlags.gymAttribution` (attribution/earnings, §6.5/§6.6).

- **Codes** (§6.1): `GymInviteCodesScreen` + `GymInviteCodeDetailScreen` (QR + poster export),
  `referrals/{code}` with `type: 'gym'`, minted client-direct (rules re-verify real gym ownership) with
  a 5,000-use default ceiling. Full contract: [`DATABASE.md`](DATABASE.md), [`SERVICES.md`](SERVICES.md).
- **Attribution** (§6.5): redeeming a gym code no longer grants a personal-referral trial — it writes
  an immutable `gym_attributions/{uid}` and bumps `gyms/{id}.attributed_member_count`. The redeemed
  user sees "you signed up via {gym}" on their own profile, with a one-tap, display-only disconnect
  (the record itself never deletes — the gym's commission stays intact). The gym itself never gets
  direct read access to that record: `GymInviteCodesScreen`'s funnel header shows only the gym's own
  aggregate counters (signups, premium conversions), never an individual identity — a deliberately
  different, LOWER-stakes privacy posture than Faz 4's progress-sharing tiers, since attribution is
  acquisition-channel metadata, not health/behavior data, and the member's identity is already visible
  via the ordinary membership roster regardless.
- **Revenue** (§6.6): a real premium purchase by an attributed user accrues a flat `gymPremiumShare`
  commission (`functions/economy.js`'s `GYM_COMMISSION_TRY`) into the SAME `users/{uid}/commissions`
  ledger coaches/affiliates already use — triggered server-side from inside `purchases.js`'s purchase
  validation, never client-visible. `GymEarningsScreen` shows it with a literal "payouts are processed
  manually" banner and a real link to the gym's commission contract terms
  (`assets/legal/marketplace_terms_{en,tr}.md` §10 — was drafted long before this but never linked
  from any screen until this task; see `COMPLIANCE.md` §8).

---

## 10. Relationship to coaches

Gyms and coaches are **independent roles** that a single user can hold together — a gym owner can
also be a coach. The side menu reflects this: it only offers the role you *don't* have
(`hideGym` / `hideCoach` on the growth card).

There is currently **no formal gym↔coach association** — no "coaches at this gym", no gym-mediated
client referral, no revenue split between them. That's the main M6 design gap. See
[`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md).

---

## 11. Blockers & roadmap

| ID | Issue |
|---|---|
| `BLK-03` | Approval and gym notifications — fan-out fix deployed; no real approval exercised end to end yet |
| `S13` | GPS check-in's radius check is still client-only (QR and geofence paths are server-validated) |
| — | White-label is a brand colour only |

`BLK-05` (admin unreachable) is closed and deployed — see `PROJECT_STATE.md`.

**M6 roadmap** ([`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §B): real white-label
(logo, theme, optional own listing), gym subscription tiers, gym↔coach association, class scheduling,
equipment/capacity awareness, and deeper retention analytics.

**Before reopening this domain:** close the remaining half of `S13` (GPS path server validation),
verify `BLK-03` end to end against a real application (deployed, but not yet exercised live), and
pilot with 5–10 real gyms rather than launching broadly.
