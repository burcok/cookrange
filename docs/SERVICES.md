# SERVICES.md — Services & Cloud Functions

> All business logic lives here. UI never calls Firebase directly — it goes through a service.
> 75 Dart singletons in `lib/core/services/**` + **22 deployed** Cloud Functions in `functions/`.
> **Cloud Function *contracts* (request/response, auth, error codes) are owned by
> [`API.md`](API.md)** — this file covers what each service/function *does*.
> **Security-authoritative state lives server-side**: premium in `entitlements/{uid}`, AI credits in
> `ai_credits/{uid}` — both owner-**read** + server-**write-only**; the client never grants premium,
> consumes credits, applies referrals, or deletes accounts directly.
> Pattern: `static final _instance = Foo._internal(); factory Foo() => _instance;`
> **Code is truth — keep this in sync when you add/change a service.**

---

## Auth & Identity
- **AuthService** `auth_service.dart` — Auth lifecycle: email/password, Google, Apple; email
  verification; password reset; session tracking + concurrent-login detection. Holds the app
  `navigatorKey`. In-memory user cache; `invalidateUserCache()` clears it so the next read refetches
  (used to stop a stale cache flag from resurrecting old state — e.g. the meal-plan gate). Session-
  static `mealPlanGatePassed` flag lets "Skip" clear the meal-plan generation gate permanently
  (`RouteGuard` no longer re-loops back into generation). **GDPR account deletion
  is server-authoritative** — `deleteAccount` invokes the `deleteUserAccount` callable (recursive
  subtree + Storage + Auth erasure) instead of client-side deletes. Email no longer sent to analytics.
- **FirestoreService** `firestore_service.dart` — Central Firestore I/O: user CRUD, activity
  logging, role assignment (`addUserRole`), streak, `getUserStream`. `getPrivateNutritionData(uid)`
  migrates + reads PII subcollection; `savePrivateNutritionData(uid, data)` writes it.
  `syncDeviceContext(uid)` writes the full device/IP/app-version context on every app open/resume
  (not just `is_online`) — called from `AppLifecycleService._setOnline`. `verifyAndRepairUserData`
  now backfills `email`/`displayName`/`photoURL` from Auth when missing, so the core profile is
  consistent regardless of sign-up method.
- **AdminStatusService** `admin_status_service.dart` — Real-time ban/admin status; `onBanStatusChanged`
  stream feeds `RouteGuard`; reads `admin_config` for maintenance/min-version.

## AI & Generation (`services/ai/` + AI services)
- **AIService** `ai/ai_service.dart` — LLM engine (OpenRouter). **Proxy-mandatory in release** (all
  calls go through the `aiProxy` Cloud Function); the bundled `OPENROUTER_API_KEY` is **debug-only**
  (release builds never ship/use a client key). 3-retry policy. Typed exceptions:
  `AIRetryableException`, `AIFatalException`, `AIQuotaExceededException` (402), `AIJsonParseException`.
  `generateCompletion`, `generateChatResponse`, `generateJson`. `isConfigured`, `hasProxy`,
  `setProxyUrl()` (from Remote/App Config). Every call is tagged with a `type`
  (`meal_plan`/`recipe`/`insight`/`weekly_recap`/`food_photo`/`chat`) that flows to `aiProxy` for
  per-request cost logging.
- **AiChatService** `ai/ai_chat_service.dart` — Builds profile-aware system prompt for nutrition chat.
- **AiChatHistoryService** `ai/ai_chat_history_service.dart` — In-memory conversation state (voice↔text).
- **PromptService** `ai/prompt_service.dart` — Prompt template library (recipe, weekly plan, ingredient
  validation, plan alternates) + locale instructions. **Prompt-injection guard**: user-supplied text
  is sanitized/fenced before insertion so it can't override system instructions.
  **180-dish prompt ceiling (Faz 3 §3.6)**: `generateWeeklyMealPlanPrompt` caps the candidate pool at
  `maxDishesPerPrompt` (documented at `docs/AI_SYSTEM.md`'s Prompt Strategy section since Faz 3
  planning, but unenforced until now — the catalog was 75 dishes, so it never bound). Enforced once,
  here, rather than per-caller, since both `WeeklyMealPlanService` and `MealPlanTemplateService.
  generateDraftFromAI` funnel through this method. Over the ceiling, dishes are taken round-robin by
  `meal_type` rather than positionally truncated — `DishService.getAllDishes()` has no `orderBy`, so a
  blind `.take(180)` could silently zero out whichever meal type sorts last (e.g. snacks), which is
  the exact failure mode the snack-pool fix elsewhere in this task guards against. Tested at
  `test/prompt_service_test.dart` (under/at/over the ceiling, and the anti-starvation case).
- **RecipeGenerationService** `recipe_generation_service.dart` — Structured recipe gen via AI+Prompt.
- **FoodAnalysisService** `food_analysis_service.dart` — Estimates nutrition from a food description.
- **AiInsightService** `ai_insight_service.dart` — Daily accountability insight + 30/60/90-day fitness
  twin projection + risk detection. Caches daily insight in SharedPrefs (per date+locale); saves
  projections to `users/{uid}/ai_twin_projections`. `getLatestProjectionStream` is **locale-agnostic**
  (returns newest doc by `generatedAt` DESC regardless of language). Streams latest + history.
- **AiCreditService** `ai_credit_service.dart` — **Read-only** view over the server-only
  `ai_credits/{uid}` ledger (owner-read, server-write-only). Quota enforcement + consumption now live
  entirely in the `aiProxy`/`entitlements` Cloud Functions — the client no longer writes credits.
  Exposes `getCreditsStream` (live `used_today`/`reset_at`/`bonus`); legacy client
  consume/rollback/add paths removed. Daily limits: free 2/day, premium 20/day, IAP bonus never reset.
- **EngagementCreditService** `engagement_credit_service.dart` — Faz 5 §5.2. **Read-only**, same
  posture as `AiCreditService` immediately above: all received-engagement credit logic (distinct-
  account thresholds, anti-abuse weighting, the premium 2× multiplier, shadow-restriction) is
  server-computed (`functions/engagement_credit.js`) and lands in the SAME `ai_credits/{uid}.bonus`
  pool `AiCreditService` already surfaces — nothing new to display there. The one piece of state this
  service DOES expose is `watchRestrictionState(uid)`, a live stream of `credit_restrictions/{uid}`
  (`CreditRestrictionModel`), backing `CreditRestrictionScreen`'s "good standing" vs "restricted +
  appeal" split.

## Nutrition & Food
- **DishService** `dish_service.dart` — `dishes/` CRUD + seed; streams; admin edit/delete.
- **FoodLogService** `food_log_service.dart` — Logs meals (dish/recipe/scanned/quick/barcode),
  daily totals, today stream, date-range history. Auto-upserts `recent_foods`. **Faz 5 §5.1**: every
  log path now reports a `meal_logged` XP event (`logRecipe` additionally reports `recipe_cooked` —
  same doc, two XP kinds, same reasoning as its existing dual achievement flags).
- **RecentFoodService** `recent_food_service.dart` — Last ~20 foods (Hive), quick-add carousel.
- **BarcodeLookupService** `barcode_lookup_service.dart` — Barcode → product nutrition (Open Food Facts).
- **WeeklyMealPlanService** `weekly_meal_plan_service.dart` — AI weekly plan; hash-based cache
  invalidation (profile change → regenerate); **filters allergen-unsafe dishes via `AllergenSafety`
  before sending candidates to the AI** (defense-in-depth on top of allergy validation);
  `getMealPlanHistory`, `restorePlan`, auto-archive to `meal_plan_history/{key}`. Writes
  `users/{uid}/meal_plans/current`. **`swapMeal`** (Faz 3 §3.4): recomputes the swapped day's + the
  whole plan's `total_calories`/`macros`/`fiber` via `PlanNutritionCalculator` (below) instead of a
  hand-rolled inline loop — also fixes an N+1 (`getDishById` once per meal slot) by fetching the dish
  catalog once via `getAllDishes()` and building a `{id: DishModel}` lookup up front.
  **`archiveToHistory(userId, plan)`** (Faz 3 §3.5): extracted from `_generateAndSaveMealPlan`'s old
  inline step 6 (same key derivation + write, now shared instead of duplicated) — snapshots `plan`
  into `meal_plan_history/{weekStartKey}`. **`computeCurrentProfileHash(user)`**: public wrapper
  around the private `_generateProfileHash`, so a caller outside this file can stamp a plan with the
  member's real current hash. **`adoptTemplate({user, templateDays})`** (Faz 3 §3.5 accept flow):
  archives whatever plan was previously current via `archiveToHistory` FIRST, then converts a
  template's `List<TemplateDay>` into a live plan — nutrition totals via `PlanNutritionCalculator`
  from the full-fidelity `List<MealEntry>` (never lossy), the legacy `Map<String,String>` `meals` shape
  via the new `TemplatePlanAdapter` util (`collapseMealsToLegacyMap`/`weekdayName` — pure,
  Firebase-independent, unit-tested: drops custom-food entries and resolves same-day duplicate
  meal-type slots last-wins, since `DayMealPlan` was never migrated off that shape). Stamps
  `generation_prompt_hash` with `computeCurrentProfileHash(user)` — without this, the member's very
  next `getWeeklyMealPlan` call would see a hash mismatch (an accepted template was never AI-hashed)
  and silently regenerate an unrelated AI plan over what they just accepted. 7-day `expiresAt`, matching
  every other plan in this schema. `PlanOfferService.acceptOffer` is the only caller.
- **MealPlanCalendarService** `meal_plan_calendar_service.dart` — Export plan as `.ics`.
- **NutritionAnalyticsService** `nutrition_analytics_service.dart` — Weekly summary, macro %, trends.
- **StorageService** `storage_service.dart` — Local Hive: recipes, plans, shopping, hydration, weight,
  settings (boxes: user/recipes/meal_plans/settings/shopping/hydration/weight). **Boxes are AES-256
  encrypted** — the cipher key is generated once and stored in `flutter_secure_storage` (Keychain/
  Keystore). One-time migration transparently re-opens and re-writes any pre-existing plaintext boxes
  under encryption.

## Social & Community
- **CommunityService** `community_service.dart` — Posts CRUD, cursor pagination (`fetchPostsPage`),
  comments, reactions, topic filter (arrayContains tags), weekly highlights
  (`getTopPostThisWeek`/`getTopStreakUserThisWeek`), mention fan-out, content moderation
  (`_checkContent` blocked-keyword pre-screen — reads the list from **public-read
  `settings/content_filter`**, mirrored there by admins; previously read the admin-only
  `admin_config/global` doc, so the filter was dead for normal users), `reportContent`. **Faz 5
  §5.1**: `createPost`/`addComment`/`toggleReaction` (add only, never on remove) each report their
  own XP event (`post_created`/`comment_created`/`reaction_given`) via `AchievementService`.
  **Faz 2 §2.6**: `_checkContent` is now **fail-closed** on a refresh error — it used to
  catch-and-clear to an empty list (silent `catch {}`, R4 violation), letting every post/comment
  through unchecked on any transient read failure. Now: logs the error, and blocks outright
  (`content_check_unavailable`) only when this service instance has NEVER once successfully loaded a
  keyword list; if a prior fetch already succeeded, a later refresh failure keeps serving that
  last-known-good cached list instead (stale-but-real data, not a security regression — the fail-open
  bug was specifically "treat as if no keywords exist at all").
  `getGroupFeedStream(groupId)` + `createPost(groupId:)` are this service's only group-related
  surface (the group-scoped POST feed) — group CRUD/membership/moderation/discovery itself is
  **CommunityGroupService**, below. **Faz 2 §2.5**: the old `getGroups()` stub (`const []`, always
  empty) is removed entirely, along with the dead carousel in `community_screen.dart` it backed —
  see `ActiveGroupsSection` below.
