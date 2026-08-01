# COMMUNITY.md — Social, Chat & Moderation

> The social graph, the feed, messaging, gamification, and how abuse is handled.
> Collection shapes: [`DATABASE.md`](DATABASE.md). Screens: [`FRONTEND.md`](FRONTEND.md) §5.
>
> **Owns:** `community_service.dart`, `chat_service.dart`, `follow_service.dart`,
> `friend_service.dart`, `community_group_service.dart`, `notification_service.dart`,
> `signal_service.dart`, `streak_squad_service.dart`, `achievement_service.dart`,
> `reputation_service.dart`, moderation paths.

---

## 1. Feed & posts

`posts/{postId}` with `PostType { text, recipe, progress, meal }`.

- **Composition** — text, image carousel, an attached recipe, or a progress/meal card
- **Reactions** — a reaction map plus `likedByUids[]`; draggable reaction picker in post detail
- **Comments** — `posts/{id}/comments/{id}`, own counter, author-editable
- **Saving** — `users/{uid}/saved_posts/{postId}`
- **Filters** — Latest · Global · Friends · Following · Gym · Saved, plus topic chips
  (`arrayContains` on tags) via the shared `AppFilterBar`
- **Weekly highlights** — `getTopPostThisWeek`, `getTopStreakUserThisWeek`
- **@mentions** — autocomplete, highlight, notification fan-out
- **Pagination** — cursor-based `fetchPostsPage` with `startAfter`; filter-aware

**Groups.** `community_groups/{groupId}` are location-based (city/district) with a members
subcollection and `member_count`. A post carries an optional top-level `groupId` (null = global
feed); `getGroupFeedStream` serves the scoped feed. Joined groups mirror onto
`users/{uid}.group_memberships[]`. Design: [`roadmap/COMMUNITY_GROUPS.md`](roadmap/COMMUNITY_GROUPS.md).

> ⚠️ `BLK-08` — **any user can mutate any post's non-content fields.** Like counts, the announcement
> flag, and `groupId` are all writable by anyone. Fix in the rule, not the client.

---

## 2. Social graph

Three distinct relationships — don't conflate them:

| Relationship | Shape | Symmetry |
|---|---|---|
| **Follow** | `users/{uid}/following/{targetUid}` + `users/{uid}/followers/{sourceUid}` | One-way, no approval |
| **Friend** | `users/{uid}/friends/{friendId}`, via `friend_requests` | Mutual, requires acceptance |
| **Block** | `users/{uid}/block_list/{blockedId}` | One-way, owner-only |

Friends gate private-profile visibility (`UserModel.isPrivate`): non-friends see only a lock card.
Enforced in `profile_screen.dart` behind a `_privacyResolved` gate with a fresh re-fetch. **Profile
detail is UI-gated** — it lives on the readable user doc, so this is presentation, not security.
`food_logs` and `meal_plans` are genuinely owner-only server-side.

Follow/friend mutation goes through `functions/social.js` (`followUser`, `unfollowUser`,
`sendFriendRequest`, `respondToFriendRequest`, `cancelFriendRequest`) — `FollowService`/`FriendService`
call these callables rather than writing `friends`/`friend_requests` directly. Unfriend
(`FriendService.removeFriend`) stays client-direct: it only ever deletes the caller's own side, which
is already owner-scoped-safe.

> ⚠️ Block enforcement is client-side only (`S13`). A blocked user's content is hidden, not withheld.
> `friends`/`friend_requests` open-creates (`S5`) are closed in code+rules (`SEC-06`) — pending deploy.

---

## 3. Chat

`chats/{id}` (participants, `lastMessage`, `unreadCounts`, type, `typingUsers`) with
`chats/{id}/messages/{id}`.

Types: **private** (1:1) · **group** · **system** · **gym**. Supports typing indicators, image
messages, read status, and unread counts. Content-length capped at the rules layer.

Chat images use a **participants-only scoped path** with unguessable random filenames, plus
client-side EXIF/GPS stripping on upload.

**Chat push works** — `onChatMessageCreated` is wired correctly. It was the only push path that did
until `BLK-03` (fan-out fix, §4) landed in code — still pending deploy as of this writing.

---

## 4. Notifications

**Structured storage only** (ADR-010), canonical path `notifications/{uid}/items/{docId}` (`BLK-03`).
`NotificationService.sendNotification(type:, actorUid:, actorName:, actorPhotoUrl:, relatedId:,
metadata:)` — **never** pre-rendered text — is now a thin client wrapper around the `createNotification`
Cloud Function callable; `actorUid`/`actorName`/`actorPhotoUrl` passed to it are accepted for source
compatibility but ignored, since the callable always derives the actor from the caller's own auth
identity and re-fetches their current name/photo server-side. Follow/friend-request notifications are
created inside their own callables (`functions/social.js`) since those also write the edge atomically;
admin-authored ones (coach/gym decisions, free-text messages) go through `sendAdminNotification`
(admin-claim-gated). `NotificationPresenter` renders title/body/icon/colour on the reader's device from
`notifications.feed.*` keys, so the language is always the reader's and the actor name is current. Push
text (`functions/index.js: getPushText`) mirrors the same EN/TR copy server-side.

