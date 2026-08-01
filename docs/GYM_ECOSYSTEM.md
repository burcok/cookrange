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
| `gyms/{id}` | `owner_uid`, name, address, city, district, `is_public`, `member_count`, `subscription_tier`, tags, lat/lng, `check_in_radius`, `qr_token` + expiry, `brand_color`, `is_verified` |
| `gyms/{id}/members/{uid}` | Membership record + role |
| `gyms/{id}/posts/{id}` (+ `/comments`) | Gym-scoped feed |
| `gyms/{id}/checkins/{id}` | Check-in events — `uid`, method `qr\|gps\|manual`. **Immutable** |
| `gym_applications/{id}` | Owner applications awaiting admin review |
| `gym_wars/{id}` | Gym-vs-gym competition |
| `users/{uid}.gym_memberships[]` | Mirror for "my gyms" |

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

> ⚠️ `BLK-07` — **logo upload writes to an unruled Storage prefix.** Gym setup is broken, and the
> NSFW scanner watches a different prefix, so those uploads are unscanned. Fix the rule and the
> scanner prefix together.

---

## 5. Membership & attendance

Three check-in methods, one immutable record each:

| Method | Flow |
|---|---|
| **QR** | Gym displays a rotating token (`gym_qr_screen`); member scans in `gym_checkin_screen`. Non-members get `GymJoinPromptSheet` — join + check in together |
| **GPS** | Device location vs. the gym's lat/lng within `check_in_radius` |
| **Manual** | Owner-recorded fallback |

Check-ins are create-only: no update, no delete. They feed the leaderboard and analytics.

### GPS presence & privacy — the reference implementation

The **"Near Me"** gym sort is the pattern every location feature in this codebase should copy:

1. A `PermissionPrimer` states the purpose, that the location is used **on-device only**, that it is
   **not stored**, the KVKK/GDPR basis, and that declining is fine
2. Only then does the OS dialog appear
3. Haversine sorting happens **in memory**; no coordinate is ever written
4. Declining keeps city/district browsing fully functional

Location is special-category-adjacent and needs explicit consent (*açık rıza*).
See [`COMPLIANCE.md`](COMPLIANCE.md) §6.

> ⚠️ Check-in validation is weak (`S13`): membership, geofence, and rate limit are not enforced
> together server-side, so check-ins are spoofable. That matters once leaderboards carry value.

---

## 6. Gym community & competition

- **Gym feed** — `gym_community_screen`, brand-coloured, with owner announcements. Same post
  mechanics as the global feed ([`COMMUNITY.md`](COMMUNITY.md))
- **Leaderboard** — member rankings from check-ins and streaks
- **Member home** — announcements and gym activity for members
- **Gym Wars** — model and service exist; the competition UI is minimal. Effectively unbuilt

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

## 9. Relationship to coaches

Gyms and coaches are **independent roles** that a single user can hold together — a gym owner can
also be a coach. The side menu reflects this: it only offers the role you *don't* have
(`hideGym` / `hideCoach` on the growth card).

There is currently **no formal gym↔coach association** — no "coaches at this gym", no gym-mediated
client referral, no revenue split between them. That's the main M6 design gap. See
[`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md).

---

## 10. Blockers & roadmap

| ID | Issue |
|---|---|
| `BLK-07` | Gym logo upload writes to an unruled Storage prefix; scanner watches the wrong one |
| `BLK-03` | Approval and gym notifications — fan-out fix deployed; no real approval exercised end to end yet |
| `S13` | Check-ins lack combined membership + geofence + rate-limit validation |
| — | Gym Wars UI effectively unbuilt |
| — | White-label is a brand colour only |

`BLK-05` (admin unreachable) is closed and deployed — see `PROJECT_STATE.md`.

**M6 roadmap** ([`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §B): real white-label
(logo, theme, optional own listing), gym subscription tiers, gym↔coach association, class scheduling,
equipment/capacity awareness, and deeper retention analytics.

**Before reopening this domain:** close `BLK-07` and `S13`, verify `BLK-03` end to end against a real
application (deployed, but not yet exercised live), and pilot with 5–10 real gyms rather than
launching broadly.