- **CommunityGroupService** `community_group_service.dart` — The canonical "unified group" surface
  (Faz 2 §2.3 — P1 create/search/join/leave/streams/`touchActivity` unchanged). New: `kind`
  (public/private/gym), `joinPolicy` (open/request/invite), `announcementOnly`, `rulesText` on
  `createGroup`/`updateGroupSettings`; `setMemberRole` (owner/site-admin only — see its doc comment
  for why a group-level `admin` doesn't also get this); `kickMember`/`banMember`/`unbanMember`/
  `muteMember`/`unmuteMember` (each also appends an immutable `moderation/{autoId}` log entry);
  `requestToJoin`/`withdrawJoinRequest`/`getPendingJoinRequestsStream`/`approveJoinRequest`/
  `declineJoinRequest` (`join_requests/{uid}`); `generateInviteCode`/`disableInvite`/`getInviteCode`
  (writes `secrets/invite` + the top-level `group_invites/{code}` reverse-lookup doc — the code
  itself never touches the public group doc, see `DATABASE.md`); `redeemInviteCode` (calls the
  `redeemGroupInvite` callable — code validation/redemption is server-only, there's no client-
  readable path to check a code any other way); `pinGroupMessage`/`unpinGroupMessage` (the group's
  own `pinned_message_id`, distinct from a plain chat's camelCase `pinnedMessageId`). **Deliberately
  has no `sendMessage`/`getMessages*` of its own** — every group gets a paired `chats/{chat_id}` doc
  (`createGroup`'s `chatId == id`), so a group's "akış + sohbet" reuses `ChatService` completely
  unchanged, with `group.chatId` as the `chatId` argument; firestore.rules'
  `canAccessGroupChat()`/`canPostInGroup()` are what actually enforce group membership +
  `announcement_only` on that shared path (see `DATABASE.md`'s `chats/{id}` row). `AdminService.
  approveGymApplication` auto-creates a `kind:'gym'` group (+ its paired chat) with the gym owner as
  `owner` — same id as the gym, one batch. **Faz 2 §2.5**: `getTopActiveGroups`/
  `getActiveGroupsInCity` — read-only, `activity_score`-sorted discovery for
  `ActiveGroupsSection` (`community_screen.dart`); never compute or write the score themselves (see
  `computeGroupActivityScores` below). `seedOfficialGroups` — thin wrapper around the admin-only
  callable of the same name. **Faz 2 §2.6**: `kickMember`/`banMember`/`muteMember`/`unmuteMember`/
  `unbanMember` are now wired into a real UI (`group_members_screen.dart` — reason input on every
  action, duration chips on mute) rather than being unreached service methods; the write paths
  themselves are unchanged. The same screen's new "Pending requests" section wires
  `getPendingJoinRequestsStream`/`approveJoinRequest`/`declineJoinRequest` for the first time too —
  all three existed since Faz 2 §2.3, rules-tested, with no caller anywhere in the app until now;
  shown only when the group's `join_policy == 'request'`, gated on the exact same owner/group-admin/
  site-admin check as kick/ban/mute rather than a new one. Completes that policy end-to-end alongside
  `GroupDetailScreen`'s (separately fixed) join_policy-aware Join button — request → owner/admin
  queue → approve/decline → real membership. New: `getMyModerationHistoryStream(uid)` — a `collectionGroup('moderation')`
  scan across EVERY group at once (unlike `getModerationLogStream`, which is one group's admin view),
  backing the appeal-filing screen; no rules change needed, since the existing `target_uid ==
  request.auth.uid` "transparency" read rule already applies per-document to a collection-group query.
  `isOwnerOrGroupAdmin(groupId, uid)` — a cheap 2-doc-get role check (vs. pulling the whole member
  list) backing `chat_detail_screen.dart`'s moderator-delete gate. **Faz 5 §5.3**:
  `getWeeklyContributionLeaderboardStream(groupId)` — reads the fully denormalized
  `weekly_leaderboard/{weekKey}` doc (ranked `entries[]` array, already resolved names/photos) written
  by `computeGroupContributionLeaderboards`; a single-doc read, no per-member joins on the client at
  all. Backs `GroupLeaderboardScreen` (`lib/screens/community/groups/group_leaderboard_screen.dart`),
  reached from a new trophy-icon action on `GroupDetailScreen`'s app bar (same additive pattern as the
  existing member-list action beside it). **Faz 5 §5.4**: `exportMembersCsv(groupId)` — a group's
  member list as CSV (uid/display_name/role/joined_at/status), mirroring `GymAnalyticsService.
  exportCsv`'s exact shape/discipline (capped read, logged if hit). The one genuinely new capability
  found for the plan's undefined "premium grup admin araçları" scope — gated behind
  `Entitlements.exportData` in the caller (`GroupMembersScreen._exportMembers`), never touching the
  existing, unconditionally-free `kickMember`/`banMember`/`muteMember`/`unmuteMember` above.
- **ChatService** `chat_service.dart` — Chats + **message model v2** (Faz 2 §2.1): `sendMessage`
  (body/attachments/replyTo/forwardedFrom/mentions, `server_timestamp` via `FieldValue
  .serverTimestamp()` — a deprecated `timestamp` mirror is also written so the existing message
  stream's `orderBy('timestamp')` keeps surfacing old and new docs alike), `addReaction`/
  `removeReaction`, `editMessage` (sender-only, firestore.rules enforces the 15-min window),
  `deleteMessageForEveryone`/`deleteMessageForMe`. **Faz 2 §2.6**: `deleteMessageAsModerator` — a
  group owner/admin/site-admin takes down ANOTHER member's message; deliberately narrower than
  `deleteMessageForEveryone` (only flips `is_deleted`/`deleted_for`, never clears `body` — the
  original stays in Firestore for audit/appeal review, simply never rendered once `is_deleted` is
  true, per `MessageModel.isDeletedFor`), no 15-minute window, enforced by a new
  `canModeratorDeleteMessage()` rule wired into the SAME `messages/{messageId}` update rule as
  `canEditOwnMessage()`/`canUpdateMessageEngagement()`. `chat_detail_screen.dart` resolves moderator
  status once per screen-open (`CommunityGroupService.isOwnerOrGroupAdmin`, or the `admin` custom
  claim) rather than per long-press, so the context menu stays synchronous. `markChatAsRead` now only zeroes the caller's OWN
  `unreadCounts` key and stamps `read_by`/`delivered_to` on a capped (400) recent-message window —
  the old unbounded per-message batch query (crashed past 500 unread, Faz 0 §0.5) is gone;
  **increments are exclusively server-side** now (`onChatMessageCreated`). Typing status, ad-hoc
  group chat creation (`createGroupChat` — a plain multi-party chat with no group behind it, distinct
  from a `community_groups`-paired one) unchanged. `ChatType.system` was removed (Faz 2 §2.3 —
  rendered by `chat_list_screen.dart`'s old `_buildSystemChatCard`, never produced by any writer);
  `ChatType.gym` is now real (`CommunityGroupService`, above). New `groupId` field (see
  `DATABASE.md`'s `chats/{id}` row).
  **Faz 2 §2.2 additions** (backing the rebuilt `chat_detail_screen.dart`): `getMessagesPage`
  (cursor pagination — mirrors `CommunityService.fetchPostsPage`'s shape, resolves a plain message-id
  cursor into a `DocumentSnapshot` internally so callers never touch `cloud_firestore` types),
  `getChatMediaPage` (image-only, the new `messages(type,timestamp)` composite index),
  `getMessagesAround` (jump-to-date, a same-field range+orderBy needing no new index),
  `fetchMessagesForSearch` (bounded 300-message one-shot backing client-side in-chat search — no
  text-search backend in this stack), `getMessageOnce` (resolve one message outside the loaded
  window — pinned banner, reply-tap-to-scroll), `pinMessage`/`unpinMessage` (writes
  `chats/{id}.pinnedMessageId/pinnedBy/pinnedAt` — any participant, no rules change needed, see
  `DATABASE.md`), `starMessage`/`unstarMessage`/`streamStarredMessageIds` (new
  `users/{uid}/starred_messages/{messageId}` collection, doc id = messageId), `reportMessage`/
  `reportUser` (canonical `reports` shape — `reportUser` also relocates the report-writing that used
  to live inline in `chat_detail_screen.dart`, which imported `cloud_firestore` directly; a screen
  importing Firebase violates `CLAUDE.md`'s "UI never touches Firebase" rule), `forwardMessageTo`
  (composes `sendMessage` with `forwarded_from` provenance, `hops`-incremented),
  `getUserDisplayNames` (bounded `whereIn` ≤10, mirrors `getUserChatsWithStatus`'s existing cap —
  backs group sender labels, @mention candidates, and typing-indicator names), `watchUser` (wraps
  `FirestoreService.getUserDocStream` → `UserModel`, so the screen's private-chat app-bar title never
  needs a `DocumentSnapshot` type either).
  **Faz 2 §2.4 additions** (backing the rebuilt `chat_list_screen.dart`): `getChatPrefsStream` +
  `pinChat`/`unpinChat`/`archiveChat`/`unarchiveChat`/`muteChat`/`unmuteChat`/`deleteChatForMe` —
  per-user, per-chat list-view prefs at `users/{uid}/private/chat_prefs` (mirrors
  `FirestoreService`'s `_presencePrefsRef`/`setGymTrackingEnabled` shape: a nested-map field + a
  `set(merge:true)`/`FieldValue.delete()` pair to add/remove one key without disturbing siblings).
  Deliberately NOT on the shared `chats/{id}` doc — see `DATABASE.md`'s `chat_prefs` row. Filtering/
  sorting the list itself (segment, unread-only, search, archive/delete visibility, pinned-first
  ordering) is a separate, Firebase-free, unit-tested pure function,
  `lib/core/utils/chat_list_filter.dart`'s `ChatListFilter.apply` — not part of this service.
- **FollowService** `follow_service.dart` — Following/followers counts, isFollowing stream (reads
  stay client-direct). **Write is server-authoritative** (`BLK-03`/`SEC-06`) — `follow`/`unfollow` call
  the `followUser`/`unfollowUser` callables, which write both edge sides and the follow notification
  atomically; the client no longer batch-writes them or supplies actor info.
- **FriendService** `friend_service.dart` — Search users, friendship status (read, client-side
  pre-check for UX only). **Mutation is server-authoritative** (`BLK-03`/`SEC-06`) — send/accept/
  reject/cancel call `sendFriendRequest`/`respondToFriendRequest`/`cancelFriendRequest`, which
  re-verify status server-side, write both sides atomically, and send the notification with the actor
  derived from the caller's auth identity. `removeFriend` (unfriend) stays client-direct — it only
  ever deletes the caller's own side, already safe under the owner-scoped delete rule.
- **FavoriteService** `favorite_service.dart` — `users/{uid}/favorites`; toggle, isFavorite stream.
- **ReferralService** `referral_service.dart` — 6-char codes (`referrals/{code}`). **Apply is
  server-authoritative** — calls the `applyReferral` callable (server-validated reward + commission
  ledger); the client no longer batch-writes rewards/premium. Reward: 7-day premium trial both sides.
  **Faz 6 §6.1**: `createGymInviteCode`/`gymInviteCodesStream`/`markInviteCodePrinted` — a gym-owned
  variant of the SAME collection (`type: 'gym'`, `gym_id`, optional `campaign`/`location_note`), for
  poster/QR user acquisition rather than a 1:1 personal share. Generation stays **client-direct** (no
  new callable): firestore.rules re-verifies the caller is the named `gym_id`'s real owner via a
  server-side `get()`, the same pattern every other owner-scoped gym write in this app already uses —
  nothing about minting/labeling a code needs server authority the way redeeming one does. Default
  `max_uses: 5000` (vs. 10 for personal/coach-vanity codes) — see `gymDefaultMaxUses`'s doc comment for
  the Firestore document-size reasoning.
  **Faz 6 §6.3/§6.4** — pre-signup redemption is now wired end to end, closing that gap: `previewCode`
  calls the new `previewReferralCode` callable (read-only, no auth — onboarding has no Firebase Auth
  session yet, unlike `applyCode`/`applyReferral`) to show "verified, {gym}" on the onboarding referral
  step before an account exists; response shape is identical for not-found and inactive/exhausted, so
  it can't be used to enumerate codes. `savePendingCode`/`loadPendingCode`/`clearPendingCode` stage the
  code on-device (`SharedPreferences`, 7-day TTL) so it survives an app kill mid-onboarding — in-memory
  `OnboardingProvider` state does not. Actual redemption still only ever happens via `applyCode` →
  `applyReferral`, called once from `OnboardingCompletion.finalizeAndRoute` (the first point a real,
  authenticated uid exists) — never during onboarding itself, and never blocking signup if the code
  turns out invalid/expired/already-used by then.
  **Faz 6 §6.5/§6.6** — `applyReferral` now DOES special-case `type=='gym'`: instead of the personal
  7-day-trial + ₺5-commission grant, it writes a `gym_attributions/{uid}` doc, bumps
  `gyms/{gym_id}.attributed_member_count`, and notifies the owner — no trial premium either side (see
  `docs/DATABASE.md`'s `referrals/{code}` row for why). `applyCode` now returns a `ReferralApplyResult`
  (`error`/`isGymCode`/`gymName`) instead of a bare `String?`, so callers can tell a gym-attribution
  outcome apart from a personal-reward one and show accurate success copy — both call sites
  (`settings_screen.dart`'s "I have a code" sheet, `OnboardingCompletion.finalizeAndRoute`) updated
  accordingly; `applyCode`'s new optional `source` param (`'deep_link'\|'manual_entry'\|'in_app'`,
  default `'in_app'`) feeds `gym_attributions/{uid}.source` — see that param's own doc comment for
  which call sites can state it precisely today and which can't yet. Three new read-only methods back
  the user-facing transparency side: `getMyAttribution()` (reads the caller's own `gym_attributions/
  {uid}`), `isAttributionHidden()`/`setAttributionHidden(bool)` (the display-only "disconnect"
  preference at `users/{uid}/private/attribution_prefs` — never touches the attribution doc itself,
  which stays immutable so the gym's earned commission survives a user hiding the banner).
- **AchievementService** `achievement_service.dart` — Badge grants (`users/{uid}/achievements/*`) via
  the server-authoritative `syncProgress`/`backfillProgress` callables (`functions/progress.js`);
  `checkAndGrant`'s event-flag params (`justLoggedMeal` etc.) are the client's "this momentary thing
  just happened" report. **Faz 5 §5.1**: `checkAndGrant` also takes `xpEvents` (a new `XpEvent` DTO
  defined in this file — `mealLogged`/`recipeCooked`/`postCreated`/`commentCreated`/`reactionGiven`
  factories), forwarded in the SAME `syncProgress` call as a parallel `xpEvents` array on the request —
  one callable, two concerns, never a second entry point. The server independently verifies each
  referenced doc before awarding any XP (see `progress.js`); a failed verification is silently skipped,
  never surfaced as a client error.
- **ReputationService** `reputation_service.dart` — Reputation badges/score from activity. **Faz 5
  §5.1 migration**: the tier is now derived from the user's XP LEVEL (`XpLevelCurve`,
  `lib/core/utils/xp_level_curve.dart`) in level bands, not the old `streak×2 + postCount×5` formula
  (deleted server-side too) — `ReputationData` gained a `level` field but kept `score`/`tier`'s
  existing shape, so every pre-existing display consumer (`profile_screen.dart`'s tier chip) needed
  zero code changes.
- **SignalService** `signal_service.dart` — Ephemeral broadcasts (TTL via expiresAt).
- **StreakSquadService** `streak_squad_service.dart` — Squads (`squads/`), invite codes, leaderboard.
- **ModerationAppealService** `moderation_appeal_service.dart` — Faz 2 §2.6 ("itiraz yolu"). Mirrors
  `PrivacyRequestService` deliberately (same DSAR-style pattern, `docs/COMPLIANCE.md` §7): `file(...)`
  creates a `moderation_appeals/{id}` doc whose id IS the source `community_groups/{groupId}/
  moderation/{autoId}` entry's own id (at most one appeal per action — firestore.rules relies on this
  for its `get()` cross-check); `watchAppeal(id)` streams the live status for one specific action,
  backing the inline "Appeal" / "Pending review" / "Upheld" / "Denied" state on the moderation-history
  screen. No callable — client-direct create, admin-only resolve, exactly like DSAR. **Faz 5 §5.2**:
  `fileCreditRestrictionAppeal(creditModerationEntryId, message)` — a second appeal kind into the SAME
  collection/lifecycle, `action: 'credit_restriction'`, doc id == the source
  `users/{callerUid}/credit_moderation/{autoId}` entry's own id instead of a group action's. Backs
  `CreditRestrictionScreen` (`lib/screens/profile/credit_restriction_screen.dart`), the account-scoped
  sibling of `ModerationAppealScreen`.
- **NotificationService** `notification_service.dart` — **Structured-only** in-app notifications
  (type, actorUid/Name/PhotoUrl, relatedId, metadata — never pre-rendered text) at the canonical
  `notifications/{uid}/items/{docId}` path. Pagination, mark-read, delete/clear stay client-direct
  (owner-scoped, already safe). **Creation is server-authoritative** (`BLK-03`) — `sendNotification`/
  `deleteNotificationByRelatedId` call the `createNotification`/`retractNotification` callables; the
  actor is always derived from the caller's own auth identity, never the client payload.
- **NotificationPreferencesService** `notification_preferences_service.dart` — Per-group mute prefs
  (likes/comments/friends/system/referral) in `users/{uid}.notification_muted`.

## Coach & Gym
- **CoachService** `coach_service.dart` — Coach profiles, client links, discovery/search, top coaches
  (`getTopCoachesStream`: verified+accepting, avgRating DESC). `searchCoaches(query, city:, district:, sortBy:)` — sortBy: `avg_rating` | `client_count` (default) | `created_at`. `CoachProfileModel` includes `latitude`/`longitude` for client-side near-me sorting.
- **GymService** `gym_service.dart` — Gym CRUD, owner gym stream, member mgmt, discovery
  (`searchGyms(query, city:, district:, sortBy:, startAfter:, limit:)` — sortBy: `avg_rating` | `member_count` (default) | `created_at` | `name`), QR token.
- **Faz 6 §6.1 — gym invite codes** (behind `FeatureFlags.gymInviteCodes`): `GymInviteCodesScreen`
  (management list + "+ New code" sheet) and `GymInviteCodeDetailScreen` (QR + poster export) in
  `lib/screens/gym/`, backed by `ReferralService`'s gym methods (above) and `GymInviteCodeModel`
  (`lib/core/models/`). QR rendering reuses `GymQrScreen`'s exact `qr_flutter` pattern; the printable
  poster (`GymInvitePosterCard`, `lib/core/widgets/`) reuses `GymShareCard`'s exact offscreen
  `RepaintBoundary` capture-and-share approach, but is deliberately black-on-white (not brand-themed)
  since that one gets printed and re-scanned off paper, not viewed on a screen.
  **Faz 6 §6.5/§6.6** (behind its OWN `FeatureFlags.gymAttribution`, so a problem in this newer surface
  can't take down already-verified code generation): `GymInviteCodesScreen` gained a funnel-stat header
  (`attributed_member_count`/`attributed_premium_count` read straight off the already-in-hand
  `GymModel`, no new query) showing signups vs. premium conversions across ALL of the gym's codes
  combined — deliberately 2 stages, not 3: "scans" has no honest server-side count anywhere in this
  codebase (a poster is scanned by a bare camera app, outside anything Flutter/Functions can observe;
  real scan analytics would need the site's own page-view tracking, Faz 6 §6.7, a separate repo). New
  `GymEarningsScreen` (`lib/screens/gym/gym_earnings_screen.dart`) reuses `AffiliateEarningsScreen`'s
  exact stat-card/history/payout-request pattern, scoped via `CommissionService`'s new `types` filter
  to `CommissionType.gymPremiumShare` only, with a literal "payouts are processed manually" banner
  (distinct copy from the personal screen's "coming soon" framing — no payout rail exists anywhere in
  this plan) and a real link to `LegalScreen(type: LegalDocumentType.marketplaceTerms)` — closing audit
  finding C16a (`marketplace_terms_{en,tr}.md` was drafted but never shown anywhere in the app; see
  `docs/COMPLIANCE.md` §8).
- **GymLeaderboardService** — weekly in-gym leaderboard (`getWeeklyLeaderboardStream`) + gym wars.
  **Faz 5 §5.3**: ranking source changed from raw weekly check-in counts to weekly XP
  (`community_weekly_xp/{weekKey}`, bumped by `progress.js`'s `awardXp` for ANY XP kind, not just
  check-ins) — `LeaderboardEntryModel.checkInCount` renamed to `.xp` (only 3 consuming files, a
  contained rename) since a field still called "check-in count" holding an XP number would read as a
  defect. Live trigger moved from the `checkins` collection to the gym's own `members` roster
  (`.snapshots()`); per-member XP is a one-shot, chunked `whereIn` (≤30/chunk) read on every roster
  emission, not a live listener per member — a documented trade-off (not sub-second-live the way the
  checkins listener was), see that method's doc comment.
- **GymAnalyticsService**, **GymApplicationService**, **GymPostService**.
- **CoachApplicationService**, **CoachReviewService** (transaction-updates avgRating/ratingCount).

## Billing & Credits
- **BillingService** `billing_service.dart` — `in_app_purchase`; subscriptions
  (`com.cookrange.premium.{monthly,yearly}`), consumable top-up (`cookrange_ai_credits_10`), restore.
  **No client-side premium grant or credit write** — every purchase is sent to the `validatePurchase`
  callable, which verifies the receipt against Apple/Google and writes `entitlements/{uid}` +
  `ai_credits/{uid}` server-side (mirrored to `subscription_tier`/`subscription_expires_at`).
- **CommissionService** `commission_service.dart` — `users/{uid}/commissions` + payout_requests read/
  stream, earnings summary; read-only, no client-side commission writes — `recordReferralCommission`/
  `recordCoachSessionCommission` (dead, zero-caller client writes that would have failed outright
  against `firestore.rules`' server-only commission rule anyway) and `CommissionModel.toFirestore()`
  (only ever called by those two) were removed. `functions/economy.js` is the sole writer. **Faz 6 §6.6**: `getCommissionsStream`/
  `getEarningsSummary` both gained an optional `types` filter so `GymEarningsScreen` can scope to only
  `CommissionType.gymPremiumShare`, never mixing in a gym owner's own personal referral/coaching
  commissions from the same wallet. (Tracking layer only; payout processing deferred — see roadmap.)

## Admin & Moderation
- **AdminService** `admin_service.dart` — The admin API surface (~30 methods): application review
  (approve/reject coach+gym), `searchUsers`, `banUser`/`unbanUser`, `setUserRole`, history streams,
  `logAuditAction`+`auditLogStream`, `pendingCountStream`, reports (pending/reviewed/dismiss/remove +
  bulk), `fetchAnalyticsSnapshot` (count() aggregates), `premiumUsersStream`, `bannedUsersStream`,
  `aiUsageStream`, `grantBonusCredits` (writes the server-only `ai_credits/{uid}` ledger),
  `referralsStream`/`voidReferralCode`, program review
  (approve/reject/pending/history), `adminConfigStream`/`updateAdminConfig`, `broadcastsStream`/
  `sendBroadcast`, `setGymVerified`/`setCoachVerified`, `forceLogout`, `sendPasswordReset`,
  `getUserDataStats`, `getAppConfig`/`updateAppConfig` (read + audited write of `app_config/global`,
  backing `AdminAppConfigScreen`). Coach/gym approval-decision notifications and
  `sendNotificationToUser` (free-text) are **server-authoritative** (`BLK-03`) — both call the
  admin-claim-gated `sendAdminNotification` callable rather than writing the notification doc
  directly; the application status/role-grant batch itself is unchanged (already `isAdmin()`-gated).
  **Faz 2 §2.3**: `approveGymApplication`'s batch also creates the gym's `kind:'gym'`
  `community_groups/{gymId}` doc + the owner's `owner`-role membership doc + a paired
  `chats/{gymId}` doc (`type:'gym'`) — same id as the gym, one batch, still `isAdmin()`-gated (see
  `DATABASE.md`).
  **Faz 2 §2.6**: `pendingModerationAppealCountStream`/`pendingModerationAppealsStream`/
  `reviewedModerationAppealsStream`/`resolveModerationAppeal` — the admin queue for
  `moderation_appeals/{id}` (mirrors the `privacy_requests` DSAR pair immediately above). Resolving
  `upheld` ALSO reverses a `mute`/`ban` via the existing `CommunityGroupService.unmuteMember`/
  `unbanMember` (a `kick` has no persistent restriction to lift, so it's admin-note-only) and always
  notifies the appellant through the existing `sendNotificationToUser` free-text path — no new
  `NotificationType` for one admin-authored message.
  **Faz 5 §5.2**: `resolveModerationAppeal` branches FIRST on `appeal.isCreditRestriction` (checked
  before the mute/ban branch, since `appeal.action`/`appeal.groupId` are meaningless placeholders for
  this appeal kind — see `ModerationAppealModel`'s doc comment) and reverses an upheld one via the new
  `_liftCreditRestriction(uid, adminUid)`: writes a `lift` entry to `users/{uid}/credit_moderation`
  and clears `is_shadow_restricted` **and resets `flag_count` to 0** on `credit_restrictions/{uid}` —
  a genuine clean slate, since leaving the counter at/above the auto-restrict threshold would let the
  very next flagged event immediately re-restrict an account whose appeal was just judged unwarranted.
- **CostAnalyticsService** `cost_analytics_service.dart` — Admin-only cost/revenue/profit estimates
  (Firebase pricing + `count()` aggregates) **plus real AI usage**: `fetchAiUsageStats` reads
  `ai_usage_stats/global` (+ day buckets — total cost/requests/tokens, `by_model`, `by_type`) and
  `fetchUserAiLogs(uid)` queries `ai_usage_logs` for a per-user breakdown. Powers
  `AdminCostAnalyticsScreen` (now shows real AI spend, not just estimates).
- **AdminAppConfigScreen** `screens/admin/admin_app_config_screen.dart` — Admin editor for the Remote
  App Config (`app_config/global`) via `AdminService.getAppConfig`/`updateAppConfig`: AI models/limits,
  version gates + force-update, maintenance mode, announcement, feature kill-switches, rollout %.

## Feature, Config & Push
- **FeatureGateService** `feature_gate_service.dart` — Entitlement checks + `showPaywall()`. **Faz 5
  §5.4**: all 8 `Entitlements` gates now have a real call site (Faz 0 §0.3 built this service and
  wired `showPaywall()` in 3 places, but left every `check(context, gate)` call site unwritten — that
  finding was re-verified empirically, still true, immediately before this task). Full gate-by-gate
  breakdown: [`PREMIUM.md`](PREMIUM.md) §1.
- **AppConfigService** `app_config_service.dart` — Remote App Config client over `app_config/global`
  (public-read, admin-write, **no secrets**). Boot flow is **cache-first**: reads the SharedPrefs
  snapshot instantly, then background-refreshes with a **6h TTL**; exposes a reactive `ValueNotifier`
  so gates rebuild on change. Parses into `AppConfig` (`app_config_model.dart`, every field has a
  fail-safe default). Config sections: `ai` (text/vision model, `model_by_type`, `max_tokens`
  [`_by_type`], temperature, timeout, free/premium daily limits, feature toggles), `version`
  (min_supported/latest per platform, force_update, store URLs, i18n update_message), `maintenance`,
  `announcement`, `features` (kill-switch, default-ON), `rollout` (%), `limits`,
  `endpoints.ai_proxy_url`. Helpers: `isFeatureEnabled(key)` (kill-switch), rollout bucketing.
  Consumed by `version_gate.dart` (→ `ForceUpdateScreen`), `MaintenanceScreen`, `AnnouncementBanner`,
  and feature gates — all evaluated at `route_guard.dart` build start. The **same doc is read
  server-side by `aiProxy`** (5-min cache) so model/max_tokens/quota change without redeploy.
- **RemoteConfigService** `remote_config_service.dart` — Firebase Remote Config flags: `maintenanceMode`,
  `minVersion`, `aiModel`, `maxMealRetries`, `featureVoiceAssistant`, `featureNutritionAnalytics`,
  `aiProxyUrl`. (Being superseded by `AppConfigService`/`app_config/global`.)
- **PushNotificationService** `push_notification_service.dart` — FCM + `flutter_local_notifications`.
  Initializes the `timezone` DB (`flutter_timezone` → device zone) in `initialize()`. Hydration
  reminders are precise + multi-time: `scheduleDailyWaterReminder({title, body, wakeTime, sleepTime,
  count})` uses `zonedSchedule` (`matchDateTimeComponents.time`, **inexact** alarms — no Android 13+
  exact-alarm permission) at clock times evenly spread across the wake→sleep window (handles midnight
  wrap), over a reserved id block (7001–7012). `cancelWaterReminder()` clears the block. Spread math is
  pure + unit-tested (`PushNotificationService.spreadReminderTimes`).
- **PermissionService** `permission_service.dart` — Runtime permission requests (camera/GPS/notif).
- **ATTConsentService** `att_consent_service.dart` — iOS App Tracking Transparency (one-shot,
  `att_prompted` SharedPref key).
- **ConsentService** `consent_service.dart` — KVKK/GDPR consent records. `watchConsents()` /
  `getConsents()` (all purposes, unset-filled), `setConsent(purpose, granted)` (stamps
  `kLegalPolicyVersion` + server time; Crashlytics breadcrumb), `hasConsent(purpose)` (true only if
  granted & not stale — callers re-prompt otherwise), `recordInitialConsents({analytics, marketing})`
  (batch-writes essentials=granted + optionals at registration), `applyCollectionConsent` (ties the
  user's consent state to the Analytics/Crashlytics collection flags so collection only runs once
  consent is granted). Source of truth:
  `users/{uid}/consents/{docId}` (owner-only). Surfaced in `ConsentCenterScreen` + captured in
  `register_screen`. See `docs/COMPLIANCE.md`.
- **ProgressSharingService** `progress_sharing_service.dart` (Faz 4 §4.1/§4.2/§4.3) — Deliberately a
  SEPARATE service from `ConsentService` above, not an extension of it: this is per-SCOPE
  (`ProgressSharingScope` — `gym_{gymId}` \| `coach_{uid}`) and TIERED (0-3,
  `ProgressSharingTier`), not one global bool purpose. Member side: `watchAll()` (stream, keyed by
  scopeId — backs `ProgressSharingConsentScreen`, the Consent-Center-adjacent management screen,
  §4.3), `getTier(scope)`, `grantTier(scope, tier)` / `revoke(scope)` (both a merge-only `set()`,
  stamping `kLegalPolicyVersion` + a server timestamp — mirrors `ConsentService.setConsent`'s
  versioning philosophy without forcing this genuinely different shape into `ConsentPurpose`),
  `getLastAccessByScope()` (one bounded `access_log` query, grouped client-side to "most recent
  viewer per scope" — the screen's "last viewed on X" line). Caller side (gym owner / coach):
  `getCachedSummary({memberUid, scope})` — a plain, free Firestore get of an already-generated
  `member_summaries` doc, so simply re-opening a screen never spends a generation;
  `generateSummary({memberUid, scope, locale})` invokes the `generateMemberProgressSummary` callable
  (see Cloud Functions below) — throws `FirebaseFunctionsException` on rejection (`not_shared` at
  tier 0, `not_authorized_for_scope`, `generation_rate_limited`), never silently swallowed;
  `getConsentingMemberUids(scope)` invokes `getConsentingMemberUids` (fails CLOSED to an empty set
  on error, deliberately — a transient failure must never fall back to "show everyone unscoped");
  `sendInvite({scope, memberUid})` / `hasInvited({scope, memberUid})` — the tier-0 empty state's
  one-time "send an invite" button and its read-back status (`sendProgressShareInvite`,
  `progress_share_invites/{memberUid}`). Source of truth:
  `users/{uid}/progress_sharing/{scopeId}` (owner read/write) + `users/{uid}/access_log/{entryId}`
  (owner read, server write) + `gyms/{id}\|coach_profiles/{id}/progress_share_invites/{memberUid}`
  (owner-of-scope read, server write). See `docs/DATABASE.md` and `docs/COMPLIANCE.md`.
- **ProgressSharingConsentScreen** `screens/profile/progress_sharing_consent_screen.dart` (Faz 4
  §4.3) — member-side "see every gym/coach's current tier, revoke with one tap" screen, entered
  from a dedicated card on `ConsentCenterScreen` (not folded into that screen's `ConsentPurpose`
  grid — see the screen's own header comment for why: a variable-length list of per-relationship
  TIERS doesn't fit a fixed grid of global bool purposes). Resolves each scope's gym/coach display
  name via one-shot, memoized lookups (`GymService.getGym` / `CoachService.getCoachProfile` — no
  bulk-resolve endpoint exists for this direction, and a member has few enough scopes that N small
  fetches is the right trade-off). Revoke is immediate, no confirmation dialog (KVKK: withdrawing
  must be at least as easy as granting); raising/changing tier goes through a lightweight
  `_TierPickerSheet` (not the heavyweight, un-skippable flow §1.3 mandates for `gymPresence` — that
  is a location + health special-category consent, a tier change on an already-established
  relationship is a lighter decision). Explicitly NOT built: an initial-grant discovery flow (which
  gyms/coaches CAN I share with) — `watchAll()` only returns scopes with an existing decision, and
  there is still no UI anywhere that grants a first tier; that entry point belongs on the gym
  membership / coach relationship screens, out of this task's scope.
- **PrivacyRequestService** `privacy_request_service.dart` — DSAR channel. `submit(type, message)`
  → `privacy_requests/{id}`; `myRequestsStream()`. Admin side via `AdminService.privacyRequestsStream`
  / `updatePrivacyRequest` (+ audit log). Screens: `privacy_request_screen` (user),
  `admin_privacy_requests_screen` (admin).

## Infrastructure & Utilities
- **StorageUploadService** — Firebase Storage uploads (avatars, post/chat images).
- **SharingService** — `share_plus` wrapper (recipe/progress/post/shopping/referral/challenge/**meal plan
  template**, Faz 3 §3.3 "export") + deep links. `shareMealPlanTemplate` formats a plain-text weekly
  summary (mirrors `shareShoppingList`'s plain-text-list approach, not a new file format) — nutrition
  totals come fresh from `PlanNutritionCalculator`, never a stored value.
- **DeepLinkService** — `app_links` universal + custom scheme routing; `init(navigatorKey)` in splash.
  **Faz 6 §6.3**: `/invite/{code}` no longer routes to Settings — with no signed-in session it stages
  the code (`ReferralService.savePendingCode` + directly into `OnboardingProvider`) and pushes
  onboarding (skipped if `OnboardingFlowScreen.isActive` — an in-progress flow just needs the code, not
  a second instance stacked on top); with a signed-in session the code is discarded and explained via
  an `AppSnackBar.info` (invite codes are new-signup only).
- **DataExportService** — **Complete GDPR export**: profile + **private nutrition PII** + all
  user subcollections (logs, plans, lists, posts, food analyses, achievements, consents, etc.) +
  a Storage file manifest → JSON share.
- **LogService** — Structured logging + device/IP context (Hive-cached).
- **CrashlyticsService** — `recordError`, breadcrumbs, custom keys (screen/tier/aiModel).
  **Collection is privacy-by-default OFF** — enabled only after the user grants consent
  (via `ConsentService.applyCollectionConsent`).
- **AnalyticsService** — Event queue (Hive), batch, `logScreenView`. **Collection is
  privacy-by-default OFF** — gated on consent (no email or PII in event payloads).
- **PerformanceService** — `HttpMetric` on AI calls + custom traces.
- **ExerciseLogService**, **ProgramService**, **RecipeNoteService**,
  **ShoppingListSyncService** (`users/{uid}/lists/shopping`).
- **LeaderboardService** — community-wide leaderboards: `getGlobalLeaderboardStream`/
  `getFriendsLeaderboard` (all-time streak, never resets) + (**Faz 5 §5.3**)
  `getWeeklyXpLeaderboardStream` (weekly, XP-based, resets Monday 00:00 local — a distinct metric AND
  window, reading the denormalized `community_weekly_xp/{weekKey}/members` rollup, flat authenticated-
  read since XP is already public on `users/{uid}`). Both live as tabs on the same
  `LeaderboardScreen` (Global / Friends / This Week) rather than a second screen.
- **DishSeederService** — `seedIfEmpty` (called unconditionally on every app boot) upserts whatever's
  missing from `dishes/`, not "seed only if the collection is totally empty" (Faz 3 §3.6 repair — the
  old gate meant a dish added to `dish_data.dart` after first launch never reached an
  already-seeded environment on its own; the only path that picked up new dishes was an admin's
  manual reseed via `seedAllDishes`). Cheap in steady state: one `count()` aggregation against
  `allDishes.length`; only fetches the live id set and diffs when they disagree. Additive-only —
  never overwrites an existing doc. **DishImageService**, **DemoContentSeeder** (sample programs;
  `seeds/` gate).
- **DeviceInfoService**, **ScreenUtilService**, **SystemUIService**, **AppInitializationService**
  (orchestrates boot), **AppLifecycleService**, **ProviderInitializationService**,
  **RouteConfigurationService**, **LoggingNavigatorObserver**.
- **GlobalErrorHandler** — single `FlutterError.onError` owner; wired into `MaterialApp.builder`.
- **AllergenSafety** (util) — Deterministic allergen filter: given a user's allergies/avoid lists,
  flags/removes unsafe dishes. Used by `WeeklyMealPlanService` (pre-AI) and food flows.
- **PlanNutritionCalculator** (util, `plan_nutrition_calculator.dart`, Faz 3 §3.4) — Single authority
  for meal-plan nutrition math: sums a `List<MealEntry>` against a `{id: DishModel}` catalog into
  `PlanNutritionTotals` (calories/protein/carbs/fat/fiber), scaled by each entry's `portion`; a
  missing/unresolvable `dishId` or a custom/free-text entry contributes zero rather than throwing.
  `calculateWeek`/`combineDays` roll per-day totals into a week sum + average (mirrors
  `WeeklyMealPlanModel`'s `total_*`/`avg_daily_*` shape). **No Firebase import** — fully unit-tested
  (`test/plan_nutrition_calculator_test.dart`, 27 cases). First real caller: `WeeklyMealPlanService.
  swapMeal`, above. **`classifyDeviation(actual, target, {tolerance = 0.10})`** (Faz 3 §3.3, added with
  the template builder) — the single shared "under/onTarget/over" band every deviation reading (the
  calorie ring badge, each macro bar) uses, so the definition of "off target" can't drift between
  surfaces; a non-positive `target` always reads `onTarget` (nothing to deviate from before a goal is
  set). **Faz 3 §3.5**: `PlanOfferPreviewScreen` is the second real caller — reuses
  `TemplateNutritionPanel`/`TemplateAllergenPanel` (§3.3 widgets) as-is against the member's OWN
  profile (the correct "own profile" case: previewing an offer sent TO you). Plan view and
  AI-output validation are still not built against this class.
  Named `PlanNutritionTotals`, not the shorter `NutritionTotals`, to avoid colliding with
  `food_log_model.dart`'s own distinct `NutritionTotals` (logged/eaten totals, no `fiber`, different
  shape) — importing both into one file would otherwise be an ambiguous-import compile error.
- **MealPlanTemplateService** (`meal_plan_template_service.dart`, Faz 3 §3.3) — CRUD + queries for
  `meal_plan_templates/{id}` on top of the §3.2 data model/rules. `createTemplate`/`saveEdits`/
  `deleteTemplate`/`forkTemplate` (fork = the "var olandan türet" creation path AND the library's
  "duplicate" action — same operation, different caller intent). **Version policy**: `saveEdits` bumps
  `version` by 1 only when `days` (the actual meal content) changed between the original and the edit —
  a rename/re-tag/goal-only save does not, since `version` exists to trace a sent
  `plan_offers.template_snapshot` back to a content iteration, and metadata-only edits change nothing a
  recipient would feel. This is a version COUNTER, not a stored history of past `days` — no
  `versions/{n}` subcollection was added; a real history browser is a future, separately-scoped feature.
  **Never writes `usage_count`** — that field is server-only (`sendPlanOffer` callable, §3.2), bumped
  once per recipient at send time; this service only reads it for the library's "sent to N members"
  display. Three query shapes back the library/fork-picker screens, each with its own composite index
  (`firestore.indexes.json`): `streamMyTemplates` (`author_uid`+`updated_at` DESC), `streamGymShared
  Templates` (`gym_id`+`share_scope`+`updated_at` DESC — mirrors the gym-membership branch of the read
  rule so nothing this returns can fail it), `streamPublicTemplates` (`is_public`+`usage_count` DESC).
  `generateDraftFromAI` (creation path 1) mirrors `WeeklyMealPlanService`'s AI-plan shape: fetches
  `DishService.getAllDishes()`, runs the MANDATORY `AllergenSafety.filterSafe` pre-filter before the pool
  reaches the AI prompt (refuses with `StateError` if that leaves zero safe dishes), reuses
  `PromptService.generateWeeklyMealPlanPrompt` verbatim, and returns an UNSAVED draft — the AI's own
  claimed totals are discarded entirely; only its dish selections are kept, and the caller must display
  nutrition via `PlanNutritionCalculator` instead (never the LLM's self-reported numbers).
- **PlanOfferService** (`plan_offer_service.dart`, Faz 3 §3.5) — the send/respond side, downstream of
  `MealPlanTemplateService` (above): `sendOffer` invokes the `sendPlanOffer` callable (bulk send = one
  call, `toUids` plural — the callable creates one `plan_offers` doc per recipient itself, never a
  client-side loop of N calls). `streamPendingOffers`/`streamOfferHistory` back the offer inbox (see
  `DATABASE.md`'s indexes section for why they're two different query shapes with different index
  scopes). `acceptOffer` orchestrates: parse `offer.templateSnapshot` back into a `MealPlanTemplate`
  (`MealPlanTemplate.fromJson`, per that model's own doc comment), call
  `WeeklyMealPlanService.adoptTemplate`, THEN — only once that succeeds — flip the offer to `accepted`
  (this order first; the reverse could leave an "accepted" offer with no plan actually copied).
  `declineOffer` is a plain client `.update()` under the already-tested `plan_offers` rule (no callable
  needed — the rule itself allows the recipient to move `status`/`responded_at`/optional
  `decline_reason` directly). `computeMemberTarget` (static) — the member's own calorie+macro target
  for the offer preview's deviation indicator, via the same public `CalorieCalculator.calculateBMR/
  calculateTDEE/adjustTDEEForGoal/calculateMacros` chain `WeeklyMealPlanService._calculateUserCalories`
  already runs privately for AI generation (no new stored "target" field — there isn't one anywhere in
  this schema). `pollPendingOfferCount` — the home-screen discovery banner's live-ish count, via the
  existing `pollCount` util (never a full `.snapshots()` listener just to read `.length`).
- **safeLaunchUrl** (util) — Hardened `url_launcher` wrapper: only opens URLs whose scheme + host pass
  an allowlist (blocks arbitrary/`javascript:`/unexpected-host navigation).
- **AppEnv** (util) — Central env reader (`flutter_dotenv`): typed access to keys, `APP_ENV`, and the
  debug-only `OPENROUTER_API_KEY`; single place that decides dev-vs-release behavior.
- **TestModeService** — dev test-mode toggle (Hive) + `TestDataLibrary`.
- **WhatsNewService** — once-per-version changelog gate (SharedPref `whats_new_last_version`).

---

## Cloud Functions (`functions/`)

> Server-authoritative security layer (hardening 2026-06-30, extended 2026-08-01 with
> `notifications.js`/`social.js` for `BLK-03`/`SEC-06`; extended 2026-08-04 with `presence.js` for
> Faz 1 §1.5/§1.7, and the same day with `onChatMessageCreated` (`index.js`) taking over
> `chats.unreadCounts` increments for Faz 2 §2.1's message model v2; extended 2026-08-05 with
> `groups.js` for Faz 2 §2.3 — invite-code redemption is the one piece of unified groups that
> genuinely needs server validation, since the code lives in a fully closed
> `group_invites/{code}` doc). **31 functions deployed** to
> `cookrange-app` alongside the Firestore rules;
> `appStoreNotifications` + `playRtdn` are wired but inert until store credentials exist. App Check
> enforcement + store-credential requirements are gated by `APP_ENV` (`development` | `production`)
> in `config.js` — **currently `development`** (`BLK-14`).
> **3 more added 2026-08-05** for Faz 2 §2.6 (`rate_limit.js`'s shared helper + `moderation.js`'s
> `onReportCreated`/`onGroupModerationActionCreated`/`onModerationAppealCreated` triggers) —
> registered in `index.js` but **not yet deployed** (the "31" above counts only what
> `firebase functions:list` has actually confirmed live); syntax-checked (`node -c`) only, per this
> repo's standing no-functional-test-harness limitation for Cloud Functions (`CLAUDE.md` §8).
> **1 more added the same day** for Faz 3 §3.2 (`templates.js`'s `sendPlanOffer`) — same status:
> registered in `index.js`, `node -c` syntax-checked only, not yet confirmed deployed.
> **2 more added for Faz 3 §3.5** (`templates.js`'s `onPlanOfferResponded` trigger +
> `expirePlanOffers` scheduled sweep, plus `sendPlanOffer` itself extended in place — not a new
> export) — same status: registered in `index.js`, `node -c` syntax-checked only (no functional
> execution harness exists for Cloud Functions in this repo, per `CLAUDE.md` §8), not yet confirmed
> deployed.
> **3 more added for Faz 4 §4.1/§4.2** (`summaries.js`'s `generateMemberProgressSummary` callable +
> `onProgressSharingWrite` trigger + `expireMemberProgressSummaries` scheduled sweep) — exported via
> a FACTORY (`createSummariesModule({...})`, called from `index.js` with its own already-in-scope
> `aiProxy` quota/cost helpers passed by reference) rather than a plain trigger object, so the
> `ai_credits/{uid}`-touching "SECURITY MODEL (do not regress)" quota logic is reused, not
> duplicated a second time, without a circular `require`. Verification for this batch went one step
> beyond the usual `node -c`: the module graph was actually `require()`'d (not deployed/invoked) and
> every expected export confirmed to resolve to a function — still not a functional/runtime test, but
> stronger than syntax-checking alone. Registered in `index.js`, **not yet confirmed deployed**. Also
> fixes a real gap while here: `ALLOWED_TYPES` (the `aiProxy` cost-attribution allowlist) was missing
> `'coach_report'` entirely — any caller passing it silently fell into `'other'`'s bucket; now present.
>
> **2 more added for Faz 4 §4.3** (`summaries.js`'s `sendProgressShareInvite` +
> `getConsentingMemberUids` callables — same factory, same exported-by-reference shape, no new
> `require` cycle) — closes the AT-RISK LIST leak (audit finding: `gym_analytics_service.dart`'s
> 14-day-inactive list showed every member's NAME with zero permission check) by giving the client a
> way to learn WHICH members granted tier>=1 without ever letting it read another user's
> `progress_sharing` doc directly (still owner-only). Same verification level as the §4.1/§4.2 batch
> above: `node -c` clean, the module graph actually `require()`'d and both new exports confirmed to
> resolve to real `onCall` functions — not a functional/runtime test, but stronger than
> syntax-checking alone. Registered in `index.js`, **not yet confirmed deployed**.
>
> **Faz 5 §5.1 (XP backbone)**: no new exported function — `progress.js`'s existing `syncProgress`
> extended IN PLACE (the plan's own text calls this function `awardProgress`; the shipped Faz 0 §0.4
> code named it `syncProgress` — code is truth, so it stays `syncProgress`, extended rather than
> duplicated under a second name) to also award XP, plus a new internal (non-callable) `awardXp`
> primitive exported for in-process use by three OTHER already-existing functions:
> `presence.js`'s `closeSession` and `gym.js`'s `validateGymCheckin` (both award `check_in` XP right
> after they write their own already-server-verified `checkins/*` doc) and `templates.js`'s
> `onPlanOfferResponded` (extended with a new `accepted`-transition branch alongside its existing
> `declined` one, awarding `template_accepted` XP). `index.js`'s `getPushText`/`TYPE_TO_MUTE_GROUP`
> also gained a `levelUp` case (mirrors `achievementEarned`'s "always shown, never muted" treatment).
> Same verification level as the Faz 4 batches above: `node -c` clean on all five touched files, the
> full `index.js` module graph actually `require()`'d, every expected export (`syncProgress`,
> `backfillProgress`, `awardXp`, `XP_TABLE`, plus the unchanged exports of the other four files)
> confirmed to resolve — still not a functional/runtime test, no execution harness exists for Cloud
> Functions in this repo (`CLAUDE.md` §8). Not yet confirmed deployed.
>
> **6 more added for Faz 5 §5.2** (received-engagement credit): two NEW files —
> `engagement_credit_logic.js` (pure, zero Firebase dependency — reciprocity/concentration weighting,
> duplicate-content/content-quality gates, the credit table + premium-multiplier math, local day/week
> helpers, plus (Faz 5 §5.3) `previousWeekKey` for the group-contribution streak counter; **63 unit
> tests**, `node --test functions/test/engagement_credit_logic.test.js`, the one
> piece of this batch WITH real functional test coverage rather than syntax-checking alone) and
> `engagement_credit.js` (orchestration — 5 new Firestore triggers: `onPostReactionCreated`,
> `onCommentLikeCreated`, `onGroupChatMessageCreatedForContribution`,
> `onGroupPostCreatedForContribution`, `onGroupCommentCreatedForContribution`; 1 new scheduled
> function: `awardWeeklyGroupTop3`; plus the non-callable `awardTemplateUsedCredit`, hooked
> in-process into `templates.js`'s existing `onPlanOfferResponded` accept branch, same pattern as
> `awardXp`'s three call sites). `entitlements.js` gained one additive export (`isPremium`, a read
> — mirrors `index.js`'s own private copy rather than creating a `require` cycle with it).
> Verification: `node -c` clean on all five touched/created `.js` files, the full `index.js` module
> graph `require()`'d with every new export confirmed to resolve to a function — plus, uniquely for
> this batch, the pure-logic module's 59 unit tests actually RUN and passing (not just syntax-
> checked) — still no functional/runtime harness for the Firestore-trigger/transaction orchestration
> itself (`CLAUDE.md` §8). Not yet confirmed deployed.
>
> **Faz 5 §5.3** ("Yarışma ve statü" — leaderboards + badge cabinet): no new files. `progress.js`
> gained `grantAchievementIfNew` (a narrow, standalone "grant ONE badge now" primitive — NOT routed
> through `runSync`, since two of the four new badges are earned from a scheduled sweep, not a live
> `syncProgress` call) plus 4 new `ACHIEVEMENT_POINTS` entries and two new in-`runSync` checks
> (`level50`, `gymRegular`). `engagement_credit_logic.js` gained one pure helper
> (`previousWeekKey`, 4 new unit tests). `engagement_credit.js` gained `bumpGroupTop3Streak` (the
> `groupStreak4` counter, hooked into `awardWeeklyGroupTop3`'s existing winner loop) and 1 new
> scheduled function, `computeGroupContributionLeaderboards` (every 15 min — denormalizes
> `weekly_contributions` into the group-member-readable `weekly_leaderboard/{weekKey}` summary the
> §5.2 doc comment already promised). `firestore.rules` gained a new `isGymMember(gymId)` helper and
> closed a genuine PRE-EXISTING gap (`gyms/{id}/members` read was owner-or-self only, silently
> rejecting the in-gym leaderboard's own list query for every non-owner member — see `DATABASE.md`'s
> `gyms/{id}/members/{id}` row). Verification: `node -c` clean on all four touched `.js` files, the
> full `index.js` module graph `require()`'d with `computeGroupContributionLeaderboards` confirmed to
> resolve, the pure-logic module's 63 unit tests RUN and passing, and the firestore-rules emulator
> suite (165 → 169 tests, all passing) — the rules layer is the one piece of this batch WITH real
> behavioral test coverage (positive AND negative) rather than syntax/require-checking alone. Not yet
> confirmed deployed.
>
> Full inventory and wire contracts: [`API.md`](API.md) §1.

**AI proxy** (`index.js`)
- **aiProxy** (HTTPS) — The release AI path: the only place the OpenRouter key exists, and the only
  place AI quota is enforced. Architecture, cost model, and safety layers:
  [`AI_SYSTEM.md`](AI_SYSTEM.md). Wire contract and error codes: [`API.md`](API.md) §2.

**Achievements, reputation & XP** (`progress.js`, Faz 0 §0.4 / Faz 5 §5.1)
- **syncProgress** (callable) — The single server-authoritative entry gate: re-derives streak/tier
  achievements from truth, folds in the caller's self-reported momentary event flags
  (`justLoggedMeal` etc.), and — as of Faz 5 §5.1 — awards XP for a request-supplied `xpEvents[]`
  array (`{kind, refId, ...}`, one of `meal_logged`/`recipe_cooked`/`post_created`/
  `comment_created`/`reaction_given`), each independently re-verified against its referenced doc
  before anything is awarded. Response now also carries `xp`/`level`/`leveledUp`/`xpAwarded`
  alongside the pre-existing `score`(=xp, kept as a compatibility mirror)/`tier`/`granted`.
- **backfillProgress** (callable) — One-time catch-up for existing users; unchanged signature, now
  also benefits from `syncProgress`'s XP additions since it calls the same shared `runSync` core.
- **awardXp** (internal, NOT an exported Cloud Function) — The only writer of `users/{uid}.xp`/
  `.level`/`.level_updated_at` and of `users/{uid}/xp_events/*`. Idempotent per `${kind}_${refId}`;
  enforces a fixed, server-owned points/daily-cap table (`XP_TABLE`) a client can never override;
  sends the `levelUp` notification (reusing the existing notification pipeline — no confetti/
  animation library exists anywhere in this codebase) the instant a threshold is crossed. Called
  from `syncProgress` itself (client-reported kinds + server-derived `streak_day`/
  `achievement_earned`) AND, in-process, from `presence.js`/`gym.js` (`check_in`) and
  `templates.js` (`template_accepted`) — see the file's header comment for the full per-kind trust
  model and exactly why each of those three call sites needs zero additional client trust.
- **grantAchievementIfNew** (internal, NOT an exported Cloud Function, Faz 5 §5.3) — A narrow,
  standalone "grant ONE achievement key if not already earned" primitive, separate from `runSync`'s
  own batch grant loop: two of the four new §5.3 badges (`groupTop3`/`groupStreak4`) are earned from
  `engagement_credit.js`'s SCHEDULED `awardWeeklyGroupTop3` sweep, not from a live `syncProgress`
  call, so there's no `runSync` invocation to piggyback on. The other two new badges (`level50`,
  `gymRegular`) ARE granted from inside `runSync` itself, alongside the original 11 — `level50` off
  the same post-award `latestLevel` the tier badges already use (zero extra reads); `gymRegular` off
  a `count()` aggregation over `xp_events` where `kind == 'check_in'` (`>= 15`), guarded behind
  `!earned.has('gymRegular')` so the aggregation read is only ever paid before the badge is earned,
  never again after.

**Entitlements & purchases** (`entitlements.js`, `purchases.js`)
- **grantPremium / revokePremium / grantBonusCredits / claimPurchaseToken** (`entitlements.js`) —
  The **only** writers of `entitlements/{uid}` (premium) and `ai_credits/{uid}` (credits);
  `subscription_tier` is mirrored to the user doc. Server-only.
- **purchaseCorrelationKey / reverseCommissionsForPurchase** (`entitlements.js`, Faz 6 §6.6
  follow-up — commission reversal) — `purchaseCorrelationKey(platform, token)` is a one-way SHA-256
  of `platform:token`, written onto a commission entry at grant time
  (`economy.js`'s `maybeAwardGymCommission`) as `purchase_key` and recomputed at revocation time to
  find it again; deliberately NOT the reversible base64url id `claimPurchaseToken` uses for
  `processed_purchases/{id}` — that collection is fully server-only, but `commissions` is
  owner-readable, so a reversible key there would hand the owner a decodable copy of the purchasing
  member's actual store transaction id for no functional reason. `reverseCommissionsForPurchase
  (platform, token, reason)` runs a `collectionGroup('commissions').where('purchase_key', '==', …)`
  query (new `COLLECTION_GROUP` index, `firestore.indexes.json`) and, per matched entry: `pending`/
  `approved` → flips to `rejected` (existing `CommissionStatus`, already excluded from
  `commission_service.dart`'s `getEarningsSummary` totals) plus `reversed_at`/`reversed_reason`;
  already-`paid` → left factually intact (annotated only) plus a NEW negative-amount sibling entry
  (`status:'pending'`, `adjustment_of`/`adjustment_reason`) that nets against the owner's next MANUAL
  payout instead of clawing back cash already sent; already-reversed/rejected/an adjustment entry
  itself → no-op (idempotent against webhook redelivery). Called next to every `revokePremium` call in
  `purchases.js`, best-effort (`.catch`-logged) — but, unlike those `revokePremium` calls, ONLY for a
  genuine refund/revoke signal, never for a plain non-renewed expiry (see the `appStoreNotifications`/
  `playRtdn` bullet below for why) — see its own doc comment for the full reasoning, including why the
  pre-existing `referral` commission is structurally exempt rather than still-gapped.
- **validatePurchase** (callable, `purchases.js`) — Verifies receipts against the **Apple App Store
  Server API** + **Google Play Developer API**, dedupes purchase tokens, and grants entitlements/
  credits via `entitlements.js`. **Fail-closed** (no grant unless the store confirms). **Faz 6 §6.6**:
  immediately after a subscription (never the AI-credits consumable) grant succeeds, calls
  `economy.js`'s `maybeAwardGymCommission(uid, productId, platform, token)` — best-effort
  (`.catch`-logged, never fails an already-valid purchase response) — which no-ops for the
  overwhelming majority of purchases (no `gym_attributions/{uid}` doc) and otherwise accrues the
  gym's commission (`platform`/`token` are threaded through only so the commission entry can carry
  `purchase_key`, see above — nothing new is trusted from the client). Entirely server-side; the
  client never sees or triggers this. The function's own `revoked` branch (Apple only) also calls
  `reverseCommissionsForPurchase` alongside its existing `revokePremium` call.
- **appStoreNotifications** / **playRtdn** (`purchases.js`, *pending go-live*) — Store webhooks that
  **revoke** premium on refund/expiry (expiry included deliberately — losing premium ACCESS is
  correct whether a subscription was refunded or simply never renewed). **Commission-reversal gap
  CLOSED** (Faz 6 §6.6 follow-up): both handlers, and `validatePurchase`'s own `revoked` branch, now
  also call `entitlements.js`'s `reverseCommissionsForPurchase` (see above) — for `gymPremiumShare`
  entries, which are the only commission type carrying a `purchase_key` (the pre-existing `referral`
  commission remains structurally exempt, not gapped — see `maybeAwardGymCommission`'s and
  `applyReferral`'s own comments for why). Unlike the entitlement-revocation call right next to it,
  the reversal call is gated to REFUND/REVOKE (`appStoreNotifications`) and `voided`/notificationType
  12 (`playRtdn`) only — EXPIRED/notificationType 13 revoke access (correct — the paid period is over
  either way) but deliberately do NOT reverse a commission (a non-renewal doesn't retroactively
  invalidate the past, non-refunded purchase that already earned it).

**Economy & account** (`economy.js`, `account.js`)
- **applyReferral** (callable, `economy.js`) — Server-validated referral apply + server-side
  commission ledger (replaces the old client batch-write); writes the referrer's notification via
  `notifications.js`'s shared `writeNotification` helper. **Faz 6 §6.5**: a `type=='gym'` code takes a
  completely different branch — writes `gym_attributions/{uid}` (immutable, server-only), bumps
  `gyms/{gym_id}.attributed_member_count` in the SAME transaction, and (after commit, best-effort)
  notifies the gym owner via `NotificationType.gymAttribution` — deliberately WITHOUT `actorName`/
  `actorPhotoUrl` (only `actorUid`, for admin/audit lookups), matching the personal-referral
  notification's own actor-identity posture. No trial premium, no flat commission, for either party —
  see that branch's own comment for why a 5,000-use poster code makes the personal-referral reward
  mechanic the wrong (and abusable) fit. Also exports `maybeAwardGymCommission` (§6.6, called from
  `purchases.js`, see above) — kept in this file rather than `purchases.js` since it's economy/ledger
  logic, matching this file's existing role.
- **deleteUserAccount** (callable, `account.js`) — GDPR erasure: recursively deletes the user's
  Firestore subtree + Storage objects + the Auth user.

**Unified groups** (`groups.js`, Faz 2 §2.3/§2.5)
- **redeemGroupInvite** (callable) — Validates a `group_invites/{code}` doc (mirrors
  `applyReferral`'s shape almost exactly: a transaction returns a domain error string rather than
  throwing inside it, then an `HttpsError('failed-precondition', ...)` is raised once the
  transaction resolves) and, if valid + `invite_enabled` + the caller isn't already a member/banned,
  atomically creates their `members/{uid}` doc, increments `member_count`, and mirrors
  `group_memberships` onto their user doc. Only writer of group membership via a code — there's no
  client-readable path to validate one otherwise (the code lives in a fully closed
  `group_invites/{code}` doc, `allow read: if false`).
- **computeGroupActivityScores** (scheduled, every 15 min, Faz 2 §2.5) — Only writer of
  `community_groups.activity_score`/`activity_updated_at` (firestore.rules'
  `touchesProtectedGroupFields()` blocks every client path, including the owner). Scores `is_public`
  groups only (≤200/run — private/gym groups keep the field's safe default and are never queried by
  it), summing messages(×1)/posts(×3)/comments(×2)/new-members(×5) from the trailing 24h, each event
  weighted by `0.5 ^ (age_hours / 6)` (a 6h half-life — a smooth taper instead of the hard cliff a
  flat count-within-window would produce at exactly 24h; see the function's header comment for the
  full reasoning). Comments are resolved with ONE global `collectionGroup('comments')` query up
  front (they carry no denormalized `groupId`, and a per-group query would mean first enumerating
  every post a group has ever had), not per-group. Messages/posts/new-members are each a bounded,
  per-group `.limit()` query — no new collection-group index needed (single inequality filters,
  auto-indexed); posts reuses the existing `groupId+timestamp` composite.
- **seedOfficialGroups** (callable, admin-claim-gated exactly like `sendAdminNotification`, Faz 2
  §2.5 cold start) — Creates 2 official groups (general + "sağlıklı yaşam") in each of 15 hardcoded
  major-city names (kept in lockstep by hand with `lib/core/data/turkish_locations.dart` — Node can't
  import a Dart file) so the discovery carousels aren't empty before organic public groups exist.
  Idempotent (deterministic `official_{citySlug}_{template}` doc ids, skips existing ones); owned by
  the CALLING admin's own uid — there's no synthetic "system" account anywhere in this schema. **Not
  wired to any client UI** — a one-time operation, invoked manually (console/authenticated HTTPS
  call) rather than justifying a dedicated admin-tools screen for this pass.
**Automated moderation — abuse-rate throttling** (`rate_limit.js`, `moderation.js`, Faz 2 §2.6)
- **`rate_limit.js`** (no exported functions — a shared internal helper module) —
  `checkAndBumpSlidingWindow(db, uid, kind, windowMs, maxInWindow)` mirrors `index.js:
  enforceRateLimitAndQuota`'s transaction shape (a per-uid Firestore doc holding a window-start
  Timestamp + a count, reset once the window has expired), generalized so `moderation.js`'s three
  triggers below don't each duplicate it. `lockUntil(db, uid, kind, lockMs)` stamps
  `rate_limits/{uid}.{kind}_locked_until` — the field firestore.rules'
  `isReportRateLimited()`/`isModerationRateLimited()`/`isAppealRateLimited()` check before allowing
  the next client write of that kind.
- **onReportCreated** (Firestore trigger, `reports/{reportId}`) — Bumps the reporter's sliding
  window (10 min / 8 reports); over the threshold, locks `report_locked_until` for 15 min. Blunts a
  mass-reporting brigade trying to silence someone via report volume.
- **onGroupModerationActionCreated** (Firestore trigger,
  `community_groups/{groupId}/moderation/{actionId}`) — Bumps the ISSUING uid's sliding window (10
  min / 15 actions, covering mute/kick/ban/unmute/unban alike since all five funnel through one
  `moderation/{autoId}` create); over the threshold, locks `moderation_locked_until` for 15 min.
  Caps the blast radius of a compromised group owner/admin account attempting a mass-ban.
- **onModerationAppealCreated** (Firestore trigger, `moderation_appeals/{appealId}`) — Bumps the
  appellant's sliding window (1 hour / 5 appeals); over the threshold, locks `appeal_locked_until`
  for 1 hour.
  **Design note, see ADR-019**: all three are REACTIVE triggers layered on top of the pre-existing
  client-direct writes (`CommunityGroupService`'s methods and the report-writing call sites are
  unchanged) — not a write-gating callable. This is additive (every pre-existing rules test for
  kick/ban/mute/reports passes unmodified) but has an honest, bounded limitation: a burst can still
  land up to the window's max plus however many arrive before the trigger fires (typically ~1-2s)
  before the lock actually engages. `_checkContent`'s fail-open → fail-closed fix is client-side, not
  a Cloud Function — see `CommunityService` above.

**Gym check-in & presence** (`gym.js`, `presence.js`)
- **validateGymCheckin** (callable, `gym.js`, Faz 0 §0.7) — The only place a scanned QR value is ever
  compared against the stored `gyms/{id}/private/qr_token` (owner/admin-read-only; members obtain it
  exclusively by scanning the rendered image, never a Firestore read) and the only writer of a
  `method: 'qr'` check-in. Re-derives the actor's `display_name`/`photo_url` from their own user doc
  rather than trusting the client payload.
- **recordPresenceEvent** (callable, `presence.js`, Faz 1 §1.5) — Server-authoritative background
  geofence presence. Three event types: `enter` (raw boundary crossing — acknowledged only, does not
  open a session; "walking past" must not count), `dwell` (the loitering confirmation — Android's
  native `GEOFENCE_TRANSITION_DWELL`, or iOS's own 5-minute timer — this is what actually opens a
  session), `exit` (closes whatever session is open; no-op success if none is, since a dwell may
  never have confirmed). A `dwell` validates App Check, gym membership, `gyms/{id}.geofence_enabled`,
  `hasConsent(gym_presence)`, the per-gym `presence_prefs` toggle, a 10-minute same-gym re-entry rate
  limit, and ±5-minute client/server clock skew before opening `gyms/{id}/presence/{uid}` and
  incrementing `live_occupancy` (transaction). Closing a session (`exit` or the scheduled timeout
  sweep below) writes an immutable `presence_sessions` doc, decrements `live_occupancy`, and records a
  `method: 'geofence'` check-in — so the leaderboard/gym-wars/analytics see a real, server-verified
  visit instead of a client-claimed one.
- **onGymPresenceCreated** (Firestore trigger, `presence.js`, Faz 1 §1.7) — On a new
  `gyms/{id}/presence/{uid}` doc (i.e. a real, dwell-confirmed arrival), notifies whichever of the
  arriving member's friends are ALSO members of that gym — intersected via one membership existence
  check per friend rather than a `whereIn` (30-item cap). Gated by, in order: a fixed-window quiet
  hours check (07:00–23:00, Europe/Istanbul UTC+3 — the app's only real market, so a fixed offset is
  accurate here, not an approximation), the arriving user's own `notify_friends_enabled` broadcast
  toggle, the receiving user's per-friend mute list (`presence_prefs.muted_friend_uids`), and a
  once-per-(receiver, friend, gym)-per-day dedup log (`presence_notify_log`, fully server-only).
  Writes via the shared `writeNotification` helper — push suppression for a receiver who muted the
  entire `presence` notification group happens automatically downstream in `onInAppNotificationCreated`,
  the same as every other notification type.

**Admin roles** (`admin.js`)
- **syncAdminClaim** (Firestore trigger, `BLK-05`) — On write to `admin_roles/{uid}`, mirrors
  `is_admin` onto the Firebase Auth `admin` custom claim. The real admin gate: `admin_roles/{uid}`
  itself is console/Admin-SDK-only (`write: if false`), so this claim can't be self-granted.

**Notifications & social** (`notifications.js`, `social.js`, `BLK-03`/`SEC-06`)
- **createNotification / retractNotification** (callables, `notifications.js`) — Server-authored
  in-app notification create/undo for social interactions (likes, comments, reactions, mentions,
  streak milestones). Actor is always `context.auth.uid`, re-fetched from `users/{uid}` — never the
  client payload. `retractNotification` only deletes docs whose `actorUid` matches the caller.
- **sendAdminNotification** (callable, `notifications.js`) — Admin-claim-gated (`BLK-05`'s custom
  claim). Coach/gym application decisions and free-text single-user messages
  (`AdminService.sendNotificationToUser`'s server side).
- **followUser / unfollowUser / sendFriendRequest / respondToFriendRequest / cancelFriendRequest**
  (callables, `social.js`) — Replace the old client-direct writes to `friends`/`friend_requests`
  (now rule-denied unconditionally). Each re-verifies state server-side and writes the edge(s) +
  notification atomically.

**Notifications & broadcasts** (`index.js`)
- **onInAppNotificationCreated** (Firestore trigger) — On new `notifications/{uid}/items/{docId}`
  doc (the canonical path, `BLK-03`), fans out a localized (recipient's `locale`) FCM push respecting
  the recipient's mute preferences. Skips `type: 'broadcast'` docs (handled below) to avoid a
  double-send.
- **onChatMessageCreated** (Firestore trigger) — On new `chats/{id}/messages/{id}`, pushes to other
  recipients AND (Faz 2 §2.1) increments each recipient's `chats/{id}.unreadCounts` key — the
  ONLY writer of that increment now; a client may only ever zero its own key
  (firestore.rules' `canMarkOwnUnreadZero`). Push preview reads the v2 `body` field (falls back to
  the legacy `text` defensively, though onCreate only ever fires for brand-new — so always v2 —
  docs). **Faz 2 §2.4 fix** (`resolveChatRecipients` helper): recipients used to come straight from
  `chatData.participants`, which for a group-backed chat (`groupId` set) only ever holds the group's
  owner — `joinGroup`/`approveJoinRequest`/`redeemGroupInvite`/`kickMember`/`banMember` all write
  `community_groups/{groupId}/members`, never this array. Every real member besides the owner was
  therefore silently invisible to both push AND the unread counter for every group/gym chat. Now:
  when `groupId` is set, recipients are read from that SAME `members` subcollection (excluding
  `banned` ones) instead — the same source firestore.rules' `canAccessGroupChat()` already treats as
  authoritative for chat access — rather than trying to keep `participants` in sync at every
  membership-change call site (rejected: `participants` is deliberately client-immutable per Faz 2
  §2.1's `canUpdateChatMeta()`, closing that back up would reopen a chat-hijack surface). No new
  index — a bare `members` collection read, no `where`/`orderBy`. This is also what makes
  `ChatService.getUnreadMessageCountStream` (the plan's "sunucu tarafı toplam okunmamış sayacı")
  correct for groups/gym chats, not just DMs — it just sums `unreadCounts[uid]`, so a real key per
  real member is all it needed.
- **executeBroadcast** (internal helper) — Sends admin broadcasts to an audience (all/coaches/
  gymOwners/single uid), immediate or scheduled, with its own per-locale push text.

**Scheduled (pubsub cron)** (`index.js`)
- **streakAtRiskNotifier** (daily, 17:00 UTC) — Queries `users` for an active streak and pushes a
  reminder to anyone who hasn't logged food yet today (respecting the `reminders` mute group).
  **Bug fixed 2026-08-04**: was querying a top-level `streak` field that no user document has ever
  had (`.where('streak', '>', 0)`) — the real field is nested at `onboarding_data.streak`
  (`firestore_service.dart`'s `handleUserLogin` writes it via dot-notation). Firestore excludes any
  doc missing the field used in a `where()`/`orderBy()`, so the query always returned an empty
  snapshot and this cron had silently never sent a single notification since it was written. Now
  queries `onboarding_data.streak` — matches the field path `leaderboard_service.dart` and
  `community_service.dart` already order by. No index change needed: `firestore.indexes.json` has
  no `fieldOverrides` disabling automatic single-field indexing on this path, and a lone inequality
  filter (no combined `orderBy` on a different field) never needs a composite index — confirmed
  empirically against the Firestore emulator (seeded realistically-shaped docs, old query shape
  matched zero, new shape matched exactly the seeded active-streak user).
- **weeklyPlanReadyNotifier** (Mondays, 07:00 UTC) — Notifies onboarded users their weekly plan is
  ready to regenerate.
- **endExpiredGymWars** (hourly) — Closes any `gym_wars` doc past its `end_date`, scores both sides
  via `.count()` aggregation, and notifies both gym owners of the result (Faz 0 §0.6, `S18`).
- **closeStalePresenceSessions** (every 15 min, `presence.js`, Faz 1 §1.5) — Safety-net sweep: closes
  any `presence` doc (collection-group query) whose `expires_at` has passed with no real `exit` ever
  arriving (app killed, phone died, background execution denied by the OS), so a "ghost" presence
  can't inflate `live_occupancy` forever. Independent of any gym's opening hours by design.
- **computeGroupActivityScores** (every 15 min, `groups.js`, Faz 2 §2.5) — see "Unified groups" above
  for the full decay-formula writeup; listed here too since this is the index of every scheduled job.
- **expirePlanOffers** (hourly, `templates.js`, Faz 3 §3.5) — same shape as `endExpiredGymWars`
  (query a status + a date bound, batch-flip, log) but over a `collectionGroup('plan_offers')` scan
  (the collection lives per-user, not as one top-level collection) — needs its own `COLLECTION_GROUP`
  composite index, separate from the `COLLECTION`-scoped one the offer inbox query uses
  (`DATABASE.md`). Flips any `pending` offer past `expires_at` to `expired`; no notification sent —
  a silent flip only, since telling a member "your ignored offer expired" would itself be the pressure
  §3.5 explicitly says a member should never feel.
- **expireMemberProgressSummaries** (hourly, `summaries.js`, Faz 4 §4.2) — same query/batch shape as
  `expirePlanOffers` above, but **deletes** rather than flips a status field: a stale AI-generated
  narrative has no audit value once expired (unlike a historical plan-offer record). One
  `collectionGroup('member_summaries')` query covers both `gyms/{id}/member_summaries` and
  `coach_profiles/{id}/member_summaries` since they share a subcollection name.

**Meal plan templates** (`templates.js`, Faz 3 §3.2, extended §3.5)
- **sendPlanOffer** (callable) — The only writer of `users/{uid}/plan_offers/{id}` (`allow create: if
  false` in `firestore.rules`). Accepts `templateId` + `toUids` (dedup'd, self-send dropped, capped at
  100) + an optional `message` (≤500 chars); verifies the caller is the template's own `author_uid`
  (or a site admin); verifies each recipient has a REAL relationship to the sender (`gym`: a member of
  the template's `gym_id`; `coach`: an ACTIVE client at `coach_profiles/{authorUid}/clients/{toUid}`;
  `admin`: any registered user); then, per recipient, batch-writes: (1) a `plan_offers/{autoId}` doc
  (immutable `template_snapshot` copy taken at that moment), (2) **Faz 3 §3.5** — a `plan_offer`-typed
  chat message in that recipient's private 1:1 chat with the sender (found via ONE query of the
  sender's own chats up front, not one query per recipient — mirrors `ChatService
  .createOrGetPrivateChat`'s find-or-create shape, batched; a new chat is created if none exists yet),
  matching the exact field shape `ChatService.sendMessage`/`MessageModel.toJson` produce so
  `onChatMessageCreated` (`index.js`) fires unread-count + push exactly as it would for a client-sent
  message. Bumps `meal_plan_templates/{id}.usage_count` by the recipient count in the same batch — the
  only path that field can move (`touchesProtectedTemplateFields()`). After the batch commits: (3) a
  `planOfferReceived` notification per recipient (`writeNotification`, best-effort — the durable write
  already succeeded by this point).
- **onPlanOfferResponded** (Firestore trigger, `users/{uid}/plan_offers/{offerId}` onUpdate, Faz 3
  §3.5) — reacts to the RECIPIENT's own direct Firestore update (no callable exists for accept/decline
  — `firestore.rules`' `plan_offers` update rule already lets the recipient flip
  `pending`→`accepted`/`declined` directly, verified by the rules suite). The only place the
  sender-facing notification can be written (`notifications/*` create is server-only). Mirrors
  `onChatMessageCreated`/`onGymPresenceCreated`'s "client writes the allowed primary mutation, a
  trigger reacts with the server-only side effect" pattern. Fires a `planOfferDeclined` notification
  to `from_uid` ONLY on decline (never accept — not asked for by §3.5's own text), forwarding
  `decline_reason` into the notification metadata if present. **Faz 5 §5.2**: on `accepted`, ALSO
  calls `engagement_credit.js`'s `awardTemplateUsedCredit({authorUid: after.from_uid, acceptingUid,
  refId: offerId})` right alongside the existing `awardXp(..., 'template_accepted', ...)` call — the
  template's AUTHOR (not the accepting member) gets a shot at received-engagement credit for "your
  template was used by someone else", gated by the same account-eligibility + reciprocity/
  concentration checks every other §5.2 source uses.
- **expirePlanOffers** (scheduled) — see "Scheduled (pubsub cron)" above.

**Progress-sharing summaries** (`summaries.js`, Faz 4 §4.1/§4.2)
- **generateMemberProgressSummary** (callable) — Full contract: [`API.md`](API.md) §3. The
  server-authoritative replacement for `coach_client_detail_screen.dart`'s client-side, zero-check
  `_generateAiReport()` (audit C2) — that call site is still live in parallel until Faz 4 §4.4
  rewires the screen to call this instead; this task builds the backend half only. Re-derives the
  caller's authority from real `gyms/{id}.owner_uid`+`members` or `coach_profiles/{id}/clients`
  data (never the client's claim, matching `sendPlanOffer`'s `isEligibleRecipient` precedent above);
  rejects outright (not a quiet empty result) at `progress_sharing` tier 0; aggregates only the
  tier-permitted fields; checks the MEMBER's (not the caller's) `aiProcessing`+`crossBorderTransfer`
  consent before any LLM call, falling back to a template-only narrative otherwise; tags the AI call
  `type: 'coach_report'` (now in `index.js`'s `ALLOWED_TYPES` — was missing); charges quota/rate-limit
  to the CALLER's own `ai_credits/{uid}`, never the member's.
- **onProgressSharingWrite** (Firestore trigger, `users/{uid}/progress_sharing/{scopeId}` onWrite) —
  see "Scheduled (pubsub cron)" section above for its sibling sweep; this one reacts immediately
  instead of waiting: deletes the cached `member_summaries` doc for that (uid, scopeId) the moment
  the tier changes AT ALL (any direction), not only on a full revoke — docs/COMPLIANCE.md's
  "withdrawable as easily as it was given" bar.
- **expireMemberProgressSummaries** (scheduled) — see "Scheduled (pubsub cron)" above.

Shares `aiProxy`'s quota/cost machinery (`getAppConfig`/`isPremium`/`enforceRateLimitAndQuota`/
`rollbackConsume`/`recordUsage`, all still defined in `index.js`) via a factory function
(`createSummariesModule({...})`) rather than duplicating it — see the Cloud Functions header note
above for why a factory instead of either a second copy of that logic or a circular `require`.

**Received-engagement credit** (`engagement_credit_logic.js` + `engagement_credit.js`, Faz 5 §5.2)

Credit for what OTHER accounts do to YOUR content — structurally separate from Faz 5 §5.1's XP (which
rewards actions YOU take) per that file's own header comment ("do not reuse xp_events for this").
Lands in the EXISTING `ai_credits/{uid}.bonus` pool via `entitlements.js`'s `grantBonusCredits` — no
third currency. `engagement_credit_logic.js` is pure (zero Firebase dependency, unit-tested directly);
`engagement_credit.js` is the Firestore orchestration. Full data model: `DATABASE.md`.

- **onPostReactionCreated** / **onCommentLikeCreated** (Firestore triggers, `posts/{id}/reactions/{uid}`
  and `posts/{id}/comments/{id}/likes/{uid}` onCreate) — sources 1/2: "post got reactions from 10
  distinct accounts" / "comment got likes from 5 distinct accounts". Both funnel through
  `handleDistinctAccountEngagement`: self-reaction/like never counts; content-quality + duplicate-
  content eligibility is computed ONCE per content item and cached (`credit_progress` subcollection,
  fully server-only) so every later reactor/liker reuses the same verdict; `accumulateWeightedEngagement`
  dedups the giver PERMANENTLY (`counted_uids` only ever grows — a remove-then-redo toggle can never
  re-count) and accumulates a reciprocity/concentration-weighted score toward the threshold in one
  transaction; crossing the threshold triggers `awardEngagementCredit`.
- **awardTemplateUsedCredit** (internal, NOT an exported Cloud Function) — source 3: "your template/
  recipe was used by someone else". Called in-process from `templates.js`'s `onPlanOfferResponded` on
  accept (see that entry above). No distinct-account threshold (every acceptance is its own discrete,
  one-time opportunity) — the reciprocity/concentration weight is applied as a binary gate instead of
  threshold progress: a flagged pair's acceptance is skipped outright, not partially credited.
- **onGroupChatMessageCreatedForContribution** / **onGroupPostCreatedForContribution** /
  **onGroupCommentCreatedForContribution** (Firestore triggers) + **awardWeeklyGroupTop3** (scheduled,
  every 24h) — source 4: "top-3 in weekly group contribution ranking". The three triggers bump a
  per-(group, week, member) score (message×1/post×3/comment×2 — same weights `computeGroupActivityScores`
  already uses, as a flat weekly sum rather than a decayed one) in `community_groups/{id}/
  weekly_contributions/{weekKey}/members/{uid}` (fully server-only); the sweep always reprocesses the
  most recently COMPLETED local week (idempotent via the ledger, so exact cron timing never matters),
  ranks each group's top `WEEKLY_CANDIDATE_BUFFER` (10) scorers, and awards the first 3 who pass the
  account-eligibility gate (`pickTopNEligible` — skips an ineligible top-scorer and promotes the next
  one, rather than losing the slot). The 1/week cap is GLOBAL across all groups (a member top-3 in
  multiple groups the same week is credited once, from whichever group's sweep iteration lands first
  — an accepted, low-stakes tiebreak, documented in the function's own header comment). Its cap-check
  is an EQUALITY match on `week_key` (see `DATABASE.md`'s `engagement_credit_events` row), not a
  `created_at` time range like the three daily sources use — a range would break here specifically,
  since the award always happens after its target week has already closed. **Faz 5 §5.3**: each
  winner's loop iteration ALSO calls `progress.grantAchievementIfNew(db, uid, 'groupTop3')` (first-
  ever weekly top-3 finish) and `bumpGroupTop3Streak` (consecutive-week counter on
  `users/{uid}.group_top3_streak`/`.group_top3_streak_week_key`, field-locked in firestore.rules
  exactly like `xp`/`level` — crossing 4 grants `groupStreak4` via the same
  `grantAchievementIfNew`). Both are best-effort (awaited, errors logged, never abort the sweep).
- **computeGroupContributionLeaderboards** (scheduled, every 15 min, Faz 5 §5.3) — denormalizes
  `weekly_contributions/{weekKey}/members` (top 10, CURRENT still-accumulating week — a live "who's
  winning right now" display, unlike `awardWeeklyGroupTop3`'s last-COMPLETED-week award pass) into
  `community_groups/{id}/weekly_leaderboard/{weekKey}` (`entries: [{uid, display_name, photo_url,
  score, rank}]`), resolving names/photos via one batched `db.getAll(...)` per group (bounded to the
  top 10, never all members). Mirrors `computeGroupActivityScores`'s cadence/shape exactly (`groups.js`)
  — the same "periodically denormalize a server-only counter for display" pattern, reused rather than
  invented fresh. Consumed by `CommunityGroupService.getWeeklyContributionLeaderboardStream` →
  `GroupLeaderboardScreen` (`lib/screens/community/groups/group_leaderboard_screen.dart`).
- **Anti-abuse mechanism, shared by every source above** (`engagement_credit_logic.js`):
  - `reciprocityWeight` — a rolling PER-PAIR bidirectional interaction counter
    (`reciprocity_pairs/{pairKey}`, fully server-only); once a pair's history is large enough to judge
    (≥4 total interactions) and roughly balanced both ways (ratio ≥0.5), new interactions between them
    are down-weighted to 0.2× — the concrete A→B→A signature the plan names.
  - `concentrationWeight` — catches closed CLUSTERS a pairwise check alone would miss: a rolling
    window (last 20) of distinct engagers a RECEIVER has gotten credit from
    (`engagement_diversity/{uid}`, fully server-only); once full, if ≤3 distinct accounts account for
    the whole window, further engagement from that same small set is down-weighted 0.2×.
  - Both signals combine by taking the MORE punitive weight (`combinedEngagementWeight`) — independent
    detectors of the same concern, not stacked penalties. Honest limitation documented in the source:
    neither catches many disposable ONE-SHOT bot accounts each reacting exactly once to one target
    (no recurrence for either signal to catch) — the account-age+email-verification gate is the
    primary defense against that specific pattern, not this mechanism.
  - `isNearDuplicateText` — near-identical-repost detection (exact match after normalization, OR
    word-level Jaccard similarity ≥0.85) against the AUTHOR'S OWN last 20 posts/comments/group
    messages — never a cross-user corpus. Deliberately simple, per the plan's own instruction not to
    over-engineer a full plagiarism detector.
  - `isAccountOldEnough` (≥3 days) + Admin Auth's `emailVerified` (no Firestore mirror exists for this
    anywhere in the codebase, so this is the one place in the batch that calls `admin.auth().getUser()`
    rather than reading only Firestore) + `credit_restrictions/{uid}.is_shadow_restricted !== true` —
    all three gate EVERY award, for every source, no exceptions.
  - **Shadow-restriction auto-trigger** (`bumpSuspicionFlag`) — a rolling `flag_count` on
    `credit_restrictions/{uid}`, bumped on BOTH sides of a down-weighted interaction (the receiver
    whose credit attempt was flagged, AND the giver whose engagement pattern looked non-organic) and
    on a duplicate-content block (the author only). Crossing `AUTO_RESTRICT_FLAG_THRESHOLD` (5)
    auto-restricts: `is_shadow_restricted: true` + an immutable `users/{uid}/credit_moderation`
    `restrict` log entry. Restriction affects ONLY credit accumulation — zero effect on content
    visibility to other users. Real appeal path: reuses Faz 2 §2.6's `moderation_appeals` collection/
    lifecycle/admin-review-queue/rate-limiter end to end (a second appeal KIND, not a second appeals
    system) — see `ModerationAppealService`/`AdminService` entries above and
    `lib/screens/profile/credit_restriction_screen.dart`.
  - **Premium 2× multiplier** (`creditAndCapForPremium`) — doubles both the per-source credit value
    AND the daily/weekly cap for premium users; the distinct-account THRESHOLD (10/5) is deliberately
    NOT doubled — premium makes the reward bigger, never the popularity bar easier to clear. This is
    the concrete, actually-applied implementation of the `multiplier_applied` field `xp_events`
    reserved (always `1`, inert) for this exact system — see `progress.js`'s header comment.
- **Deferred, explicitly out of scope for this pass**: an admin-panel manual restrict/lift button (only
  the auto-trigger + appeal-driven lift exist today — `isAccountEligibleForCredit`/`bumpSuspicionFlag`
  are exported for this future reuse); a decrement/reversal of `reciprocity_pairs`/`engagement_diversity`
  when a reaction/like is later removed (the trackers record that an interaction HAPPENED, by design,
  and are never walked back). Faz 5 §5.3 (leaderboard/badge UI reading this mechanism) is now built —
  see the "Faz 5 §5.3" callout above and the "Achievements, reputation & XP" section's
  `grantAchievementIfNew` entry.

**Secrets / env** (Functions): `OPENROUTER_API_KEY` + Apple/Google store credentials in
`functions/.env`; `APP_ENV` selects enforcement mode.

---

## Dependencies (grouped — see `pubspec.yaml` for exact versions)
- **Firebase:** core, auth, firestore, storage, analytics, crashlytics, messaging, remote_config,
  performance, app_check; google_sign_in, sign_in_with_apple.
- **State/UI:** provider, flutter_screenutil, cupertino_icons, font_awesome_flutter, flutter_svg,
  cached_network_image.
- **Local:** shared_preferences, hive(+flutter), path_provider.
- **Network/AI:** http, connectivity_plus, flutter_dotenv, flutter_map+latlong2, url_launcher.
- **Device/Media:** device_info_plus, package_info_plus, permission_handler, geolocator, image_picker,
  file_picker, mobile_scanner, qr_flutter, speech_to_text, wakelock_plus, share_plus.
- **Commerce:** in_app_purchase, app_links.
- **Utils:** intl, logging, flutter_local_notifications, uuid, crypto.
- **Dev:** flutter_test, flutter_lints, hive_generator, build_runner, analyzer.