`NotificationType` is backward-compatible: legacy values (`like`, `friend_request`) still parse, but
prefer the granular ones (`likePost`, `likeComment`, `reaction`, `referral`, `streakMilestone`).

**Mute groups** (`users/{uid}.notification_muted`): likes · comments · friends · system · referral ·
reminders. Respected by the fan-out function — muted groups still get the in-app notification, never
the push.

**Adding a notification type:** add the `type`, add `notifications.feed.*` keys in **EN and TR**, add
an EN/TR case to `getPushText`, and handle it in `NotificationPresenter` — all in the same change, or
it renders as a raw key (in-app) / generic text (push).

> `BLK-03`/`SEC-06` — the fan-out trigger (`onInAppNotificationCreated`) now has a real writer for
> every notification type, all server-authored via Admin SDK; client `create` on the notification path
> is denied unconditionally by rule. Code + rules tests written, **deploy pending** as of this writing
> — see `PROJECT_STATE.md` for current status. Physical-device push delivery cannot be verified in
> this environment (no iOS/Android hardware, and the iOS Simulator cannot receive real APNs).

---

## 5. Ephemeral & group accountability

- **Signals** — `signals/{id}`, short-lived broadcasts with a TTL via `expiresAt`. Content-capped.
  Needs a Firestore TTL policy so they actually expire and stop costing storage.
- **Streak Squads** — `squads/{id}`, small accountability groups with invite codes and a shared
  leaderboard.

---

## 6. Gamification

| System | Mechanic |
|---|---|
| **Streaks** | Daily streak with freeze consumption; milestone banners. Unit-tested |
| **Achievements** | 11 badges, `kAchievementCatalog`. `earn(uid, key)` is idempotent; `checkAndGrant` fires from every success path; `backfillForUser` for existing accounts. Profile grid with a reduced-motion-aware unlock animation |
| **Reputation** | Score and badges derived from activity |
| **Leaderboards** | Global + friends; gym leaderboards are separate |
| **Weekly recap** | AI-generated week score, wins, challenges, trend |

> ⚠️ `streak` and `reputation` are **client-computed and client-written** (`SEC-14`) — both are
> forgeable. Moving them server-side is deferred but required before anything of value depends on them.
> **Challenges are deliberately sunset** (ADR-012 era) — screens and lib references are removed, but a
> rules block, two indexes, and four orphan i18n keys survive (`DEBT-11`). An XP/levels layer is
> proposed, not built (`GAM-01`).

---

## 7. Moderation

**Layers, in order of when they fire:**

1. **Pre-publish keyword screen** — `CommunityService._checkContent` reads the blocked-keyword list
   from **public-read `settings/content_filter`**. It previously read the admin-only
   `admin_config/global`, so for every non-admin user *the filter silently failed open*. Admins
   write the list through `AdminService.updateAdminConfig`, which mirrors it to the public doc.
2. **Content-length caps** — enforced in `firestore.rules` on posts, comments, chat, signals.
3. **Image scanning** — `scanImage` runs Cloud Vision SafeSearch on upload and deletes unsafe
   objects. Best-effort until the Vision API is enabled.
4. **User reports** — `reports/{id}` (`status`, `targetType`, `reason`) → admin queue with dismiss,
   remove, and bulk actions, plus an audit entry.
5. **Admin enforcement** — ban/unban, force logout, content takedown, broadcasts.

> `BLK-05` (admin surface unreachable) is closed and deployed. `scanImage` still watches the wrong
> prefix (`BLK-07`). There is also **no per-uid UGC rate limiter** (spam, mass friend-requests, signal
> flooding are all unthrottled) — `SEC-06`'s callables re-verify identity and state server-side but add
> no throttling. A real sliding-window limiter needs UGC creates routed through a callable — scope it
> before community GA.

---

## 8. Cost discipline

Social feeds are the easiest way to melt a Firestore bill.

- Every feed and comment query is paginated with `.limit()` and a `startAfter` cursor
- Counts use `count()` / `pollCount()` — never `.snapshots().map((s) => s.size)`
- Post cards use `RepaintBoundary`; avatars go through `AppImage` / `CachedNetworkImageProvider`
- Hot counters are denormalized rather than re-counted
- Every listener is cancelled in `dispose`

Adding an unbounded `.snapshots()` to a social collection re-reads every matching document on every
change — see `CLAUDE.md` §9.

---

## 9. Roadmap

Group discovery depth, richer topics, and community-driven challenges are in
[`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §D;
[`roadmap/PHASE_15_ENGAGEMENT.md`](roadmap/PHASE_15_ENGAGEMENT.md) covers the engagement loop.
Community **is** in the consumer-only v1 scope (ADR-012) — unlike gym and coach, it ships in v1.0,
which makes `BLK-03` and `BLK-08` launch blockers rather than deferrable.
