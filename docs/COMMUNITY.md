# COMMUNITY.md — Social, Chat & Moderation

> The social graph, the feed, messaging, gamification, and how abuse is handled.
> Collection shapes: [`DATABASE.md`](DATABASE.md). Screens: [`FRONTEND.md`](FRONTEND.md) §5.
>
> **Owns:** `community_service.dart`, `chat_service.dart`, `follow_service.dart`,
> `friend_service.dart`, `community_group_service.dart`, `notification_service.dart`,
> `signal_service.dart`, `streak_squad_service.dart`, `achievement_service.dart`,
> `reputation_service.dart`, `moderation_appeal_service.dart`, moderation paths.

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

**Groups.** `community_groups/{groupId}` is a single unified entity for BOTH gym-affiliated groups
AND regular, user-created groups — they are not separate systems. `GroupKind` is `public` /
`private` / `gym`: a `gym`-kind group is auto-created by `AdminService.approveGymApplication` the
moment a gym application is approved (the gym's owner becomes the group's owner), is deliberately
excluded from general discovery (`isPublic: false`), and is reached only from the gym's own screen
— everything else about it (chat, moderation, membership) is identical machinery to a `public`/
`private` group created by any user via `CreateGroupScreen`. Every group has:

- A **members** subcollection + `member_count`, mirrored onto `users/{uid}.group_memberships[]`.
- A **`GroupJoinPolicy`**: `open` (self-join), `request` (queues a `join_requests/{uid}` doc for
  owner/admin approve/decline), or `invite` (redeemed via a server-validated `group_invites/{code}`
  callable, `functions/groups.js: redeemGroupInvite` — the code itself never lives on the
  client-readable group doc). All three are wired end to end, including the request queue UI
  (`group_members_screen.dart`'s "Pending requests" section) and code redemption.
- An **`announcementOnly`** toggle: only the owner/a group-level `admin` may post; everyone else
  still reads and reacts — enforced server-side by `canPostInGroup()`, not just hidden in the UI.
  `GroupMemberRole` is `owner` / `admin` / `moderator` / `member`, though only owner/admin are ever
  actually assigned by any service method today.
- **Moderation**: owner/group-admin kick/ban/mute/unmute (`group_members_screen.dart`), logged
  to an append-only `moderation/{autoId}` subcollection the target can read their own entries from,
  plus a `moderation_appeals` path to contest an action (§7).
- Its own **chat** (see §3) and, for public groups, an **activity-ranked discovery carousel**:
  `activity_score` is computed every 15 minutes by `computeGroupActivityScores`
  (`functions/groups.js` — messages×1 + posts×3 + comments×2 + new-members×5, decayed with a
  6-hour half-life over a 24h window), never client-computed.

A post carries an optional top-level `groupId` (null = global feed); `getGroupFeedStream` serves
the scoped feed. Design origin: [`roadmap/COMMUNITY_GROUPS.md`](roadmap/COMMUNITY_GROUPS.md) (the
original, simpler location-based-only design — superseded in practice by the unified model above;
kept for historical context, not as the current contract).

> `BLK-08` — the `posts` update rule was a denylist (only `authorId`/`content`/`imageUrls`/`tags`
> blocked), so any authenticated user could write `groupId` or any other field. Now an allowlist:
> non-owners may only touch engagement bookkeeping (`likesCount`/`likedUserIds`/`recentLikers`/
> `reactions`/`commentsCount`), with the two scalar counters constrained to ±1 per write. The identical
> bug also existed on `posts/{id}/comments` and `gyms/{id}/posts` (that's where the announcement flag
> actually lives) — fixed the same way. Deployed 2026-08-01; see `PROJECT_STATE.md`.

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
> `friends`/`friend_requests` open-creates (`S5`) are closed in code+rules, deployed (`SEC-06`).

---

## 3. Chat

`chats/{id}` (participants, `lastMessage`, `unreadCounts`, type, `typingUsers`, `pinnedMessageId`,
optional `groupId`) with `chats/{id}/messages/{id}`. One collection, one `ChatService`, three
`ChatType`s — **not** a DM-only collection:

- **`private`** — a genuine 1:1 direct message. `ChatService.createOrGetPrivateChat` reuses an
  existing 2-participant chat rather than duplicating it. This is the app's only DM surface — there
  is no separate "direct message" data model or service.
- **`group`** — either an ad-hoc multi-person chat (`ChatService.createGroupChat`, participants
  array only) or the paired chat every `community_groups` doc gets on creation (`chatId == groupId`;
  §1). For a group-backed chat, `firestore.rules`' `canAccessGroupChat()`/`canPostInGroup()` grant
  the **whole group's membership** read/post access keyed off `groupId`, not the `participants`
  array (which only ever holds the group's owner for these).
- **`gym`** — the paired chat for a `kind:'gym'` community group. Was rendered by
  `chat_list_screen.dart` with zero real producers before Faz 2 §2.3; now real. (A `system` type was
  removed — it was rendered but never produced by any writer.)

**Message model v2** (Faz 2 §2.1, `message_model.dart`) is genuinely WhatsApp-level, not just
text + image: attachments (image, with room for other kinds), **reply** (denormalized quote
snapshot), **forward** (with a visible hop count), per-message **reactions**, **edit** (sender-only,
15-minute window, rules-enforced), **delete** — "for everyone" (sender-only, same window, clears
body/attachments) or "for me" (any participant, hides only for them) — per-recipient **delivered/
read receipts**, **typing indicators**, **@mentions**, a single **pinned message** per chat, and a
personal **star/bookmark** (`users/{uid}/starred_messages`). Cursor-paginated history
(`getMessagesPage`), jump-to-date (`getMessagesAround`), a bounded in-chat search (300-message
client-side scan, no text-search backend exists), and a dedicated media gallery
(`getChatMediaPage`) are all real, not aspirational. None of this is end-to-end encrypted —
messages are deliberately server-readable so reporting and moderator takedown (below) can work.

In a group-backed chat, a group owner/admin (or site admin) can additionally take down another
member's message (`ChatService.deleteMessageAsModerator` — flips `is_deleted` only, never rewrites
`body`) without needing the sender-only edit/delete path. Per-user chat-list prefs (pin/archive/
mute/delete-for-me, `chat_prefs`, Faz 2 §2.4) are independent of the shared chat doc.

Chat images use a **participants-only scoped path** with unguessable random filenames, plus
client-side EXIF/GPS stripping on upload.

**Chat push works** — `onChatMessageCreated` is wired correctly, and (Faz 2 §2.4) now sources a
group-backed chat's recipients from `community_groups/{id}/members` rather than the `participants`
array, so real group members are actually counted/notified, not just the owner. It was the only
push path that worked at all until `BLK-03` (fan-out fix, §4) deployed 2026-08-01 — every
notification type now has a server-authored writer, though physical push delivery is unverified in
this environment (no device).

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
> is denied unconditionally by rule. Deployed 2026-08-01 — see `PROJECT_STATE.md` for current status.
> Physical-device push delivery cannot be verified in this environment (no iOS/Android hardware, and
> the iOS Simulator cannot receive real APNs).

---

## 5. Ephemeral & group accountability

- **Signals** — `signals/{id}`, short-lived broadcasts with a TTL via `expiresAt` (`gymHelp` /
  `mealShare` / `general`). Content-capped. Needs a Firestore TTL policy so they actually expire and
  stop costing storage. Currently visible to the whole community — no friends-only/gym-only scope
  yet.
- **Streak Squads** — `squads/{id}` (`StreakSquadService`/`StreakSquadModel`), a small group joined
  via a 6-char invite code. There is **no shared/pooled streak** — each member keeps their own
  individual streak (`users/{uid}.onboarding_data.streak`); the squad's entire job is showing
  members' streaks side by side, ranked, so someone noticing a friend's column flatten is the
  mechanism, not a group streak that resets for everyone. No squad-level chat exists — accountability
  is visibility only.

---

## 6. Gamification

| System | Mechanic |
|---|---|
| **Streaks** | Daily streak with freeze consumption; milestone banners. Unit-tested |
| **Achievements** | 15 badges, `kAchievementCatalog` — the original 11 (first meal/photo/post/cook, streak 7/30/100, tier active/contributor/expert/legend) plus 4 added in Faz 5 §5.3 (`level50`, `groupTop3`, `groupStreak4`, `gymRegular`). `earn(uid, key)` is idempotent; `checkAndGrant` fires from every success path; `backfillForUser` for existing accounts. Profile grid with a reduced-motion-aware unlock animation |
| **Reputation** | A tier (`newcomer`/`active`/`contributor`/`expert`/`legend`) derived from XP-level bands (`ReputationService._tierFromLevel`) |
| **XP & levels** | Faz 5 §5.1 — a server-owned points/caps ledger (`functions/progress.js`'s `awardXp`), idempotent per event, increasing-interval level curve |
| **Leaderboards** | All-time streak (global + friends, `LeaderboardService`) **and** a separate weekly-reset, XP-based ranking (community-wide and per-gym, `community_weekly_xp/{weekKey}`) — plus each group's own weekly contribution leaderboard (§1) |
| **Weekly recap** | AI-generated week score, wins, challenges, trend |

> ⚠️ **Superseded finding, kept for history:** `streak` and `reputation`/`reputation_score` used to be
> client-computed and client-written (`SEC-14`) and forgeable. **Both are now closed.** Reputation is
> derived server-side from the XP ledger (`firestore.rules` denies client writes to
> `xp`/`level`/`reputation_score` unconditionally). The daily login streak's increment/reset/freeze
> logic now lives exclusively in the `processStreakLogin` callable (`functions/progress.js`,
> `firestore_service.dart:handleUserLogin` just calls it and reads back the result) — `update`s to
> `onboarding_data.streak`/`streak_freeze_count` are server-write-only by rule; the client only ever
> writes the seed value (`streak: 1`) once, at brand-new-account **creation**, which `create` rules
> don't gate the same way `update` does and isn't a meaningful forgery vector.
> **Challenges are deliberately sunset** (ADR-012 era) — screens and lib references are removed, but a
> rules block, two indexes, and four orphan i18n keys survive (`DEBT-11`).

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
4. **Group-level moderation** (Faz 2 §2.6) — a group owner/group-admin (or site admin) can
   kick/ban/mute/unmute a member (`CommunityGroupService`, `group_members_screen.dart`, reason
   prompt + duration chips on mute) and take down another member's message in that group's chat
   without editing it (`ChatService.deleteMessageAsModerator`). Every action is logged to an
   append-only `community_groups/{id}/moderation/{autoId}` entry the target can read their own copy
   of. A member can contest one via `moderation_appeals/{id}` (doc id == the moderation action's own
   id, one appeal per action) — filed from `ModerationAppealScreen`, resolved by an admin
   (`AdminService.resolveModerationAppeal`); upholding an appeal auto-reverses the mute/ban.
5. **User reports** — `reports/{id}` (`status`, `targetType`, `reason`) → admin queue with dismiss,
   remove, and bulk actions, plus an audit entry.
6. **Platform-level admin enforcement** — `AdminService.banUser`/`unbanUser` (writes
   `users/{uid}.is_banned` + an `admin/status/{uid}/flags` record, audit-logged), force logout,
   content takedown, broadcasts.

> `BLK-05` (admin surface unreachable) is closed and deployed — the report queue, ban/unban, and
> appeal resolution are all reachable through it today (though no real admin session has exercised
> them against live traffic yet). `scanImage`'s prefix mismatch (`BLK-07`) is **also closed** —
> `storage.rules`'s guarded path now matches the real `gyms/{gymId}/logo.jpg` upload path, so the
> scanner and the rule watch the same prefix.
>
> Reports, group moderation actions, and moderation appeals each now have their own per-uid
> sliding-window rate limit (`functions/rate_limit.js`, `rate_limits/{uid}`, fully server-only) —
> but this is narrower than a general UGC limiter: ordinary post/comment/signal creation and
> friend-requests are still unthrottled. A broad UGC limiter would need those creates routed through
> a callable too — scope it before community GA.

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
