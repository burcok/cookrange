# Community Groups — Product Roadmap

> Status: **P1 (MVP) shipped.** P2/P3 are planned, not yet built.
> Owner: product + community. Last updated: 2026-06-30.

---

## 1. Why groups (the retention thesis)

The global feed is broad and shallow — users scroll, maybe react, and leave. **Groups create
"small rooms" with a reason to come back**: a place where the people are *like you* (same city,
same gym, same goal) and where your post is actually seen by a relevant audience. Local + interest
scoping is the wedge:

- **Local belonging** — "İstanbul Koşucuları", "Kadıköy Vegan", "[Gym] Members". People care more
  about people near them; local groups convert online activity into real-world accountability.
- **Goal tribes** — "Kilo verme 2026", "Bulk season", "Keto TR". Shared goal → shared streaks →
  social pressure → retention.
- **Creator/owner gravity** — coaches and gym owners get a home base; their clients follow them in.

The single metric this feature optimizes: **D30 retention of users who join ≥1 group** vs. those who
don't. Secondary: posts-per-member-per-week inside groups (engagement density).

---

## 2. Who sees what, and why (the flow)

This was the open design question. The model:

| Actor | Discovery | Inside a group |
|---|---|---|
| **Logged-out** | Nothing (auth-gated app). | — |
| **Any signed-in user** | Sees **public** groups, defaulted to **their city**, filterable by district, sortable by activity/members/newest. Can search across cities. | Can read a public group's about + member count. To **post or see the member-only feed signals**, they must **join** (one tap, no approval for public groups). |
| **Member** | Their joined groups surface in a "My groups" strip + the community carousel. | Full feed: read + post + react + comment. Posts they make in-group carry `groupId` and appear only in that group's feed (not the global feed). |
| **Owner** | Same as member, plus their group ranks by `last_activity_at`. | Can edit group meta, (P3) moderate members/posts. |
| **Private group** (P3) | **Not** shown in discovery. Reached only via invite link / code. | Join requires invite. |

**The core loop:** discover (city default) → preview → join → see relevant feed → post → others in
your city see it → they join → activity bumps the group up discovery → more joins. Location is the
cold-start seed; activity is the ranking signal.

### Location handling (KVKK-clean — important)
The app stores **no GPS**. The discovery city/district is a **user-chosen preference** (the same
`TurkishLocations` picker used by gym/coach discovery), remembered in `SharedPreferences`
(`groups_last_city` / `groups_last_district`). This keeps the "default to my city" UX without
storing or processing device location — consistent with the legal-first stance in `docs/COMPLIANCE.md`.
If P2 introduces GPS "near me" sorting, it must reuse the gym/coach consent primer (on-device only,
never stored).

---

## 3. Data model (as built in P1)

```
community_groups/{groupId}
  name, description, city, district, cover_image_url,
  owner_uid, member_count, is_public, tags[],
  created_at, updated_at, last_activity_at        ← ranking signal

community_groups/{groupId}/members/{uid}
  display_name, photo_url, role (owner|moderator|member), joined_at

users/{uid}.group_memberships: [groupId, ...]      ← "My groups" (no extra reads)

posts/{postId}.groupId  (optional)                 ← group-scoped feed; null = global feed
```

**Indexes** (`firestore.indexes.json`): `community_groups` on `is_public` + each sort field
(`last_activity_at` / `member_count` / `created_at`), plus the same with `city` and `city`+`district`
prefixes; `posts` on `groupId` + `timestamp`.

**Rules** (`firestore.rules`): groups readable by any signed-in user; create requires
`owner_uid == auth.uid`; update by owner/admin **or** a counter-only diff (`member_count`,
`last_activity_at`, `updated_at`) so members can join/leave/post; members subcollection writable by
the member themselves (self join/leave) or the owner/admin.

**Service**: `CommunityGroupService` (create/search/join/leave/streams/touchActivity).
Group feed reuses `CommunityService.getGroupFeedStream(groupId)` + the existing `createPost(groupId:)`.

---

## 4. P1 — MVP (✅ shipped)

- Create group (name, description, city, district, tags, public toggle) — `create_group_screen.dart`.
- Discover public groups, **defaulted to the user's remembered city**, district filter, sort by
  most-active / most-members / newest — `groups_discovery_screen.dart` (uses the shared `AppFilterBar`).
- Join / leave; "My groups" strip; group membership mirrored on the user doc.
- Group detail: header (location, members, about, tags), join/leave, **member-only group feed** with a
  lightweight composer; posts render via the existing `GlassPostCard` — `group_detail_screen.dart`.
- Entry points: community "Groups" carousel (stub retired) + side-menu "Groups".

---

## 5. P2 — Engagement (planned)

The "reason to come back daily" layer:

1. **Weekly local leaderboard** — per-group ranking by check-ins / logged days / posts. Reuse the
   `gym_leaderboard_service` pattern. Drives competitive return visits.
2. **Group challenges** — owner/mods launch a time-boxed challenge ("7-day no-sugar"); members opt in,
   progress bar + finisher badges. Hook into the existing challenge system.
3. **Events / meetups** — a group can post an event (date, place, RSVP). Local groups → real-world
   meetups → the strongest retention signal there is.
4. **Activity push** — opt-in "new post in {group}" / "challenge starting" notifications via the
   existing `NotificationService` + per-group mute in `NotificationPreferencesService`.
5. **"New in your city" suggestions** — surface newly-created or fast-growing local groups on the home
   dashboard and community top.
6. **Group cover images** — `StorageUploadService` upload; visual identity lifts join rates.
7. **Role mirroring** — a coach/gym owner's group auto-suggested to their clients/members.

Exit criteria for P2: median active group has a live leaderboard + ≥1 challenge/month; push opt-in
measurable lift on D7 return.

---

## 6. P3 — Growth & moderation (planned)

Needed once groups have scale (and bad actors):

1. **Moderators** — owner promotes members to `moderator`; can remove posts/members. (`role` field
   already exists.)
2. **Reports & moderation queue** — reuse `reports/{id}` + admin tooling for group posts.
3. **Invite links / codes** — `referrals`-style codes for private groups; deep-link join.
4. **Private / invite-only groups** — `is_public=false` already hides from discovery; add the
   request/approve join flow.
5. **Suggested groups** — lightweight recommendations from city + goal + followed coaches.
6. **Anti-abuse** — rate-limit group creation, spam detection on group posts (reuse `_checkContent`).

---

## 7. Risks & open questions

- **Cold start**: empty cities feel dead. Mitigation — seed a few official groups per major city; the
  discovery empty-state CTAs straight into "create the first group in {city}".
- **Counter integrity**: `member_count` is incremented client-side under a counter-only rule. If it
  drifts, a periodic Cloud Function reconcile (count members subcollection) is the fix — defer to P2.
- **Feed dilution**: group posts are excluded from the global feed (only `groupId == null` shows
  globally via the default query path). Confirm no query accidentally surfaces group posts globally.
- **Moderation latency**: until P3, a public group is self-policed by its owner only. Acceptable at
  MVP scale; revisit before heavy promotion.
- **KVKK**: keep location a preference, never stored GPS, unless/until a consented "near me" lands.
